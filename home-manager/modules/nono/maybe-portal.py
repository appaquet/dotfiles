"""Request/approve bridge for commands that need to escape the nono sandbox.

Two modes share one entry point:
  * client mode (`maybe-portal <argv...>`) connects to `./.nono/socket`, sends a request,
    relays output, and exits with the command's exit code.
  * approver mode (`maybe-portal`) binds `./.nono/socket`, prompts a human per request,
    runs the command outside the sandbox, and streams output back.

Warning: vibe coded
"""

import atexit
import errno
import json
import os
import re
import select
import shlex
import signal
import socket
import subprocess
import sys
import termios
import threading
import tty

SOCKET_DIR = ".nono"
SOCKET_NAME = "socket"
WHITELIST_NAME = "portal.json"
PROTOCOL_VERSION = 1
CONNECT_PROBE_TIMEOUT = 0.1
OUTPUT_PREFIX = "│ "
USAGE = """\
usage:
  maybe-portal                run as approver: bind ./.nono/socket, prompt per request
  maybe-portal <argv...>      run as client: send request to approver, relay output, exit with its code
  maybe-portal --help         show this message

The approver creates ./.nono/ if missing and binds ./.nono/socket with mode 0600.
A project-local whitelist at ./.nono/portal.json (regex patterns) auto-approves
matching requests. Approver keys per prompt: a=approve, d=deny, w=approve+save
pattern, q=deny and stop.
"""


def main(argv):
    if argv and argv[0] in ("-h", "--help"):
        sys.stdout.write(USAGE)
        return 0
    if not argv:
        return run_approver()
    return run_client(argv)


def run_approver():
    sock_path = os.path.join(SOCKET_DIR, SOCKET_NAME)
    os.makedirs(SOCKET_DIR, exist_ok=True)

    if _probe_existing(sock_path):
        sys.stderr.write(
            f"maybe-portal: another approver is already listening on {sock_path}\n"
        )
        return 1

    _remove_stale(sock_path)

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    prev_umask = os.umask(0o177)
    try:
        server.bind(sock_path)
    finally:
        os.umask(prev_umask)
    # bind honours umask but be explicit so behavior is independent of the inherited mask.
    os.chmod(sock_path, 0o600)
    server.listen(8)

    atexit.register(_safe_unlink, sock_path)
    stopping = {"flag": False}

    def _on_signal(signum, _frame):
        stopping["flag"] = True
        _safe_unlink(sock_path)
        # Re-raise default behavior so the process terminates promptly.
        signal.signal(signum, signal.SIG_DFL)
        os.kill(os.getpid(), signum)

    signal.signal(signal.SIGINT, _on_signal)
    signal.signal(signal.SIGTERM, _on_signal)

    sys.stderr.write(f"listening on {sock_path}\n")
    sys.stderr.flush()

    try:
        while not stopping["flag"]:
            try:
                conn, _addr = server.accept()
            except OSError as exc:
                if exc.errno == errno.EINTR:
                    continue
                raise
            try:
                stop_after = _handle_connection(conn)
            finally:
                try:
                    conn.close()
                except OSError:
                    pass
            if stop_after:
                break
    finally:
        try:
            server.close()
        except OSError:
            pass
        _safe_unlink(sock_path)
    return 0


def run_client(argv):
    sock_path = os.path.join(SOCKET_DIR, SOCKET_NAME)
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        client.connect(sock_path)
    except (FileNotFoundError, ConnectionRefusedError):
        sys.stderr.write(f"maybe-portal: no approver running on {sock_path}\n")
        return 2
    except OSError as exc:
        if exc.errno in (errno.ENOENT, errno.ECONNREFUSED):
            sys.stderr.write(f"maybe-portal: no approver running on {sock_path}\n")
            return 2
        sys.stderr.write(f"maybe-portal: connect failed: {exc}\n")
        return 2

    # SIGINT closes the socket; the approver keeps owning the running command.
    def _on_sigint(_signum, _frame):
        try:
            client.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        try:
            client.close()
        except OSError:
            pass
        sys.exit(130)

    signal.signal(signal.SIGINT, _on_sigint)

    request = {
        "version": PROTOCOL_VERSION,
        "argv": list(argv),
        "cwd": os.getcwd(),
        "pid": os.getpid(),
    }
    try:
        client.sendall((json.dumps(request) + "\n").encode("utf-8"))
    except OSError as exc:
        sys.stderr.write(f"maybe-portal: failed to send request: {exc}\n")
        return 2

    reader = client.makefile("r", encoding="utf-8", errors="replace", newline="\n")
    try:
        for line in reader:
            line = line.rstrip("\n")
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                sys.stderr.write(
                    f"maybe-portal: malformed event from approver: {line!r}\n"
                )
                return 2
            kind = event.get("event")
            if kind == "output":
                stream = sys.stdout if event.get("stream") == "stdout" else sys.stderr
                stream.write(event.get("data", ""))
                stream.flush()
            elif kind == "exit":
                code = event.get("code", 0)
                try:
                    return int(code)
                except (TypeError, ValueError):
                    return 1
            elif kind == "denied":
                reason = event.get("reason", "unknown")
                sys.stderr.write(f"maybe-portal: denied: {reason}\n")
                return 126
            else:
                sys.stderr.write(
                    f"maybe-portal: unknown event from approver: {kind!r}\n"
                )
                return 2
    finally:
        try:
            reader.close()
        except OSError:
            pass
        try:
            client.close()
        except OSError:
            pass

    sys.stderr.write("maybe-portal: approver closed connection without exit event\n")
    return 2


