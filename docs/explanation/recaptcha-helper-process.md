# The reCAPTCHA SDK in a helper process: design

The design of the helper, written before its code. It replaces the plan of loading the translated SDK into
Telegram's own process ([library mode](../reference/recompiler/library-mode.md)). The helper now exists
(`recompiler/tests/recaptchahelper`) and is proved on the build host against a fixture library; the rules an app
keeps towards it are [the contract](../reference/recompiler/recaptcha-helper.md), which is the page to read for
the protocol as built. Every statement is marked **Measured** (with where),
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

**Measured in the app, on the same refused path** (`runs/m4-pass124/xlstats-1/`, drop40, 2026-11-19, two launches):
the load on demand and `fetchClient` together 1.89 and 1.62 s (the app's `fetched` time includes the load: the glue
reports `load=not tried` when the fetch is called), and 20 `execute` calls 0.36 to 0.69 s. That is `rcsdk`'s load and
fetch together (1.8 to 2.1 s) and its `execute`: the app is no slower than the separate process. Before the routing
fix (pass123, `m4pts.out`) the same two steps took 3.93 and 3.72 s and 2.88 and 3.18 s, a lock convoy between two
threads that drop39 removed ([library mode](../reference/recompiler/library-mode.md), "Two threads that send at
once").

**No run anywhere has returned a token.** Every `execute`, in `rcsdk` and in the app, was given a key the server
refuses. The key Telegram uses is not in its sources: it arrives in the text of the server's error 403
`RECAPTCHA_CHECK_<method>__<siteKey>` to a sign-in request (`submodules/MtProtoKit/Sources/MTRequestMessageService.m`,
line 1018), and a search of the sources for a 40-character key constant finds none. A sign-in request is an account
action, which the owner forbade. So whether the path to a token goes through the `WKWebView` backport, `UIDevice` or
the keychain, and whether those answer in a process without `UIApplication`, is **not known** and cannot be measured
until the owner gives a key (2 below).

**Measured as `mobile`, from inside the `.app` and started by the app** (the Telegram session, 2026-11-19, drop40,
pass124, `telegram-build/.agent-work/runs/rcsdk-pass124/`; measurements 1, 3 and 4 below): `rcsdk` signed with `ldid`
and Telegram's entitlements ran from a subfolder of the installed `.app` as `mobile`, eight runs of eight with the
twelve step lines and exit 0, from a shell and from `posix_spawn` inside Telegram's process. From the shell with
Telegram not running: load 1.12 s, `fetchClient` 0.45 s, `execute` 0.63 s, the same answer; resident 3.3 MB at start,
12.6 MB after the load, 21.5 MB at the most. So drop40 in a process of its own is where drop31 was, and where the app
is.

**Not proved yet**: the bundle identifier the SDK reads at the top of the `.app` (the runs were in a subfolder, on
purpose), and everything on the path that returns a token.

## Protocol

The app starts the helper with `posix_spawn` and file actions: the read end of one pipe becomes the helper's
descriptor 0, the write end of a second its descriptor 1, descriptor 2 is opened on a log file of the app's
(decided with the code: not `/dev/null`, the last lines of a helper that died are the only account of why), and
`POSIX_SPAWN_CLOEXEC_DEFAULT` closes everything else, so that none of Telegram's sockets and
database files reaches the helper. **Measured** (4 below): iOS 6.1.3 takes the flag, the call returns in 6.2 ms, and
the child's descriptors at the start of `main` are 0, 1 and 2 as pipes and a fourth, a pipe at 3, that the same
program has when a shell starts it: one of its own libraries opens it, and nothing of Telegram's is there (the
app's new pipes were its descriptors 44 to 47). The arguments are the path of the library and the protocol
version; the environment is the app's own with the `XL_*` switches (the measurement passed Telegram's environment;
an empty one is not tried).

The app sets `F_SETNOSIGPIPE` on its write end. **Measured** in Telegram's process: `SIGPIPE` has its default action
there, a write into a pipe whose reader has gone ends Telegram with signal 13 and leaves no crash report, and with
the flag the same write answers `EPIPE` and the app lives. So the flag is required, not prudent; the helper sets it
on its own end of the answer pipe, because ignoring the signal does not hold once the runtime's diagnostics have
given it a handler (found with the check: a helper whose library reset the signal died of it).

A message is one line of UTF-8, fields separated by a tab, ended by a newline; a tab, a newline or a percent sign
inside a field is percent-escaped; a line is at most 64 KiB (a token is a few KiB of ASCII).

