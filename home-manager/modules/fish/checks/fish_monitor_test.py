"""Regression tests for the fish `monitor` function.

Each case drives a real interactive fish in a pseudo-terminal, the same way a user would type into
a Herdr pane, and compares the exact OSC 7501 states fish wrote to the terminal.

Usage: python3 fish_monitor_test.py <path/to/monitor.fish>
"""

import os
import pty
import re
import select
import signal
import sys
import tempfile
import time

PROMPT = b"PROMPT> "
FRAME_RE = re.compile(rb"\x1b\]7501;([^\x1b]*)\x1b\\")
TIMEOUT = 10.0


def main():
    monitor_fish = sys.argv[1]
    failures = []
    for case in CASES:
        try:
            case(monitor_fish)
            print(f"ok   {case.__name__}")
        except Exception as err:  # noqa: BLE001 - report every case
            failures.append(case.__name__)
            print(f"FAIL {case.__name__}: {err}")
    if failures:
        print(f"{len(failures)} case(s) failed: {', '.join(failures)}")
        sys.exit(1)


# Cases ------------------------------------------------------------------------------------------


def case_wrapper_success(monitor_fish):
    with Fish(monitor_fish) as f:
        f.run("monitor sh -c 'exit 0'")
        f.assert_states(["working", "done"])


def case_wrapper_error(monitor_fish):
    with Fish(monitor_fish) as f:
        f.run("monitor sh -c 'exit 3'; echo CODE=$status")
        f.assert_states(["working", "error"])
        f.assert_output(b"CODE=3")


def case_wrapper_frame_has_no_command_text(monitor_fish):
    with Fish(monitor_fish) as f:
        f.run("monitor sh -c 'exit 0' secret-arg")
        f.assert_frames([b"state=working:app=fish-job", b"state=done:app=fish-job"])


def case_wrapper_ctrl_c(monitor_fish):
    with Fish(monitor_fish) as f:
        f.start(f"monitor {READY_THEN_SLEEP}")
        f.send(b"\x03")
        f.wait_prompt()
        f.assert_states(["working", "idle"])


def case_wrapper_ctrl_z(monitor_fish):
    with Fish(monitor_fish) as f:
        f.start(f"monitor {READY_THEN_SLEEP}")
        f.suspend()
        f.assert_states(["working", "idle"])
        f.assert_stopped_jobs(1)


def case_wrapper_without_herdr(monitor_fish):
    with Fish(monitor_fish, herdr=False) as f:
        f.run("monitor sh -c 'echo RAN; exit 0'")
        f.assert_states([])
        f.assert_output(b"RAN")


def case_wrapper_usage(monitor_fish):
    with Fish(monitor_fish) as f:
        f.run("monitor; echo CODE=$status")
        f.assert_states([])
        f.assert_output(b"usage: monitor")
        f.assert_output(b"CODE=2")


def case_fg_resumes_same_job_with_input(monitor_fish):
    with Fish(monitor_fish) as f:
        f.start("sh -c 'echo PID1=$$; echo RE\"\"ADY; read x; echo GOT=$x PID2=$$; exit 4'")
        f.suspend()
        f.send(b"monitor fg\r")
        f.expect(b"to foreground")
        f.send(b"hello\r")
        f.wait_prompt()
        f.assert_states(["working", "error"])
        pid1 = f.match(rb"PID1=(\d+)")
        f.assert_output(b"GOT=hello PID2=" + pid1)


def case_fg_success(monitor_fish):
    with Fish(monitor_fish) as f:
        f.start("sh -c 'echo RE\"\"ADY; sleep 0.5; exit 0'")
        f.suspend()
        f.run("monitor fg")
        f.assert_states(["working", "done"])


def case_fg_pipeline_uses_last_stage(monitor_fish):
    with Fish(monitor_fish) as f:
        f.start("sh -c 'echo RE\"\"ADY; sleep 0.5' | sh -c 'cat; exit 5'")
        f.suspend()
        f.run("monitor fg")
        f.assert_states(["working", "error"])


def case_fg_ctrl_c(monitor_fish):
    with Fish(monitor_fish) as f:
        f.start(READY_THEN_TICK)
        f.suspend()
        f.resume("monitor fg")
        f.send(b"\x03")
        f.wait_prompt()
        f.assert_states(["working", "idle"])


