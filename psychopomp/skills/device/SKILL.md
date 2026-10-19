---
name: device
description: Put the app on the user's own jailbroken iPhone, iPad or iPod touch and see it run — OpenSSH from Cydia, the device.env file, xmake device install, launching the app, reading its log file and crash logs, root versus mobile, and keeping the user's data private. Use after the skill package when PROJECT.md says the app goes onto the user's device, or whenever the user asks to install, run, test or debug the app on their phone or tablet, or to read a crash from it.
---

# The app on the user's device

Charon's `xmake device` reaches one jailbroken device over SSH: it installs the project's packages,
removes them, runs a shell command as root, reads the system log over USB, and says where the device
is. It has **no launch, no tap, no screenshot and no file copy**: those are done as this skill says,
over SSH or by the user's own hand. Everything here touches a device that holds the user's life:
read nothing that is not the app's.

Read `PROJECT.md` first: the device (model identifier and release), the app's bundle identifier and
package name, and the `## Progress` evidence of the skills `build`, `emulate`, `checks` and `package`.
Do not touch the device before the user says it is connected and you may.

## 1. Prepare the device (the user does this, on the device)

1. The device is jailbroken and Cydia opens. Ask the user; do not guess.
2. In Cydia, search **OpenSSH** and install it. It starts an SSH server on port 22.
3. On these releases the SSH login is `root` with the password `alpine`, the same for the `mobile`
   user — known to everyone. Ask the user to change both now from their own Terminal, typing the new
   passwords themselves:

   ```
   ssh -o HostKeyAlgorithms=+ssh-rsa -o KexAlgorithms=+diffie-hellman-group14-sha1,diffie-hellman-group1-sha1 -o Ciphers=+aes128-cbc,3des-cbc root@DEVICE_ADDRESS
   passwd            # root
   passwd mobile
   ```

   Over USB (step 2 starts the tunnel), the address is `-p 2222 root@127.0.0.1`.

   The `-o` options admit the old key exchange and ciphers an old OpenSSH speaks; `xmake device`
   adds the same ones itself.
4. Key login instead of a password is the user's choice: an RSA key (`ssh-keygen -t rsa`) appended to
   `/var/root/.ssh/authorized_keys` on the device. With a key, `device.env` carries no password.

How to know it worked: the user's `ssh` reaches a `#` prompt with the new password.

## 2. Tell Charon which device: `device.env`

`xmake device` reads `device.env` in the project root (`device.NAME.env` with `-d NAME` or
`CHARON_DEVICE=NAME` for a second device). Lines are `KEY=VALUE`; `export`, quotes and `#` comments
are allowed. A key missing from the file is taken from the environment.

| Key | Meaning | Default |
| --- | --- | --- |
| `DEVICE_HOST` | the device's address, or `127.0.0.1` for a USB tunnel | `127.0.0.1` |
| `DEVICE_PORT` | the SSH port: `22` over Wi-Fi, the tunnel's port over USB | `2222` |
| `DEVICE_UDID` | the device's UDID, which the USB tunnel needs | empty |
| `DEVICE_PASSWORD` (or `DEVICE_PASS`) | the root password; empty means key login | empty |

- **USB (recommended):** `brew install libimobiledevice` (it brings `iproxy`), plug the device in,
  run `xmake device list` — each attached device's UDID, model, release and tunnel. Write
  `DEVICE_UDID=<that UDID>` and leave host and port at their defaults. When nothing listens on the
  port, Charon starts `iproxy 2222 22 -u <UDID>` itself (without `DEVICE_UDID` only when exactly one
  device is attached).
- **Wi-Fi:** `DEVICE_HOST=<the address in Settings → Wi-Fi → the network's details>` and
  `DEVICE_PORT=22`.
- The file holds a password: add `device*.env` to the project's `.gitignore` before writing it, and
  `chmod 600 device.env`. Never copy the UDID, the address or the password into `PROJECT.md`, a
  commit, a log you keep, or a message.

Without the file and without `DEVICE_HOST`, every command stops with `nothing names a phone` — on
purpose: `127.0.0.1:2222` could reach whichever device a tunnel happens to serve.

How to know it worked:

```
xmake device where                               # host:port, no connection made
xmake device run "uname -m"                      # the model identifier, e.g. iPhone4,1
```

The model must be the one `PROJECT.md` names. The release is in `xmake device list` (USB).

## 3. Install

From the project directory:

```
xmake device -y install
```

It builds, writes every package the project declares (the app's, its dependencies — the
`org.charon.apple-backports` and shared Swift runtime packages `xmake deb` carries — and any probe
or test stand with a control file of its own), refuses when `/Applications/<Name>.app` on the device
belongs to another bundle identifier, copies each `.deb` to `/tmp` on the device, runs `dpkg -i`, and
then `su mobile -c uicache` so SpringBoard shows the icon.

How to know it worked: one `installed <package>_<version>_iphoneos-arm.deb on <host:port>` line per
package (over Wi-Fi that line holds the device's address: replace it with `<device>` in any log you
keep), then

```
xmake device run "dpkg -s <package>"             # Status: install ok installed, and the Version you built
```

A refusal naming another bundle identifier (`/Applications/<Name>.app on the phone is <other id>,
and this package installs <id> over it`): find the package that owns it with
`xmake device run "dpkg -S /Applications/<Name>.app"`. If it is one you installed, remove it
(step 7); if not, it is the user's, so ask them before removing anything. Installing over it makes
SpringBoard lose the app until a reboot.

## 4. Launch