| Direction | Line | Meaning |
|---|---|---|
| helper to app | `ready` version, UUID of the library, milliseconds of the load | sent once; the app sends nothing before it. The UUID is the file's `LC_UUID`: a sha256 would read 57.6 MB at every start |
| helper to app | `failed` name, text | sent once in place of `ready`; the helper then exits |
| app to helper | `token` id, site key, action, milliseconds allowed | several may be pending; the helper answers each id once |
| helper to app | `token` id, `ok`, the token | |
| helper to app | `token` id, `error`, name, domain, code, text | names: `FETCH_FAILED`, `EXECUTE_FAILED`, `TIMEOUT`, `BAD_REQUEST`; domain, code and text are the SDK's `NSError` |
| helper to app | `rejected` name, text | a line the helper could not tie to an id: `UNKNOWN_LINE`, `BAD_ID`, `DUPLICATE_ID`, `LINE_TOO_LONG` |
| app to helper | `quit` | the helper exits 0 |

**Timeouts.** Telegram waits 15 s for a token and then reports `RECAPTCHA_TIMEOUT`
(`TelegramCore/Sources/Network/Network.swift`, [the study](recaptcha-sdk-on-ios6.md), section 8). The app side owns
the deadline: it answers its caller at 13 s with a named error whatever the helper does, and a helper that has not
answered a request by then is killed. The helper has the same number in the request and answers `TIMEOUT` itself
when the SDK has not called back, so that a slow SDK is told from a dead helper.

**One helper per login, serving several tokens.** The key reaches the app only in the server's demand, so before it
nothing but the spawn and the load can happen. A helper that the app starts when the login screen appears (a
heuristic: the protocol gives no earlier sign, and the app knows neither the method nor the key until the 403) has
loaded by the time the demand comes, and the 15 s are spent on `fetchClient` and `execute` alone. A helper started
by the demand adds the spawn and the load to that; the numbers of both are in "One login" below (the app on drop40
does load, fetch and execute in 2.1 and 2.6 s). A second token for the same key costs the `execute` alone,
because the helper keeps the client per key as the app does (`recaptchaClientsBySiteKey` in `AppDelegate.swift`).
The helper exits on `quit`, when its descriptor 0 ends, or after 120 s without a request, so that it does not hold
its memory through a session.

**Measured** (4 below), the spawn: 6.2 ms for the call and 0.92 s until the child's first line, which is dyld and
the program's libraries; that second is paid before `main` and no design of the helper removes it. In that run the
load then took 4.1 s, against 0.8 to 2.3 s from a shell, because Telegram itself was 15 s into its launch and held
both cores; `fetchClient` and `execute` took 1.08 and 0.39 s. A helper started while the app is busy is that slow,
which is one more reason to start it before the demand. Not measured: every time on the path that returns a token.

## One login, from the 403 to the retried request

What Telegram does (`submodules/MtProtoKit/Sources/MTRequestMessageService.m`, line 1018, and
`submodules/TelegramCore/Sources/Network/Network.swift`, line 683): the server answers a request with 403
`RECAPTCHA_CHECK_<method>__<siteKey>`; the request is kept, the app is asked for a token with that method and key,
and when a string comes the request is sent again with it. The wait is `filter { $0 != nil } |> take(1) |>
timeout(15.0, …, alternate: .single("RECAPTCHA_TIMEOUT"))`: a `nil` from the app is dropped, so a failure answered
with `nil` costs the user the rest of the 15 s. Each request that meets the 403 asks on its own, so two may be
pending at once; they are two `token` lines with two ids, and the helper makes one fetch for the key.

A helper that has said `ready` has nothing to do before the 403: there is no step of the protocol without a key. The
one `token` line does the fetch for a key it has not seen and then the execute; a second line for the same key does
the execute alone.

The clock is the app's and starts at the 403: it answers its caller by 13 s, 2 s inside Telegram's 15. The
milliseconds it writes into the request are what is left of 12 s at the moment of writing, so that the helper's
`TIMEOUT` reaches the app a second before the app's own deadline and a slow SDK is told from a dead helper.

Every number is **measured** on the 4S with a key the server refuses, the low end from a shell with the phone idle
(drop40, measurement 1, and drop31), the high end as a child of a Telegram 15 s into its launch (measurement 4):

