#!/usr/bin/env python3
"""Reach the phone a port names in its device.env.

    device.py --root PORT [--device NAME] run [SECONDS] COMMAND...
    device.py --root PORT [--device NAME] copy LOCAL REMOTE
    device.py --root PORT [--device NAME] fetch REMOTE LOCAL
    device.py --root PORT [--device NAME] where
    device.py --root PORT [--device NAME] log [SECONDS] [TEXT]

A port with more than one phone keeps device.NAME.env beside device.env and picks
one with --device NAME or CHARON_DEVICE=NAME for the whole shell.

Callers import it and bind a port first: bind(root), then run(20, "uiopen ..."),
copy(...), fetch(...). A dead USB tunnel is brought back before every command,
because a refused connection reads in a log exactly like a crashed browser.
"""
import os
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

ENV_FILE = "device.env"
CHOSEN = "CHARON_DEVICE"
DEFAULTS = {"host": "127.0.0.1", "port": "2222", "password": "", "udid": ""}

SSH_OPTIONS = [
    "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
    "-o", "LogLevel=ERROR", "-o", "ConnectTimeout=8",
    "-o", "HostKeyAlgorithms=+ssh-rsa", "-o", "PubkeyAcceptedKeyTypes=+ssh-rsa",
    "-o", "KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1",
    "-o", "Ciphers=+aes128-cbc,3des-cbc",
    "-o", "ControlMaster=auto", "-o", "ControlPersist=60",
    "-o", "ControlPath=/tmp/rev-ssh-%h-%p",
]

SETTINGS = dict(DEFAULTS)
HOST = SETTINGS["host"]
PORT = SETTINGS["port"]
ROOT = None


def _read_env_file(path):
    values = {}
    if not path.is_file():
        return values
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):].lstrip()
        key, sep, value = line.partition("=")
        if not sep or not key.isidentifier():
            continue
        value = value.strip()
        if value[:1] in ("'", '"'):
            quote = value[0]
            end = value.find(quote, 1)
            value = value[1:end] if end > 0 else value[1:]
        else:
            value = value.split(" #", 1)[0].split("\t#", 1)[0].strip()
        values[key] = value
    return values


def env_file(root, name=None):
    chosen = name or os.environ.get(CHOSEN)
    return Path(root) / (f"device.{chosen}.env" if chosen else ENV_FILE)


def _settings(root, name=None):
    env = dict(os.environ)
    if root is not None:
        env.update(_read_env_file(env_file(root, name)))
    return {
        "host": env.get("DEVICE_HOST") or DEFAULTS["host"],
        "port": env.get("DEVICE_PORT") or DEFAULTS["port"],
        "password": env.get("DEVICE_PASSWORD") or env.get("DEVICE_PASS") or DEFAULTS["password"],
        "udid": env.get("DEVICE_UDID") or DEFAULTS["udid"],
    }


def bind(root, name=None):
    global ROOT, HOST, PORT
    ROOT = Path(root).expanduser().resolve()
    named = env_file(ROOT, name)
    if not named.is_file() and "DEVICE_HOST" not in os.environ:
        known = sorted(path.name for path in ROOT.glob("device*.env"))
        raise RuntimeError(f"nothing names a phone: {named} does not exist and DEVICE_HOST is unset"
                           f"{' (this port has ' + ', '.join(known) + ')' if known else ''}. "
                           f"{DEFAULTS['host']}:{DEFAULTS['port']} is not a safe guess - on a machine with a USB "
                           f"tunnel it reaches whichever phone that tunnel serves.")
    SETTINGS.clear()
    SETTINGS.update(_settings(ROOT, name))
    HOST = SETTINGS["host"]
    PORT = SETTINGS["port"]
    return SETTINGS


def configure(host=None, port=None, password=None, udid=None):
    global HOST, PORT
    overrides = {"host": host, "port": port, "password": password, "udid": udid}
    SETTINGS.update({key: str(value) for key, value in overrides.items() if value is not None})
    HOST = SETTINGS["host"]
    PORT = SETTINGS["port"]
    return SETTINGS


def where():
    return f"{SETTINGS['host']}:{SETTINGS['port']}"


def _host():
    return SETTINGS["host"]


def _port():
    return SETTINGS["port"]


def _port_open(host, port):
    try:
        with socket.create_connection((host, int(port)), timeout=2):
            return True
    except OSError:
        return False


