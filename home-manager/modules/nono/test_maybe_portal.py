import importlib.util
import io
import json
import os
import pathlib
import tempfile
import unittest
from contextlib import contextmanager
from types import SimpleNamespace
from unittest import mock


MODULE_PATH = os.path.join(os.path.dirname(__file__), "maybe-portal.py")
SPEC = importlib.util.spec_from_file_location("maybe_portal", MODULE_PATH)
maybe_portal = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(maybe_portal)


@contextmanager
def _working_directory(path):
    previous = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(previous)


class _Connection:
    def __init__(self, request):
        self.reader = io.StringIO(json.dumps(request) + "\n")
        self.events = []

    def settimeout(self, _timeout):
        pass

    def makefile(self, *_args, **_kwargs):
        return self.reader

    def sendall(self, payload):
        self.events.append(json.loads(payload.decode("utf-8")))


class MaybePortalTmuxTests(unittest.TestCase):
    def test_popup_exit_codes_map_to_decisions_and_popup_runs_once(self):
        expected = {
            0: "approve",
            1: "deny",
            2: "deny_stop",
            3: "approve_stop",
            4: "approve",
        }

        with tempfile.TemporaryDirectory() as directory, _working_directory(directory):
            os.mkdir(".nono")
            for exit_code, decision in expected.items():
                with self.subTest(exit_code=exit_code):
                    popup_calls = []

                    def fake_popup(command, **_kwargs):
                        popup_calls.append(command)
                        if exit_code == 4:
                            decision_file = next(
                                command[index + 1].split("=", 1)[1]
                                for index, value in enumerate(command)
                                if value == "-e"
                                and command[index + 1].startswith(
                                    "MAYBE_PORTAL_TMUX_DECISION_FILE="
                                )
                            )
                            pathlib.Path(decision_file).write_text(
                                "^echo hello$\n", encoding="utf-8"
                            )
                        return SimpleNamespace(returncode=exit_code, stderr="")

                    with (
                        mock.patch.object(
                            maybe_portal,
                            "_resolve_tmux_client",
                            return_value="/dev/pts/4",
                        ),
                        mock.patch.object(
                            maybe_portal.subprocess, "run", side_effect=fake_popup
                        ),
                        mock.patch.object(maybe_portal.sys, "stderr", io.StringIO()),
                    ):
                        result = maybe_portal._prompt_user(
                            123, directory, "echo hello", ["echo", "hello"], tmux_mode=True
                        )

                    self.assertEqual(result, decision)
                    self.assertEqual(len(popup_calls), 1)
                    self.assertIn("display-popup", popup_calls[0])
                    self.assertIn("-E", popup_calls[0])
                    self.assertIn("-c", popup_calls[0])
                    self.assertNotIn("-t", popup_calls[0])

    def test_human_request_with_no_matching_whitelist_uses_popup(self):
        request = {
            "version": maybe_portal.PROTOCOL_VERSION,
            "argv": ["echo", "hello"],
            "cwd": os.getcwd(),
            "pid": 123,
        }
        with tempfile.TemporaryDirectory() as directory, _working_directory(directory):
            request["cwd"] = directory
            connection = _Connection(request)
            popup_calls = []

            def fake_popup(command, **_kwargs):
                popup_calls.append(command)
                return SimpleNamespace(returncode=0, stderr="")

            with (
                mock.patch.object(
                    maybe_portal, "_resolve_tmux_client", return_value="/dev/pts/4"
                ),
                mock.patch.object(
                    maybe_portal.subprocess, "run", side_effect=fake_popup
                ),
                mock.patch.object(maybe_portal, "_run_subprocess"),
            ):
                result = maybe_portal._handle_connection(connection, tmux_mode=True)

        self.assertFalse(result)
        self.assertEqual(len(popup_calls), 1)

    def test_whitelist_match_skips_tmux_prompt(self):
        with tempfile.TemporaryDirectory() as directory, _working_directory(directory):
            os.mkdir(".nono")
            pathlib.Path(".nono/portal.json").write_text(
                json.dumps(
                    {"version": maybe_portal.PROTOCOL_VERSION, "patterns": ["^echo hello$"]}
                ),
                encoding="utf-8",
            )
            connection = _Connection(
                {
                    "version": maybe_portal.PROTOCOL_VERSION,
                    "argv": ["echo", "hello"],
                    "cwd": directory,
                    "pid": 123,
                }
            )

            with (
                mock.patch.object(maybe_portal.subprocess, "run") as popup,
                mock.patch.object(maybe_portal, "_run_subprocess") as run_command,
                mock.patch.object(maybe_portal.sys, "stderr", io.StringIO()),
            ):
                result = maybe_portal._handle_connection(connection, tmux_mode=True)

        self.assertFalse(result)
        popup.assert_not_called()
        run_command.assert_called_once()

    def test_non_tmux_prompt_does_not_spawn_popup(self):
        with (
            mock.patch.object(maybe_portal, "_read_one_key", return_value="a"),
            mock.patch.object(maybe_portal.subprocess, "run") as popup,
            mock.patch.object(maybe_portal.sys, "stderr", io.StringIO()),
        ):
            result = maybe_portal._prompt_user(
                123, "/tmp", "echo hello", ["echo", "hello"], tmux_mode=False
            )

        self.assertEqual(result, "approve")
        popup.assert_not_called()

    def test_no_attached_client_fails_closed(self):
        with (
            mock.patch.object(maybe_portal, "_resolve_tmux_client", return_value=None),
            mock.patch.object(maybe_portal.subprocess, "run") as popup,
        ):
            result = maybe_portal._prompt_user_tmux(123, "/tmp", "echo hello")

        self.assertEqual(result, "deny")
        popup.assert_not_called()

    def test_portal_ui_decision_keys(self):
        expected = {
            "q": 2,
            "": 1,
            "\x1b": 1,
            "a": 0,
        }

        for key, exit_code in expected.items():
            with self.subTest(key=key), mock.patch.object(
                maybe_portal, "_read_one_key_timeout", return_value=key
            ), mock.patch.object(maybe_portal.sys, "stdout", io.StringIO()):
                self.assertEqual(maybe_portal.run_portal_ui(), exit_code)

        with tempfile.TemporaryDirectory() as directory:
            decision_file = os.path.join(directory, "decision")
            environment = {
                "MAYBE_PORTAL_TMUX_DECISION_FILE": decision_file,
                "MAYBE_PORTAL_TMUX_NONO_DIR": directory,
                "MAYBE_PORTAL_TMUX_PATTERN": "^echo hello$",
            }
            with (
                mock.patch.dict(os.environ, environment, clear=False),
                mock.patch.object(
                    maybe_portal, "_read_one_key_timeout", return_value="w"
                ),
                mock.patch.object(maybe_portal.sys, "stdout", io.StringIO()),
            ):
                self.assertEqual(maybe_portal.run_portal_ui(), 4)
            self.assertEqual(
                pathlib.Path(decision_file).read_text(encoding="utf-8"),
                "^echo hello$\n",
            )


if __name__ == "__main__":
    unittest.main()