def _handle_connection(conn):
    """Run a single approver/client transaction. Returns True if approver should stop."""
    conn.settimeout(None)
    reader = conn.makefile("r", encoding="utf-8", errors="replace", newline="\n")
    raw = reader.readline()
    if not raw:
        _send_event(conn, {"event": "denied", "reason": "empty request"})
        return False
    try:
        request = json.loads(raw)
    except json.JSONDecodeError:
        _send_event(conn, {"event": "denied", "reason": "malformed request"})
        return False
    if not isinstance(request, dict):
        _send_event(conn, {"event": "denied", "reason": "malformed request"})
        return False
    if request.get("version") != PROTOCOL_VERSION:
        _send_event(conn, {"event": "denied", "reason": "unsupported version"})
        return False
    argv = request.get("argv")
    cwd = request.get("cwd")
    pid = request.get("pid")
    if (
        not isinstance(argv, list)
        or not argv
        or not all(isinstance(a, str) for a in argv)
        or not isinstance(cwd, str)
        or not isinstance(pid, int)
    ):
        _send_event(conn, {"event": "denied", "reason": "malformed request"})
        return False

    quoted = shlex.join(argv)
    patterns = _load_whitelist()
    matched = _match_whitelist(patterns, quoted)
    stop_after = False
    if matched is not None:
        sys.stderr.write(f"auto-approved by pattern: {matched}\n")
        sys.stderr.flush()
    else:
        decision = _prompt_user(pid, cwd, quoted, argv)
        if decision == "deny":
            _send_event(conn, {"event": "denied", "reason": "user denied"})
            return False
        if decision == "deny_stop":
            _send_event(conn, {"event": "denied", "reason": "user denied"})
            return True
        if decision == "approve_stop":
            stop_after = True
        # "approve" / "approve_stop" / "whitelisted" all proceed to exec.

    if not os.path.isdir(cwd):
        _send_event(conn, {"event": "denied", "reason": "cwd missing"})
        return stop_after

    _run_subprocess(conn, argv, cwd)
    return stop_after


def _prompt_user(pid, cwd, quoted, argv):
    sys.stderr.write("\n")
    sys.stderr.write("maybe-portal: incoming request\n")
    sys.stderr.write(f"  pid: {pid}\n")
    sys.stderr.write(f"  cwd: {cwd}\n")
    sys.stderr.write(f"  cmd: {quoted}\n")
    sys.stderr.write("  [a]pprove  [d]eny  [w]hitelist+approve  [q]deny+stop: ")
    sys.stderr.flush()

    choice = _read_one_key()
    sys.stderr.write(f"{choice}\n")
    sys.stderr.flush()
    if choice == "a":
        return "approve"
    if choice == "d":
        return "deny"
    if choice == "q":
        return "deny_stop"
    if choice == "w":
        default = _default_pattern(quoted)
        sys.stderr.write(f"pattern (default: {default}): ")
        sys.stderr.flush()
        entered = sys.stdin.readline() if not sys.stdin.isatty() else input()
        pattern = entered.strip() if entered and entered.strip() else default
        try:
            re.compile(pattern)
        except re.error as exc:
            sys.stderr.write(f"invalid regex, not saved: {exc}\n")
            sys.stderr.flush()
            return "approve"
        _persist_pattern(pattern)
        sys.stderr.write(f"saved pattern: {pattern}\n")
        sys.stderr.flush()
        return "approve"
    return "deny"