| Step | Cold: the helper is started by the 403 | Warm: the helper said `ready` before |
|---|---|---|
| `posix_spawn` returns | 0.006 s | |
| to the helper's first instruction (dyld) | 0.92 s, one measurement | |
| load, to `ready` | 1.1 to 4.1 s | |
| `ready` at | 2.0 to 5.0 s | before the 403 |
| the request is written | at `ready`, with 10.0 to 7.0 s allowed | at 0, with 12.0 s allowed |
| fetch for the key | 0.2 to 1.1 s | 0.2 to 1.1 s |
| execute | 0.3 to 0.8 s | 0.3 to 0.8 s |
| the answer at | 2.5 to 6.9 s; the run of measurement 4 was 6.5 s | 0.5 to 1.9 s |
| left of the 13 s | 6.1 to 10.5 s | 11.1 to 12.5 s |

So both fit, on this path. What the table cannot say is the path that returns a token: it has at least the same
steps, and any request to Google that the refused path does not make comes on top, on the phone's network. Cold has
6 s for that at its slowest, warm 11 s. That is the reason to start the helper at the login screen and not a reason
to refuse the cold start, which stays as what happens when the warm helper is not there.

When the warm helper is not there. It exits after its idle time, and a person can look at the login screen longer
than 120 s. Two rules cover it without a guess. The app starts the login helper with a longer idle time
(`--idle-ms 600000`: `rcsdk` holds 12.6 MB resident after the load, measured, and the app has no chats open yet).
And whenever the 403 finds no helper, or one that has not said `ready`, the request waits for `ready` and the cold
column applies: the app never needs to know which case it is in, it writes the request when `ready` has come and
puts what is left of 12 s into it.

What ends the wait early: `failed` in place of `ready`, the end of the answer pipe, a `token … error`. In each the
app answers its caller at once, with a string and not `nil`, for the reason in the first paragraph; which string
Telegram's own code should see for a failure is the app's decision.

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
  names are not literals in the code and were not traced.

After the runs of measurement 1 there was no preferences file of `rcsdk` for `mobile`, and none for root from the runs
on drop31: a program that ends without `synchronize` writes nothing out. The helper calls `synchronize` on its domain
before it exits, and then the file is there. **Measured** on the phone with the refused key: the domain has no key
at `ready`, one at the exit (`RCA_client_events` with the SDK's version as suffix, an array), and the file
`<state>.plist` was 5562 bytes after one request and 11345 after the second part of the run. So the refused path does
keep an event queue, and it needs the `synchronize`. The path that returns a token may keep more.

`valueForKey:` and `setValue:forKey:` are sent too (three and five places); their receivers were not traced. The
suite object is a real `NSUserDefaults`, so it answers whatever the standard one does.

What the server sees does not depend on the domain's name: the package name comes from `NSBundle` (`mainBundle`,
`bundleIdentifier`), not from the preferences. It may depend on the content being kept from one helper to the next
(the queue, the pairs), so the domain is a file that persists, not a dictionary in memory. On this route Telegram's
process never runs the SDK, so the helper's domain is the only place those keys ever are.

**The URL cache.** The same question, found by measurement 1 and not by reading: the run left
`Library/Caches/rcsdk-entitled/` with a `Cache.db` of `NSURLCache` (the answers of `www.gstatic.com` and a report
address of Google are in it). The folder is named after the bundle identifier, or after the program when there is
none, so a helper at the top of the `.app` would open Telegram's own `Cache.db` from a second process. The helper
does not: before `xl_load` it gives itself a cache of its own with `+[NSURLCache setSharedURLCache:]`, on a path
beside its preferences domain. **Measured** on the phone: a cache made with a name is an SQLite file named by that
name, with its `-shm` and `-wal` files, in `Library/Caches/<program>/`, and there is no `Cache.db` in it.

**The cookie store.** The third place of that kind, and the phone showed it: the helper's process was given a shared
cookie store with 211 cookies in it, 15 of them for Google's hosts. The Foundation backport's `NSURLSession` takes
its cookies from the configuration's store, and the default configuration's store is the shared one
(`NSURLSessionConfiguration.m`, `NSURLSession.m`), so the SDK's requests would carry those cookies and its responses
would add to them. The helper therefore answers `sharedHTTPCookieStorage` with the store of an ephemeral
configuration, in memory and its own; it is empty at each start. The store has to exist before the replacement is
installed: the backport's `NSURLSessionConfiguration` `init` asks for the shared stores, and its ephemeral constructor
then overwrites them (`NSURLSessionConfiguration.m`, `RevenantCookieStorage.m`), so a helper that made the store on
first use re-entered its own `dispatch_once` and hung on the phone. By that reading the ephemeral store is private, and
the log line compares it with the shared one on the phone. Whether the server's answer depends on cookies that
the SDK itself set on an earlier request is not known, and that is the cost of the choice: a store kept on disk would
be one more file in the helper's home.

