# The reCAPTCHA SDK in a helper process: design

A design, written before any code. It replaces the plan of loading the translated SDK into Telegram's own process
([library mode](../reference/recompiler/library-mode.md)). Every statement is marked **Measured** (with where),
**Reasoned** or **Not known**; the last section orders the measurements that decide the open ones.

## Why

**Measured** (the Telegram session, 2026-11-19, `telegram-build/.agent-work/runs/m4-pass123/panelmap/` and `m4pts/`):
once a session has opened the media panel, Telegram's heap has grown by 111 MiB of address space, 87% of it touched,
and libmalloc does not give the arenas back when the panel closes. With the panel open and no library, 36 MiB are
free below `0x30000000`; the library needs a 14 MiB reservation at a fixed address (`0x2e000000`), and in the failed
pass the largest free block before `xl_load` began at `0x2e44e000`, inside that range (`m4pts.out`, the line
`RMAP before-xl_load`). No footprint of the library inside the process survives a session that opened the panel
once. A process of its own has an empty address space every time.

**Measured** (the coordinator, same day, `runs/spawn-facts/`): Telegram as installed runs as `mobile` from
`/var/stash` with no seatbelt profile, `sandbox_check` allows `process-fork` and `process-exec`, and `posix_spawn` of
a copy of `/bin/true` placed inside the `.app` ran and exited 0.

## The program