def _run_subprocess(conn, argv, cwd):
    try:
        proc = subprocess.Popen(
            argv,
            cwd=cwd,
            env=os.environ.copy(),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
            text=False,
        )
    except FileNotFoundError as exc:
        _send_event(conn, {"event": "denied", "reason": f"exec failed: {exc}"})
        return
    except OSError as exc:
        _send_event(conn, {"event": "denied", "reason": f"exec failed: {exc}"})
        return

    send_lock = threading.Lock()

    def pump(stream_obj, stream_name):
        try:
            for raw_line in iter(stream_obj.readline, b""):
                text = raw_line.decode("utf-8", errors="replace")
                with send_lock:
                    _send_event(
                        conn,
                        {"event": "output", "stream": stream_name, "data": text},
                    )
                # Tail to approver stderr with a faint prefix so the operator sees progress.
                sys.stderr.write(OUTPUT_PREFIX + text)
                sys.stderr.flush()
        finally:
            try:
                stream_obj.close()
            except OSError:
                pass

    t_out = threading.Thread(target=pump, args=(proc.stdout, "stdout"), daemon=True)
    t_err = threading.Thread(target=pump, args=(proc.stderr, "stderr"), daemon=True)
    t_out.start()
    t_err.start()

    code = proc.wait()
    t_out.join()
    t_err.join()

    with send_lock:
        _send_event(conn, {"event": "exit", "code": code})


def _load_whitelist():
    path = os.path.join(SOCKET_DIR, WHITELIST_NAME)
    try:
        with open(path, "r", encoding="utf-8") as fp:
            data = json.load(fp)
    except FileNotFoundError:
        return []
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"maybe-portal: failed to read {path}: {exc}\n")
        return []
    if not isinstance(data, dict) or data.get("version") != PROTOCOL_VERSION:
        sys.stderr.write(f"maybe-portal: ignoring {path}: unsupported schema\n")
        return []
    raw_patterns = data.get("patterns") or []
    compiled = []
    for raw in raw_patterns:
        if not isinstance(raw, str):
            sys.stderr.write(f"maybe-portal: skipping non-string pattern: {raw!r}\n")
            continue
        try:
            compiled.append((raw, re.compile(raw)))
        except re.error as exc:
            sys.stderr.write(f"maybe-portal: skipping invalid regex {raw!r}: {exc}\n")
    return compiled


def _match_whitelist(patterns, candidate):
    for raw, compiled in patterns:
        if compiled.search(candidate):
            return raw
    return None


def _persist_pattern(pattern):
    path = os.path.join(SOCKET_DIR, WHITELIST_NAME)
    os.makedirs(SOCKET_DIR, exist_ok=True)
    existing = []
    try:
        with open(path, "r", encoding="utf-8") as fp:
            data = json.load(fp)
        if isinstance(data, dict) and isinstance(data.get("patterns"), list):
            existing = [p for p in data["patterns"] if isinstance(p, str)]
    except FileNotFoundError:
        pass
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"maybe-portal: rewriting {path} (could not parse: {exc})\n")

    if pattern in existing:
        return
    existing.append(pattern)
    payload = {"version": PROTOCOL_VERSION, "patterns": existing}
    tmp_path = path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as fp:
        json.dump(payload, fp, indent=2)
        fp.write("\n")
    os.replace(tmp_path, path)


def _default_pattern(quoted):
    return "^" + re.escape(quoted) + "$"


def _probe_existing(path):
    if not os.path.exists(path):
        return False
    probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    probe.settimeout(CONNECT_PROBE_TIMEOUT)
    try:
        probe.connect(path)
    except (ConnectionRefusedError, FileNotFoundError, socket.timeout):
        return False
    except OSError:
        return False
    else:
        return True
    finally:
        try:
            probe.close()
        except OSError:
            pass


def _remove_stale(path):
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    except OSError as exc:
        sys.stderr.write(f"maybe-portal: could not remove stale {path}: {exc}\n")


def _safe_unlink(path):
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    except OSError:
        pass


def _send_event(conn, event):
    payload = (json.dumps(event) + "\n").encode("utf-8")
    try:
        conn.sendall(payload)
    except OSError:
        pass


def _read_one_key():
    """Read a single keystroke from /dev/tty in cbreak mode; falls back to stdin."""
    try:
        fd = os.open("/dev/tty", os.O_RDONLY)
    except OSError:
        ch = sys.stdin.read(1)
        return ch.lower() if ch else ""
    try:
        old = termios.tcgetattr(fd)
        try:
            tty.setcbreak(fd)
            # Block until at least one byte is available.
            rlist, _, _ = select.select([fd], [], [])
            if not rlist:
                return ""
            ch = os.read(fd, 1).decode("utf-8", errors="replace")
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)
    finally:
        os.close(fd)
    return ch.lower()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