**The caches folder of the library.** A fourth place, found on the phone and not by reading: after a run there was a
file `ovk` of 564 bytes in `Library/Caches/rcec/` of the home the helper was given, rewritten at every run, and beside
it a file of 5396 bytes named by a short prefix and a site key, older than the helper. The library writes them itself:
`rcec` is a string in it, and the Swift `URL.cachesDirectory` that it calls takes its path from the C function
`NSSearchPathForDirectoriesInDomains`, which no replacement of an Objective-C method reaches. The helper moves its whole
home before it loads anything: `CFFIXED_USER_HOME` is set to a folder of its state, and the preferences domain, the URL
cache and `rcec` all lie under it. The helper asks for the caches folder afterwards and stops with `NO_HOME` if it is not
inside, so that a Foundation that ignores the variable cannot make the library write into the app's container without
saying so. On the build host this is proved with a fixture that writes as the SDK does; on iOS 6 it is not.

The move has a price that the caches folder did not show. The home is also where a process finds the global
preferences, and the SDK reads the preferred languages and the current locale (`NSLocale`) and sends them, so a helper
whose home had no `.GlobalPreferences.plist` could report another language than the app and be judged on it. The
helper reads `AppleLanguages` and `AppleLocale` before the move and after it and stops with `NO_HOME` if they differ.
On the Mac they do not (the global domain is served by `cfprefsd`, which ignores the variable); on iOS 6 it is not
known, and it is the first thing the next phone run settles. The keychain and the
temporary folder are not under the home.

## Memory

**Measured** (3 below): the resident size of `rcsdk` on the refused path is 21.5 MB at the most on drop40 (24.4 MB
on drop31). It ran six times in the windows of that measurement, once beside a Telegram with a chat open that was
already getting memory warnings, once while the panel was being built, four times after Telegram had died, and every
run passed: no line of jetsam or memorystatus is in the syslog of any of them, and `rcsdk` was never killed. **Not
known**: its size on the path that returns a token. The library's 57.6 MB file is mapped, not read: the resident
figure is what counts.

What could not be measured is the case this route exists for, Telegram alive with the media panel open and the
helper beside it. On pass124 Telegram does not survive the panel: in three windows of three it died within seconds
of it (`mmap` failing with `ENOMEM`, then an allocation that failed, a fault or a trap). In two of them `rcsdk` had
not been started; in the third Telegram died a second after `rcsdk` started, which neither shows nor excludes that
a second process took memory from it. pass124 still carries the in-process path, but before a load it holds nothing
of the library's: the glue's `reserve=0` is the status of finding the library's file and no reservation (the
constructor of `recaptcha_native.c` reserves nothing, `xl_load` takes the range when it is called), and the map of
pass124 with a chat open and no library loaded (`runs/m4-pass124/addrmap/memprobe-C1.out`, the mark `A2`) has no
region in `0x2e000000` to `0x2ee28000`: the range lies in a free block of 50 MiB that begins at `0x2caba000`, the
largest one below `0x30000000`, which is where the heap's next arenas go when the rest is used. So a library loaded
late finds its range taken by the app, and one loaded early takes 14 MiB of the block the panel needs.

**Measured** (the same files): in the three windows where it died the app had not loaded the library. Its syslog has
no `recaptcha: xl_load` line in any of them (`rcsmem/syslog-Q1.txt`, `rcsmem2/syslog-Q2.txt`,
`rcsmem3/syslog-Q3-mid.txt`), and the map of the second (`rcsmem2/memprobe-Q2.out`) shows the library's range empty
at the start, two regions of 184 KiB in it with a chat open, and the app's own heap in it at the last mark, with
30 MiB free below `0x30000000`. So pass124 dies of the panel with nothing of the library in its address space: that
is the app's own shortage, and the helper does not cure it. What the helper removes is the library's share (14 MiB
of range and what it touches) and every failure of loading late; whether the app without the library survives the
panel is a question about the app, measured by the Telegram session, and the panel case of this measurement cannot
pass before that one does.

**Measured, the helper itself** (pass125b of Telegram's build on the iPhone 4S, iOS 6.1.3, 2026-11-19; two windows, the
helper of the drop43 sources with a memory probe inserted into it, a key the server refuses; the Telegram session's
record, `scratch-login/memprobe/memprobe-helper-HH1.out` and `-HH2.out`, one sample about every 1.35 s):