def case_fg_second_ctrl_z(monitor_fish):
    with Fish(monitor_fish) as f:
        f.start(READY_THEN_TICK)
        f.suspend()
        f.resume("monitor fg")
        f.suspend()
        f.assert_states(["working", "idle"])
        f.assert_stopped_jobs(1)


def case_fg_no_stale_handler(monitor_fish):
    with Fish(monitor_fish) as f:
        f.start(READY_THEN_TICK)
        f.suspend()
        f.resume("monitor fg")
        f.suspend()
        f.resume("fg")
        f.send(b"\x03")
        f.wait_prompt()
        f.assert_states(["working", "idle"])


def case_fg_explicit_job(monitor_fish):
    with Fish(monitor_fish) as f:
        f.start("sh -c 'echo RE\"\"ADY; sleep 0.5; exit 0'")
        f.suspend()
        f.start("sh -c 'echo RE\"\"ADY; sleep 0.5; exit 6'")
        f.suspend()
        f.run("monitor fg %2")
        f.assert_states(["working", "error"])
        f.assert_stopped_jobs(1)


def case_fg_several_stopped_needs_choice(monitor_fish):
    with Fish(monitor_fish) as f:
        f.start(READY_THEN_SLEEP)
        f.suspend()
        f.start(READY_THEN_SLEEP)
        f.suspend()
        f.run("monitor fg; echo CODE=$status")
        f.assert_states([])
        f.assert_output(b"monitor fg %N")
        f.assert_output(b"CODE=1")
        f.assert_stopped_jobs(2)


def case_fg_no_stopped_job(monitor_fish):
    with Fish(monitor_fish) as f:
        f.run("monitor fg; echo CODE=$status")
        f.assert_states([])
        f.assert_output(b"no stopped job")
        f.assert_output(b"CODE=1")


def case_fg_ignores_running_background_job(monitor_fish):
    with Fish(monitor_fish) as f:
        f.run("sleep 30 &")
        f.run("monitor fg; echo CODE=$status")
        f.run("monitor fg %1; echo CODE2=$status")
        f.assert_states([])
        f.assert_output(b"CODE=1")
        f.assert_output(b"CODE2=1")


def case_m_abbreviation(monitor_fish):
    # The abbreviation lives in Home Manager config; this checks fish expands it as configured.
    with Fish(monitor_fish, extra_init="abbr -a m monitor") as f:
        f.start("sh -c 'echo RE\"\"ADY; sleep 0.5; exit 0'")
        f.suspend()
        f.send(b"m fg\r")
        f.wait_prompt()
        f.assert_states(["working", "done"])


READY_THEN_SLEEP = "sh -c 'echo RE\"\"ADY; exec sleep 30'"
# Prints a tick every 0.1 s, so a tick after a resume proves the job owns the terminal again.
READY_THEN_TICK = "sh -c 'echo RE\"\"ADY; while :; do echo TICK; sleep 0.1; done'"

CASES = [
    case_wrapper_success,
    case_wrapper_error,
    case_wrapper_frame_has_no_command_text,
    case_wrapper_ctrl_c,
    case_wrapper_ctrl_z,
    case_wrapper_without_herdr,
    case_wrapper_usage,
    case_fg_resumes_same_job_with_input,
    case_fg_success,
    case_fg_pipeline_uses_last_stage,
    case_fg_ctrl_c,
    case_fg_second_ctrl_z,
    case_fg_no_stale_handler,
    case_fg_explicit_job,
    case_fg_several_stopped_needs_choice,
    case_fg_no_stopped_job,
    case_fg_ignores_running_background_job,
    case_m_abbreviation,
]


# Harness ----------------------------------------------------------------------------------------