def tunnel():
    host, port = _host(), _port()
    if host != "127.0.0.1" or _port_open(host, port) or not shutil.which("iproxy"):
        return
    udid = SETTINGS["udid"]
    if not udid and shutil.which("idevice_id"):
        attached = subprocess.run(["idevice_id", "-l"], capture_output=True, text=True).stdout.split()
        if len(attached) == 1:
            udid = attached[0]
    if not udid:
        print(f"tunnel on {port} is down and DEVICE_UDID is not set", file=sys.stderr)
        return
    subprocess.run(["pkill", "-f", f"iproxy {port} "], capture_output=True)
    with open(f"/tmp/iproxy-{port}.log", "w") as log:
        subprocess.Popen(["iproxy", port, "22", "-u", udid], stdout=log, stderr=subprocess.STDOUT,
                         start_new_session=True)
    time.sleep(3)


def _authenticated(argv):
    if not SETTINGS["password"]:
        return argv, None
    env = dict(os.environ, SSHPASS=SETTINGS["password"])
    return ["sshpass", "-e", *argv], env


def ssh_command(*extra):
    return ["ssh", *SSH_OPTIONS, "-p", _port(), *extra, f"root@{_host()}"]


def run(timeout, command, capture=True, input=None, check=False):
    tunnel()
    argv, env = _authenticated([*ssh_command(), command])
    try:
        result = subprocess.run(argv, env=env, input=input, timeout=timeout,
                                capture_output=capture, text=isinstance(input, str) or input is None)
    except subprocess.TimeoutExpired as expired:
        result = subprocess.CompletedProcess(argv, 124, expired.stdout or "", expired.stderr or "")
    if check and result.returncode:
        raise subprocess.CalledProcessError(result.returncode, command, result.stdout, result.stderr)
    return result


def output(timeout, command):
    return run(timeout, command).stdout or ""


def copy(local, remote, capture=True):
    tunnel()
    argv, env = _authenticated(["scp", *SSH_OPTIONS, "-P", _port(), str(local), f"root@{_host()}:{remote}"])
    return subprocess.run(argv, env=env, capture_output=capture, text=True).returncode == 0


def fetch(remote, local):
    tunnel()
    argv, env = _authenticated(["scp", *SSH_OPTIONS, "-P", _port(), f"root@{_host()}:{remote}", str(local)])
    return subprocess.run(argv, env=env, capture_output=True, text=True).returncode == 0


def pipe_into(producer, command, cwd=None):
    tunnel()
    argv, env = _authenticated([*ssh_command(), command])
    source = subprocess.Popen(producer, cwd=cwd, stdout=subprocess.PIPE,
                              env={**os.environ, "COPYFILE_DISABLE": "1"})
    remote = subprocess.Popen(argv, env=env, stdin=source.stdout)
    source.stdout.close()
    remote.wait()
    source.wait()
    return remote.returncode or source.returncode


def reverse_tunnel(port):
    tunnel()
    argv, env = _authenticated([*ssh_command("-N", "-R", f"{port}:127.0.0.1:{port}")])
    return subprocess.Popen(argv, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def reachable(timeout=12):
    return "ok" in output(timeout, "echo ok")


def log(seconds, text=""):
    if not shutil.which("idevicesyslog"):
        raise RuntimeError("idevicesyslog is not installed; brew install libimobiledevice reads the phone's log over "
                           "USB without Xcode")
    argv = ["idevicesyslog"] + (["-u", SETTINGS["udid"]] if SETTINGS["udid"] else [])
    if text:
        argv += ["-m", text]
    try:
        return subprocess.run(argv, timeout=seconds).returncode
    except subprocess.TimeoutExpired:
        return 0


def restart_safari(settle):
    run(20, "killall MobileSafari 2>/dev/null")
    time.sleep(settle)


def open_url(url):
    run(20, f"uiopen '{url}'")


def main(argv):
    root, name = Path.cwd(), None
    while argv[:1] in (["--root"], ["--device"]) and len(argv) > 1:
        if argv[0] == "--root":
            root = argv[1]
        else:
            name = argv[1]
        argv = argv[2:]
    try:
        bind(root, name)
    except RuntimeError as absent:
        print(absent, file=sys.stderr)
        return 2
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if argv else 2
    verb, args = argv[0], argv[1:]
    if verb == "run":
        timeout = 60
        if args and args[0].isdigit():
            timeout, args = int(args[0]), args[1:]
        if not args:
            print("run needs a command", file=sys.stderr)
            return 2
        return run(timeout, " ".join(args), capture=False).returncode
    if verb == "copy" and len(args) == 2:
        return 0 if copy(*args) else 1
    if verb == "fetch" and len(args) == 2:
        return 0 if fetch(*args) else 1
    if verb == "where" and not args:
        print(where())
        return 0
    if verb == "log":
        seconds = 15
        if args and args[0].isdigit():
            seconds, args = int(args[0]), args[1:]
        try:
            return log(seconds, " ".join(args))
        except RuntimeError as missing:
            print(missing, file=sys.stderr)
            return 2
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