| Moment | Virtual size | Resident | Threads |
|---|---|---|---|
| the helper's constructor | 288100 K (110 regions, mostly the shared cache) | | |
| while `xl_load` runs, 0.6 s before `ready` | 398848 K in both | 11224 K and 11208 K | 8 |
| 0.7 s after `ready`, before the answer | 401580 K and 405252 K | 17552 K and 19028 K | 9 and 12 |
| 0.5 s after the answer (the peak) | 409132 K and 408088 K | 21524 K and 21476 K | 16 and 15 |
| idle, from 8.5 s on | 402868 K, then 402344 K | 21312 K, then 21296 K | 10 |

The library adds about 110 MB of virtual size to the helper (288 to 399), an `execute` adds 3 to 10 MB at its peak and
the size returns to about 402 MB after the answer and stays there; resident is 21 MB, and the malloc zones grew from
20.8 to 21.1 MB with 1.2 to 2.2 MB in use and no failures. Below `0x30000000` the helper has 760476 K free at the start,
about 650 MB after `xl_load` and about 646 MB when idle, the largest hole 360 to 395 MB: the helper is far from the limit
of its address space, which is the question the budget asks. The helper starts when the first request comes: `ready`
2.03 and 2.06 s after the spawn (`xl_load` 1577 and 1671 ms), the answer `EXECUTE_FAILED ... Invalid Site Key.` 3.80
and 3.68 s after the request. The app's virtual size in the same windows: 880872 K before the request and 882020 K after
the answer in the first, 879064 K and 881968 K in the second, resident 120584 to 120748 K and 119848 to 121676 K, so the
helper costs the app 1 to 3 MB (the pipes and the reader thread) and the library lives in another address space. Not
measured: a helper with a key the server accepts, which goes further down the SDK's path than the refusal does, and
the helper after a second request.

## Signing and install

**Measured**: a program signed with `ldid -S` and the entitlements file of Telegram's executable runs as `mobile` from
inside the installed `.app`, from a shell and as a child of the app (1 and 4 below); the plain signature was not
needed and so not tried there. The helper and the two library files are added to the `.app` by the Telegram
session's install step; the app's own executable no longer links the loader.

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
   which has the domain of its own. **Passed** (2026-11-19): the build with Telegram's entitlements, at the first
   try; Telegram's preferences file the same before and after.
2. The same with Telegram's site key (a request to Google, which the owner allows from this phone). Shows: a token,
   or the error, for a process that is not an application. **Ends the route** if the path to a token needs what only
   an application has (the web view, the vendor identifier) and neither answers here. This is the largest unknown.
   It cannot run: nobody here has a key the server accepts, and the only source is an account action (above). It
   waits for the owner's word.
3. The resident lines of run 1 (`fetched`, `executed`), and the same run while Telegram is frontmost with the panel
   open. **Ends the route** if Telegram or the helper is killed for memory there, twice in a row. The size on the
   path that returns a token stays unknown until 2. **Half done**: the sizes are measured and `rcsdk` was never
   killed, beside a Telegram with a chat open and beside one dying of its own address space; the panel case cannot
   be made while the app dies of the panel with no library in it, as pass124 does ("Memory"); it is repeated when
   an app survives the panel.
4. `posix_spawn` of `rcsdk` from Telegram's process with the two pipes and `POSIX_SPAWN_CLOEXEC_DEFAULT` (the probe
   that started `/bin/true`): it loads and answers, and its descriptors are 0, 1 and 2 only. **Ends the route** if a
   child of the app cannot load the library (a limit inherited from the app). **Passed**: the twelve lines on the
   answer pipe, end-of-file, exit 0, the parent Telegram's pid, nothing inherited ("Protocol").
5. Lifetime, with the first helper build: the app killed (by signal, and by the user) during a request, the helper
   gone within a second; the app sent to the background during a request, the answer there on return; a helper
   stopped with `SIGSTOP`, the app's deadline fires at 13 s and no process is left. Nothing here ends the route; it
   fixes the numbers.
6. Preferences, caches and keychain, with the first helper build: Telegram's preferences file, its `Cache.db` and
   its cookie file are the same before and after a request (the helper's are its own), and the keychain calls of the
   SDK answer for a program signed with `ldid`. Nothing here ends the route: a keychain that refuses is answered by
   the SDK's own error path, to be read then.
7. Times, with the first helper build: five requests from a helper started by the request and five from one that had
   loaded before it. The route stands if both are under 13 s with room, which the refused path's numbers say.

Not ours to measure: whether Telegram's server accepts the token. Only a sign-up answers that, and that is the
owner's action.