class Fish:
    """An interactive fish in a pseudo-terminal with `monitor.fish` sourced and a fixed prompt."""

    def __init__(self, monitor_fish, herdr=True, extra_init=""):
        self.monitor_fish = monitor_fish
        self.herdr = herdr
        self.extra_init = extra_init
        self.buf = b""
        self.answered_queries = 0
        self.prompts_seen = 0

    def __enter__(self):
        home = tempfile.mkdtemp()
        init = (
            "set -g fish_greeting; function fish_prompt; printf 'PROMPT> '; end; "
            f"source {self.monitor_fish}; {self.extra_init}"
        )
        env = {
            "HOME": home,
            "XDG_CONFIG_HOME": f"{home}/.config",
            "XDG_DATA_HOME": f"{home}/.local/share",
            "TERM": "xterm",
            "PATH": os.environ["PATH"],
        }
        if self.herdr:
            env["HC_TERMINAL_ID"] = "t1"
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execvpe("fish", ["fish", "--no-config", "-i", "-C", init], env)
        self.wait_prompt()
        return self

    def __exit__(self, *exc):
        try:
            os.killpg(os.getpgid(self.pid), signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            os.kill(self.pid, signal.SIGKILL)
            os.waitpid(self.pid, 0)
        except (ProcessLookupError, ChildProcessError):
            pass
        os.close(self.fd)

    def send(self, data):
        os.write(self.fd, data)

    def run(self, line):
        """Type a command line and wait for the next prompt."""
        self.send(line.encode() + b"\r")
        self.wait_prompt()

    def start(self, line):
        """Type a command line and wait until the command prints READY."""
        start = len(self.buf)
        self.send(line.encode() + b"\r")
        self.expect(b"READY\r\n", since=start)

    def resume(self, line):
        """Resume a tick job with `line` and wait until it ticks in the foreground."""
        start = len(self.buf)
        self.send(line.encode() + b"\r")
        self.expect(b"to foreground", since=start)
        self.expect(b"TICK\r\n", since=self.buf.index(b"to foreground", start))

    def suspend(self):
        """Press Ctrl-Z and wait for fish's prompt. Fish prints no stop notice inside a function."""
        self.send(b"\x1a")
        self.wait_prompt()

    def wait_prompt(self):
        target = self.prompts_seen + 1
        self._read_until(lambda: self.buf.count(PROMPT) >= target, f"prompt #{target}")
        self.prompts_seen = self.buf.count(PROMPT)

    def expect(self, needle, since=0):
        self._read_until(lambda: needle in self.buf[since:], repr(needle))

    def match(self, pattern):
        found = re.search(pattern, self.buf)
        if not found:
            raise AssertionError(f"no match for {pattern!r}\n{self._tail()}")
        return found.group(1)

    def frames(self):
        return FRAME_RE.findall(self.buf)

    def assert_frames(self, expected):
        got = self.frames()
        if got != expected:
            raise AssertionError(f"frames: expected {expected}, got {got}")

    def assert_states(self, expected):
        got = [re.match(rb"state=([a-z]+)", f).group(1).decode() for f in self.frames()]
        if got != expected:
            raise AssertionError(f"states: expected {expected}, got {got}\n{self._tail()}")

    def assert_output(self, needle):
        if needle not in self.buf:
            raise AssertionError(f"missing output {needle!r}\n{self._tail()}")

    def assert_stopped_jobs(self, expected):
        start = len(self.buf)
        self.run("echo STOPPED=(LC_ALL=C jobs 2>/dev/null | string match -r '\\tstopped\\t' | count)")
        got = re.search(rb"STOPPED=(\d+)", self.buf[start:].split(b"\n", 1)[-1])
        if not got or int(got.group(1)) != expected:
            raise AssertionError(f"stopped jobs: expected {expected}\n{self._tail()}")

    def _read_until(self, done, what):
        deadline = time.monotonic() + TIMEOUT
        while not done():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError(f"timed out waiting for {what}\n{self._tail()}")
            ready, _, _ = select.select([self.fd], [], [], remaining)
            if not ready:
                continue
            try:
                chunk = os.read(self.fd, 4096)
            except OSError:
                raise AssertionError(f"fish exited waiting for {what}\n{self._tail()}")
            self.buf += chunk
            self._answer_queries()

    def _answer_queries(self):
        # fish blocks at startup and before each prompt until the terminal answers its primary
        # device attributes query (ESC [ 0 c).
        queries = self.buf.count(b"\x1b[0c")
        while self.answered_queries < queries:
            self.send(b"\x1b[?62c")
            self.answered_queries += 1

    def _tail(self):
        return "output tail: " + repr(self.buf[-600:])


if __name__ == "__main__":
    main()