**Charon has no launch action today** (`xmake device` takes only install, uninstall, log, run, where,
list, claim and release), and iOS has no public way to open an app from a shell. The launch is the
native one: **the user taps the icon.** It is their device, and SpringBoard's own launch is the one
the app will always get. Tell the user what to look for and what to do on each screen, and ask what
they see. Do not reach for a private-API launcher to automate it; say plainly that launching from
the host is missing, and move on.

An app that vanishes at launch without a crash report failed to load. The build's import check
(skill `build`) should have refused that already — go back there first. To read dyld's own message,
which a SpringBoard launch never shows, start the executable once as the user SpringBoard would, and
stop it after a few seconds:

```
xmake device run "su mobile -c '/Applications/<Name>.app/<Name> & sleep 5; kill \$!'"
```

`Library not loaded` or `Symbol not found` on stderr names what is missing. This is a diagnosis, not
a launch: the app does not get the screen.

## 5. What the app says

- The app's own log is a file it writes with `printf` + `fflush` (the skill `checks` says how, and why a
  file rather than `NSLog`). Read it with `xmake device run "cat <path>"` and keep the output under
  `.logs/` in the project.
- `xmake device -s 30 log <TEXT>` streams the device's system log over USB for 30 seconds (it needs
  `idevicesyslog`, from `libimobiledevice`), filtered to lines holding `TEXT`. Always give `TEXT` —
  the app's executable name: the unfiltered log carries other apps' traffic.
- `xmake device run "<command>"` fails with the remote command's exit status, which `ssh` passes
  through: `1` is usually the command's own failure, `127` a command the device does not have, `255`
  `ssh` itself (no connection). A jailbroken device may lack host tools such as `head`, `tail` or
  `timeout`: trim output on the host, `xmake device run "..." | tail`.

## 6. Crash logs

```
xmake device run "ls -t /var/mobile/Library/Logs/CrashReporter/<Name>_*"
xmake device run "cat /var/mobile/Library/Logs/CrashReporter/<the newest of those files>" > .logs/crash-<date>.txt
```

Let the device's shell match only the app's own reports (`<Name>_*`, `<Name>` the executable): a
listing of the whole folder names every app the user ran and when. A process that runs as root (a
probe) leaves its report in `/var/logs/CrashReporter/<probe>_*` instead. Read
the exception type, the crashed thread and the frames in the app's image; open no other app's report.
For a crash you can reproduce in a probe, the emulator's debugger names the frames (skill `emulate`).

## 7. Uninstall

```
xmake device uninstall <package>                 # dpkg -r, then the shared runtime packages nothing needs any more
xmake device --keep uninstall <package>          # dpkg -r of the named packages only
```

It never removes `org.charon.apple-backports`: other programs built with Charon use it.

## 8. root and mobile

- SSH, and so every `xmake device` command, runs as **root**. An app started by SpringBoard runs as
  **mobile**.
- A directory made over SSH belongs to root, and an app that writes into it dies or fails silently.
  Create what the app writes as mobile, and check:

  ```
  xmake device run "su mobile -c 'mkdir -p <dir> && touch <dir>/probe && rm <dir>/probe' && echo writable"
  ```

- `uicache` runs as mobile (`su mobile -c uicache`), which is what `xmake device install` does.

## 9. Privacy — never lifted

- Read, copy or log only the app's own files, its own log and its own crash reports. Never open
  messages, mail, contacts, call history, photos, notes, accounts, keychains or other apps' data,
  even when a command could.
- No screenshot of the user's screen, no recording, no system-log capture without the app's filter.
- The UDID, the address, the password and the device's name stay in `device.env`; nothing else.
- Leave the device as you found it: remove the probes and test stands you installed (step 7); ask
  before removing anything you did not install.

## 10. Record

Update `PROJECT.md` `## Progress`, line `device`: the package and version installed, the model and
release it runs on (no UDID, no address), how it was launched, and the evidence — the log file you
read or the user's own words on what they saw. Then, if the app is also published, follow the skill
`cydia-repo`.

## Traps

- Guessing `127.0.0.1:2222` without `device.env` → write the file; a tunnel on that port may serve
  another device, and "Permission denied" then means the wrong device, not the wrong password.
- `device.env` committed → it holds the root password; `.gitignore` it before it exists.
- Expecting `xmake device` to launch, tap or take a shot → it cannot; the user taps, and you read the
  app's log file.
- `NSLog` as the app's report → after a tap it does reach the system log (measured on iPhone 4S
  6.1.3), but only the streamed log, over USB, among every other app's lines; read the app's own
  `printf` file instead, and filter `xmake device -s 30 log <TEXT>` by the app's name when you
  need the log.
- An app that dies at launch with no crash report → run the executable as mobile once (step 4);
  dyld's message goes to stderr only.
- A directory created over SSH for the app → root owns it; create it as mobile and check with `touch`.
- Wi-Fi on a network the user does not control → `xmake device` does not verify the device's host key;
  use USB there.
- An option after the action (`xmake device uninstall --keep <package>`, `xmake device log -s 30 <TEXT>`)
  → put every option before the action. Reason: xmake hands what follows the action to it as its
  arguments, so `--keep` reaches `dpkg -r` and fails there, and `-s 30 <TEXT>` as a whole becomes
  the text the log filters on, which no line holds.
- `-s` with `run` → it bounds `log` only; a `run` command that never ends blocks: end it yourself
  (`xmake device run "<command> & sleep N; kill \$!"`: the `\` keeps the Mac's shell from
  expanding `$!` before the command reaches the device).