`rcsdk` with a pipe instead of a command line: the host program of the check `recaptchareal`
(`recompiler/tests/recaptchareal/main.m`), a plain Foundation executable with its own armv7 Swift runtime, no
`UIApplication`, the main thread in `CFRunLoopRunInMode`. It calls `xl_load` once, first thing in `main`, on
`Frameworks/RecaptchaEnterprise.dylib` of the bundle it lies in; no `xl_reserve` before it and no retry: the address
space holds the program and its libraries and nothing else, so the fixed range is free or the process is broken. Then
`xl_find_class`, `fetchClientWithSiteKey:completion:` once per site key (kept, as Telegram's own code keeps it) and
`executeWithAction:completion:` per request.

**Measured** (`rcsdk` on drop31, 60 runs on the 4S,
`telegram-build/.agent-work/recaptcha-real/drop31-stress-60-run.txt`; run by the device module, so as root from the
scratch folder, with a 40-character key the server refuses): 60 of 60
exit 0; load 1.64 to 1.70 s; `fetchClient` answers with a client in 0.20 to 0.41 s; `execute` answers in 0.28 to
0.76 s with `com.google.recaptcha 2 'Invalid Site Key.'`; resident 3.4 MB at start, 15.4 MB after the load, 24.4 MB
at the most. `rcsdk` ran on no later drop (the Telegram session, 2026-11-19).

**Measured in the app, on the same refused path** (`runs/m4-pass123/m4pts.out`, 2026-11-19, two runs): `fetchClient`
3.93 and 3.72 s, `execute` 2.88 and 3.18 s, with the same answer. That is about ten times `rcsdk`'s times. The app's
runs were on a drop before the routing fix (drop39), which removed a lock convoy between two threads; whether that is
the whole difference is not traced.

**No run anywhere has returned a token.** Every `execute`, in `rcsdk` and in the app, was given a key the server
refuses. The key Telegram uses is not in its sources: it arrives in the text of the server's error 403
`RECAPTCHA_CHECK_<method>__<siteKey>` to a sign-in request (`submodules/MtProtoKit/Sources/MTRequestMessageService.m`,
line 1018), and a search of the sources for a 40-character key constant finds none. A sign-in request is an account
action, which the owner forbade. So whether the path to a token goes through the `WKWebView` backport, `UIDevice` or
the keychain, and whether those answer in a process without `UIApplication`, is **not known** and cannot be measured
until the owner gives a key (2 below).

**Not proved by `rcsdk`** either, each a measurement below: running as `mobile` from inside the `.app`; the bundle
identifier the SDK then reads; being started by the app.

## Protocol

**Reasoned.** The app starts the helper with `posix_spawn` and file actions: the read end of one pipe becomes the
helper's descriptor 0, the write end of a second its descriptor 1, descriptor 2 goes to the runtime's log file or
`/dev/null`, and `POSIX_SPAWN_CLOEXEC_DEFAULT` closes everything else, so that none of Telegram's sockets and
database files reaches the helper (the SDK's `spawn.h` has the flag and marks its companion
`posix_spawn_file_actions_addinherit_np` as available from iOS 4.3; on the phone it is measurement 4; if it fails
there, the helper closes every descriptor above 2 before it loads anything). The arguments are the path of the
library and the protocol version; the environment is empty but for the `XL_*` switches. The app sets
`F_SETNOSIGPIPE` on its write end, so that a request written to a helper that has died answers `EPIPE` and does not
end Telegram with `SIGPIPE` (Telegram's sources ignore the signal nowhere and set `SO_NOSIGPIPE` on their sockets
only: the Telegram session's reading); the helper ignores `SIGPIPE` for the same reason.

A message is one line of UTF-8, fields separated by a tab, ended by a newline; a tab, a newline or a percent sign
inside a field is percent-escaped; a line is at most 64 KiB (a token is a few KiB of ASCII).

| Direction | Line | Meaning |
|---|---|---|
| helper to app | `ready` version, sha256 of the library, milliseconds of the load | sent once; the app sends nothing before it |
| helper to app | `failed` name, text | sent once in place of `ready`; the helper then exits |
| app to helper | `token` id, site key, action, milliseconds allowed | several may be pending; the helper answers each id once |
| helper to app | `token` id, `ok`, the token | |
| helper to app | `token` id, `error`, name, domain, code, text | names: `FETCH_FAILED`, `EXECUTE_FAILED`, `TIMEOUT`, `BAD_REQUEST`; domain, code and text are the SDK's `NSError` |
| app to helper | `quit` | the helper exits 0 |

**Timeouts.** Telegram waits 15 s for a token and then reports `RECAPTCHA_TIMEOUT`
(`TelegramCore/Sources/Network/Network.swift`, [the study](recaptcha-sdk-on-ios6.md), section 8). The app side owns
the deadline: it answers its caller at 13 s with a named error whatever the helper does, and a helper that has not
answered a request by then is killed. The helper has the same number in the request and answers `TIMEOUT` itself
when the SDK has not called back, so that a slow SDK is told from a dead helper.

**One helper per login, serving several tokens.** The key reaches the app only in the server's demand, so before it
nothing but the spawn and the load can happen. A helper that the app starts when the login screen appears (a
heuristic: the protocol gives no earlier sign, and the app knows neither the method nor the key until the 403) has
loaded by the time the demand comes, and the 15 s are spent on `fetchClient` and `execute` alone: 0.5 to 1.2 s by
`rcsdk`'s numbers, 6.8 and 6.9 s in the app's two runs, all on the refused path. A helper started by the demand adds
the spawn and 1.7 s of load to that. A second token for the same key costs the `execute` alone, because the helper
keeps the client per key as the app does (`recaptchaClientsBySiteKey` in `AppDelegate.swift`). The helper exits on
`quit`, when its descriptor 0 ends, or after 120 s without a request, so that it does not hold its memory through a
session. Not measured: the spawn itself, and every time on the path that returns a token.

## Lifetime

**Reasoned**, to be measured (5 below).

- The app dies or is killed: the write end of the request pipe closes with it, the helper reads end-of-file on
  descriptor 0 and exits. That holds for every way a process ends, so no orphan can outlive the app by more than the
  read. The helper also keeps `alarm()` as `rcsdk` does, as a second bound.
- The helper hangs or crashes: the app sees end-of-file on the answer pipe or its own deadline, sends `SIGKILL`,
  reaps it (`waitpid` on a dispatch source of the process, so no zombie stays), answers every pending id with
  `HELPER_DIED`, and starts a new helper for the next request, once; a second death in a row is reported and not
  retried within that login.
- The app goes to the background: SpringBoard suspends the app; the helper is not an application and keeps
  running. A pending request finishes and its answer waits in the pipe until the app is resumed. Whether iOS 6 kills
  or stops a child of a suspended app is not known.
- Who kills whom: only the app kills the helper; the helper never signals the app.

## Identity

**Reasoned.** The executable lies at the top of `Telegram.app`, next to `Info.plist`, so `NSBundle.mainBundle` is
Telegram's bundle and the SDK reads Telegram's bundle identifier, version and `infoDictionary`; in a subfolder the
main bundle would be that folder and the identifier nil, which the server answers with `Invalid Package Name.` (a
string of the SDK). Its code signature is `ldid -S` with the entitlements file of Telegram's own executable (the
signed pass keeps it; it has `application-identifier` and no `keychain-access-groups`), so that `SecItemAdd` and
`SecItemCopyMatching` of the SDK ask with the same identity as in the app.

What the SDK asks the system for ([the study](recaptcha-sdk-on-ios6.md), section 4), and what is known for a process
without `UIApplication`:

| Asked | Known |
|---|---|
| `NSURLSession` (the backport), reachability | **Measured**: the 60 runs of `rcsdk` got their answer from the network path |
| `NSUserDefaults standardUserDefaults` | closed by design: the helper answers it with a domain of its own (below) |
| Keychain (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`, this-device-only) | **Not known** for a program signed with `ldid` |
| `DCAppAttestService` | **Measured** in the app: the backport answers unsupported; the same code in the helper |
| `UIDevice` (`identifierForVendor`, `model`), `WKWebView` and its script messages | **Not known**: in the module, not on the static path; whether a token needs them, and whether they answer outside an application, decides the route (2 below) |

**Preferences.** With Telegram's bundle identifier, `standardUserDefaults` in the helper would be Telegram's own
domain, written from a second process. The helper does not use it. Before `xl_load` it replaces
`+[NSUserDefaults standardUserDefaults]` in its own process with a method that answers
`[[NSUserDefaults alloc] initWithSuiteName:]` of a domain of its own, the bundle identifier with `.recaptcha` added.
The Foundation backport gives that initializer on iOS 6, a subclass over `CFPreferences` with the suite as the
application (`frameworks/Backports/src/Foundation/NSUserDefaults+SuiteName.m`). The SDK asks the class for
`standardUserDefaults` in one place and passes the object on (`RCfni.rcfnp`, 0x2c0b8 in the arm64 SDK), and the
translated code sends that message to the host's class, so it gets the helper's object.

**Measured in the SDK's disassembly**, what it keeps there:

- a queue of client events: an array of strings under the key `RCA_client_events` plus a suffix
  (`stringArrayForKey:`, `setObject:forKey:`), and at start `dictionaryRepresentation`, used once, to find every
  other key with that prefix and `removeObjectForKey:` it;
- a store of string pairs (`RCdku`): `setObject:forKey:` for each pair of a dictionary, and `stringForKey:`. Its key
  names are not literals in the code and were not traced; the preferences file `rcsdk` leaves on the phone names
  them (asked for with measurement 1).

`valueForKey:` and `setValue:forKey:` are sent too (three and five places); their receivers were not traced. The
suite object is a real `NSUserDefaults`, so it answers whatever the standard one does.

What the server sees does not depend on the domain's name: the package name comes from `NSBundle` (`mainBundle`,
`bundleIdentifier`), not from the preferences. It may depend on the content being kept from one helper to the next
(the queue, the pairs), so the domain is a file that persists, not a dictionary in memory. On this route Telegram's
process never runs the SDK, so the helper's domain is the only place those keys ever are.

## Memory

**Measured**: the helper's resident size on the refused-key path is 24.4 MB (above). **Not known**: its size on the
path that returns a token, and what jetsam does with a child of an application when Telegram itself is at 230 MB
resident on a 512 MB phone. The library's 57.6 MB file is mapped, not read: the resident figure is what counts.

## Signing and install

**Measured**: programs signed with `ldid -S` run on this phone as root from the scratch folder (every device check of
the corpus). **Not known**: the same as `mobile` from the app's folder. The helper and the two library files are
added to the `.app` by the Telegram session's install step; the app's own executable no longer links the loader.

## What the in-process path keeps

Nothing. The app does not load the library, does not reserve its range and does not contain the loader; the 14 MiB
reservation, the host part and the registry leave Telegram's address space, which is the point. A second path kept
as a fallback would be the one path known not to coexist with the panel, and would double what each drop has to
pass. The glue's retry loop for `RANGE_BUSY` and `DLOPEN_FAILED` (`Native/recaptcha_retry.c`: attempts at 0, 1 and
3 s, then every 15 s) is dead code on this route and goes with its test: a helper cannot find its range busy. What
replaces it is the rule above, one restart of a helper that died, and a named error (`HELPER_UNAVAILABLE` when the
spawn itself fails) where the glue returned its sticky load status.

## Measurements, cheapest first

Each is one run on the phone; 1, 3 and 4 need no new code, only `rcsdk` and a drop. They run first, on drop40 (the
coordinator, 2026-11-19); what to copy, the commands, what a pass looks like and what each line means are in
`telegram-build/.agent-work/recaptcha-real/drop40-rcsdk-kit/README.txt`, beside the two signed builds of `rcsdk`.

1. `rcsdk` in a subfolder of `Telegram.app`, run as `mobile` from there, with the refused key. Shows: a program of
   ours signed with `ldid` runs there (with Telegram's entitlements, and with none), `xl_load` succeeds in an empty
   address space as `mobile`. **Ends the route** if it is killed at start under every signature we can make, or
   cannot load. A subfolder, not the top of the `.app`: there `rcsdk` has no bundle identifier and writes nothing
   into Telegram's preferences, which no measurement may do; the identifier at the top waits for the helper build,
   which has the domain of its own.
2. The same with Telegram's site key (a request to Google, which the owner allows from this phone). Shows: a token,
   or the error, for a process that is not an application. **Ends the route** if the path to a token needs what only
   an application has (the web view, the vendor identifier) and neither answers here. This is the largest unknown.
   It cannot run: nobody here has a key the server accepts, and the only source is an account action (above). It
   waits for the owner's word.
3. The resident lines of run 1 (`fetched`, `executed`), and the same run while Telegram is frontmost with the panel
   open. **Ends the route** if Telegram or the helper is killed for memory there, twice in a row. The size on the
   path that returns a token stays unknown until 2.
4. `posix_spawn` of `rcsdk` from Telegram's process with the two pipes and `POSIX_SPAWN_CLOEXEC_DEFAULT` (the probe
   that started `/bin/true`): it loads and answers, and its descriptors are 0, 1 and 2 only. **Ends the route** if a
   child of the app cannot load the library (a limit inherited from the app).
5. Lifetime, with the first helper build: the app killed (by signal, and by the user) during a request, the helper
   gone within a second; the app sent to the background during a request, the answer there on return; a helper
   stopped with `SIGSTOP`, the app's deadline fires at 13 s and no process is left. Nothing here ends the route; it
   fixes the numbers.
6. Preferences and keychain, with the first helper build: Telegram's preferences file is the same before and after a
   request (the helper's keys are in its own domain), and the keychain calls of the SDK answer for a program signed
   with `ldid`. Nothing here ends the route: a keychain that refuses is answered by the SDK's own error path, to be
   read then.
7. Times, with the first helper build: five requests from a helper started by the request and five from one that had
   loaded before it. The route stands if both are under 13 s with room, which the refused path's numbers say.

Not ours to measure: whether Telegram's server accepts the token. Only a sign-up answers that, and that is the
owner's action.
