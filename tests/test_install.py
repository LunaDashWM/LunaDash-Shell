"""Exercise generated launchers without installing or running SlintLu.

Run on Linux with: python3 -m unittest discover -s tests -v
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
PATH_NAMES = (
    "plain",
    "with spaces",
    "apostrophe's",
    'double"quote',
    "$HOME",
    "$(touch substitution-ran)",
    "`touch backtick-ran`",
    "back\\slash",
    "line\nbreak",
)
EXTRA_ARGS = ["--no-reload", "two words", "", "$HOME", 'a"b', "a'b", "line\nbreak"]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="lunadash-install-test-")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.home = self.work / "home"
        self.home.mkdir()
        self.bin = self.work / "bin"
        self.bin.mkdir()
        self.record = self.work / "arguments"
        self.env = {
            **os.environ,
            "HOME": str(self.home),
            "XDG_DATA_HOME": "",
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "LAUNCHER_ARGS_FILE": str(self.record),
        }
        self.make_slintlu(self.bin / "slintlu")

    def make_slintlu(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            '#!/bin/sh\nprintf \'%s\\0\' "$@" > "$LAUNCHER_ARGS_FILE"\n',
            encoding="utf-8",
        )
        path.chmod(0o755)

    def run_command(self, args, env):
        result = subprocess.run(
            args, cwd=self.work, env=env, capture_output=True, text=True, timeout=30
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def install(self, *args, env=None):
        self.run_command(["/bin/bash", str(ROOT / "install.sh"), "--no-check", *args], env or self.env)

    def check_launcher(self, launcher, config, env=None):
        self.assertTrue((config / "shell.slint").is_file())
        self.assertTrue(os.access(launcher, os.X_OK))
        self.record.unlink(missing_ok=True)
        for marker in ("substitution-ran", "backtick-ran"):
            (self.work / marker).unlink(missing_ok=True)
        self.run_command(["/bin/sh", str(launcher), *EXTRA_ARGS], env or self.env)
        self.assertEqual(
            self.record.read_bytes().split(b"\0")[:-1],
            [os.fsencode(arg) for arg in ["--config", str(config), *EXTRA_ARGS]],
        )
        self.assertFalse((self.work / "substitution-ran").exists())
        self.assertFalse((self.work / "backtick-ran").exists())

    def test_prefix_paths_are_literal(self):
        for name in PATH_NAMES:
            with self.subTest(name=name):
                prefix = self.work / "prefixes" / name
                self.install("--prefix", str(prefix))
                self.check_launcher(prefix / "bin/lunadash-shell", prefix / "share/lunadash/shell")

    def test_xdg_data_home_paths_are_literal(self):
        for name in PATH_NAMES:
            with self.subTest(name=name):
                data = self.work / "data" / name
                env = {**self.env, "XDG_DATA_HOME": str(data)}
                self.install(env=env)
                self.check_launcher(self.home / ".local/bin/lunadash-shell", data / "lunadash/shell", env)

    def test_destdir_is_not_in_runtime_config(self):
        stage = self.work / "stage"
        self.install("--prefix", "/usr", "--destdir", str(stage))
        self.assertTrue((stage / "usr/share/lunadash/shell/shell.slint").is_file())
        self.run_command(["/bin/sh", str(stage / "usr/bin/lunadash-shell"), *EXTRA_ARGS], self.env)
        self.assertEqual(
            self.record.read_bytes().split(b"\0")[:-1],
            [os.fsencode(arg) for arg in ["--config", "/usr/share/lunadash/shell", *EXTRA_ARGS]],
        )

    def test_cargo_fallback_with_literal_home(self):
        home = self.work / "home with \\backslash and 'quote"
        self.make_slintlu(home / ".cargo/bin/slintlu")
        env = {**self.env, "HOME": str(home)}
        self.install(env=env)
        empty_bin = self.work / "empty-bin"
        empty_bin.mkdir()
        self.check_launcher(
            home / ".local/bin/lunadash-shell",
            home / ".local/share/lunadash/shell",
            {**env, "PATH": str(empty_bin)},
        )


if __name__ == "__main__":
    unittest.main()
