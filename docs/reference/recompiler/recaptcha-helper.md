# The reCAPTCHA helper: the app side's contract

What an app must do to start the helper process of the translated reCAPTCHA SDK, talk to it and survive it. The
reasons are in [the design](../../explanation/recaptcha-helper-process.md); this page is only the rules. The helper
is `recompiler/tests/recaptchahelper/helper.m`, and the check of that folder
([corpus](corpus.md), `recaptchahelper`) holds every rule here that names the helper. Its `driver.c` is an app side
in C that keeps the rules below (`start`, `put`, `get`), to read beside this page.

Proved on the build host against a fixture library. It also ran on the phone (iPhone 4S, iOS 6.1.3) with the real
library and a key the server refuses, in two parts on 2026-11-19: started from a shell, and started by Telegram's
spawn probe. In both the helper answered `ready`, named the refused key's error as `EXECUTE_FAILED`, exited 0 when the
request pipe closed, and survived being killed without the parent noticing. A third time, on 2026-11-19 (pass125b of
Telegram's build, two windows), the helper of this page was spawned by the app: `F_SETNOSIGPIPE` on the answer pipe was
accepted and none of `failed STDOUT`, `NOSIGPIPE`, `NO_HOME` or `NO_READER` appeared; `ready` came 1.734 and 1.715 s
after the spawn (the library's load 1445 and 1418 ms), and the answer to an `execute` with a key the server refuses,
`EXECUTE_FAILED com.google.recaptcha 2: Invalid Site Key.`, came 3.33 and 3.03 s after the spawn, so the helper, the
library, Google and the SDK's error reached the app whole. (Those times and the lines are the Telegram session's
record of its own run.) A fourth time, on 2026-11-23 (pass137 of Telegram's build), a shell script on the phone ran
the helper with the two pipes of the protocol and the log on descriptor 2, with a clock of whole seconds only (the
phone's shell has no finer one, so every time of that run is good to one second). A second `execute` on the same
process, twelve seconds after the first, got the same `EXECUTE_FAILED` in under a second, and the process id was the
same before the first request, before the second and before `quit`, which ended with exit 0 in the same second. With
`--idle-ms 10000` and no request the helper left with status 0 ten seconds after `ready` and wrote `no request for
the idle time` in its log. The files it keeps under its home are listed in [State](#state). No run has returned a
token. The last section says what is still open.

## Starting it

`posix_spawn` with:

- arguments: the helper's path, the path of `RecaptchaEnterprise.dylib` (its `-classes` file beside it), the protocol
  version `1`; then, optional, `--state NAME` and `--idle-ms N`;
- file actions: the read end of a request pipe to descriptor 0, the write end of an answer pipe to descriptor 1, and
  descriptor 2 opened on a log file for appending (`posix_spawn_file_actions_addopen`, `O_WRONLY | O_CREAT |
  O_APPEND`);
- the flag `POSIX_SPAWN_CLOEXEC_DEFAULT`, so that nothing else of the app is open in the helper;
- the app's own environment. The helper needs the System and Foundation backports in its process as the app has
  them, and it gets them by being linked against them as the app's executable is: the build that compiles `helper.m`
  and `protocol.h` links the Backports libraries into it, and the app's rules name no `DYLD_INSERT_LIBRARIES`. (The
  measured runs of the kit on the phone inserted them, because the kit's helper was built outside that build.)

A helper that lies at the root of the `.app`, as the main executable does, must be linked with `-Wl,-rpath,
@executable_path/Frameworks`, the `LC_RPATH` the main executable has: the phone's dyld resolves `@rpath` only through
the `LC_RPATH` of the image that loads the library, not through the app's. Measured in pass125b: the first window's
helper, linked with `-rpath @executable_path`, died after 0.39 s with signal 5 and `dyld: Library not loaded:
@rpath/libswiftFoundation.dylib, Referenced from …/RecaptchaHelper`. The check of `recompiler/tests/recaptchahelper`
links the helper for the build host and does not see this.

After the call the app closes the two ends it gave away and sets `F_SETNOSIGPIPE` on its write end of the request
pipe. Without it a write to a helper that has gone ends the app with `SIGPIPE` and no crash report (measured in
Telegram's process).

`--state` names the helper's state: its home folder, with the preferences domain and the URL cache that lie in it
(the table at the end). Without it the name is the bundle identifier with `.recaptcha` added; a helper that has
neither says `failed NO_IDENTITY`, because it would have no place of its own. The app passes it only when the helper
does not lie at the top of the `.app`.

## Lines

One line is UTF-8, fields separated by a tab, ended by a newline, 65536 bytes at most with the newline. Inside a
field a percent sign and every byte below 0x20 or equal to 0x7f is written as `%` and two hexadecimal digits; a
reader takes any `%XX`, upper or lower case, and a `%` not followed by two such digits makes the field wrong.

| Direction | Line | When |
|---|---|---|
| helper to app | `ready` `1` UUID milliseconds | once, first; the UUID is the `LC_UUID` of the library file, the milliseconds are the load |
| helper to app | `failed` NAME text | once, in place of `ready`; the helper then exits with 3 |
| app to helper | `token` id key action milliseconds | any number may be pending |
| helper to app | `token` id `ok` token | |
| helper to app | `token` id `error` NAME domain code text | |
| helper to app | `rejected` NAME text | a line the helper could not tie to an id it may answer |
| app to helper | `quit` | the helper exits with 0, answering nothing more |

- An id is 1 to 64 characters of `A-Z a-z 0-9 . _ -`, chosen by the app, and may be used again once it is answered.
- The action `login` or `signup` is the SDK's action of that name; any other text is its custom action.
- The milliseconds are 1 to 120000: the time the helper gives the SDK before it answers `TIMEOUT` itself.
- Every `token` request with a valid id that is not pending gets exactly one `token` answer. Answers come in the
  order the SDK gives them, not the order of the requests.

| `failed` | Meaning |
|---|---|
| `USAGE`, `VERSION` | the arguments are wrong, or the helper speaks another version |
| `NO_IDENTITY` | no bundle identifier and no `--state` |
| `LOAD_FAILED` | `xl_load` refused; the text is its status and message |
| `NO_DEFAULTS` | `NSUserDefaults` has no `initWithSuiteName:` (the Foundation backport is not loaded) |
| `NO_COOKIE_STORE` | there is no `NSURLSessionConfiguration`, so no cookie store of the helper's own can be made (the Foundation backport is not loaded) |
| `STDOUT` | descriptor 1 cannot be pointed at the log (`dup2`), or the answer pipe's own descriptor cannot be marked close-on-exec; the text says the error. Nothing the library prints may reach the answer pipe, so the helper stops before it loads the library |
| `NOSIGPIPE` | `SIGPIPE` cannot be ignored, or `F_SETNOSIGPIPE` is refused on the answer pipe; the text says the error. iOS 6.1.3 accepted the call on the answer pipe (iPhone 4S, 2026-11-19), and the Mac accepts it on pipes, sockets, files and `/dev/null`; the refusal has not been seen anywhere |
| `NO_READER` | the thread that reads the request pipe cannot be made; the text says the error. The helper makes it before it writes `ready` (the thread waits until `ready` is written), so an app never sees `ready` from a helper that cannot hear it |
| `NO_HOME` | the helper's home folder cannot be made; or `CFFIXED_USER_HOME` cannot be set; or after it was set the caches folder is not inside it; or the languages and locale the process reads from the global preferences are not what they were before the move. The text says the paths or the two values. The helper stops rather than let the library write into the app's container, or send another language than the app's |
| `NO_CLASSES` | the library has not the two classes the helper calls |

| `token … error` | Meaning |
|---|---|
| `FETCH_FAILED`, `EXECUTE_FAILED` | the SDK's own error: domain, code and text are its `NSError`. Domain `rchelper` with code 0 is the helper speaking (no answer of either kind, an answer that does not fit a line) |
| `TIMEOUT` | the SDK had not answered when the request's milliseconds ended; an answer that comes later is dropped |
| `BAD_REQUEST` | the id was valid and the rest was not: not five fields, an empty or wrongly escaped key or action, bytes that are not UTF-8, a NUL, a time that is not a number in range |

| `rejected` | Meaning |
|---|---|
| `UNKNOWN_LINE` | the first field is neither `token` nor `quit` alone |
| `BAD_ID` | a `token` line without a valid id |
| `DUPLICATE_ID` | the id is pending; the first request stays pending and is answered |
| `LINE_TOO_LONG` | more than 65536 bytes before a newline; the text says how many, and the helper reads on after it |

A `rejected` line is a fault of the app side, to log; the helper serves on. Its text is ASCII: every other byte of
what it quotes is escaped.

## What the app side must do

1. Count a line only when its newline has come. A helper that dies while it writes leaves a piece without one, and
   that piece is not an answer.
2. Own the deadline. Telegram gives a token 15 s; the app answers its caller at 13 s whatever the helper does, and
   puts a smaller number in the request so that the helper's `TIMEOUT` arrives first when the SDK is slow. A helper
   that has answered nothing by the app's own deadline is killed. The steps of one login with their measured times,
   cold and with a helper started at the login screen, are in
   [the design](../../explanation/recaptcha-helper-process.md), "One login, from the 403 to the retried request"; it
   also says why a failure must reach Telegram's code as a string and not as `nil`.
3. Read the answer pipe on its own, never between two writes: the helper reads requests while it is writing answers,
   so the app's writes do not wait for its reads, but an app that stops reading stops the helper's answers.
4. When the answer pipe ends, `waitpid` and decide by the status:

   | Seen | Means | The app |
   |---|---|---|
   | exit 0, nothing pending | `quit`, or the idle time passed | starts a helper at the next request |
   | exit 0, a request pending | the request crossed the idle exit | starts a helper and sends the request again; not a death |
   | exit 3 after `failed` | the helper could not start | answers `HELPER_UNAVAILABLE`; does not retry in this login |
   | a signal, or another exit | the helper died | answers every pending id with `HELPER_DIED`, starts one more helper for the next request; a second death in a row is not retried in this login |

5. Kill only with `SIGKILL` and always `waitpid` after, so that no zombie stays.
6. Close its write end of the request pipe when it no longer wants the helper, or send `quit`. The helper exits when
   descriptor 0 ends, whatever is pending.

## When the helper exits by itself

- `quit`, the end of descriptor 0, or a write to an answer pipe that the app has closed: exit 0.
- No request pending and no line from the app for the idle time (120 s, or `--idle-ms`): exit 0.
- No line in either direction for the idle time and 150 s more: `SIGALRM` ends it. That bounds a helper whose main
  thread is stuck.

Before each of the first two it writes its preferences out (`synchronize`).

The helper sets `F_SETNOSIGPIPE` on its own end of the answer pipe as the app does on its end of the request pipe.
Ignoring the signal is not enough there: with the runtime's diagnostics on, `SIGPIPE` has a handler of the runtime
that ends in the default action. When the helper cannot ignore the signal or cannot set the flag, it says
`failed NOSIGPIPE` and does not start; there is no fallback to the signal alone, because it is not known to be enough.

Any line from the app keeps the helper alive for the idle time, a line that is too long (`LINE_TOO_LONG`) included,
and so does the answer to a request.

## Descriptor 1, descriptor 2 and a crash

The helper moves the answer pipe to a descriptor of its own before it loads the library, and points descriptor 1 at
descriptor 2. So only protocol lines reach the app, and everything the library, the runtime or Foundation prints
goes to the log file of descriptor 2: `printf` and `write(1, …)` of the SDK, the runtime's `xlate:` lines, `NSLog`,
and the helper's own lines, which begin with `rchelper:`. At `ready` and at each exit of its own (`quit`, the end of
a pipe, the idle time) the helper writes one line there with the name of its state, the number of keys in its
preferences, the size of its URL cache, the number of cookies in its own store and in the shared store its process was
given (counts; no name or value), and the caches folder the library sees (`caches=`), which on a working run is inside
the helper's home. A helper that stops with `failed` writes `rchelper: failed NAME: text` instead and no such line:
it stops before it has a state to count, and the same two things are on the answer pipe.

The log file is the app's: opened by the spawn so that `dyld`'s message about a missing library lands in it too,
appended to, and trimmed by the app before a spawn when it has grown (256 KiB is plenty: a run writes a few lines).
Not `/dev/null`: the last lines of a helper that died are the only account of why.

A fatal signal in the helper has its default action. The app sees the end of the answer pipe and the signal in
`waitpid`; the system writes its crash report for the helper as for any process. With `XL_CRASH=1` in the helper's
environment the runtime's handler first writes its record (the signal, the guest frames, the budget) to descriptor
2, so into the same log file ([library mode](library-mode.md), the diagnostics switches). The app does not set it in
a release.

## State

All of it lies in one folder, the helper's home, so that removing the folder removes everything the helper and the
library left. The first thing `main` does with the state is set `CFFIXED_USER_HOME` to that folder: on the phone
`<app home>/Library/Caches/<state>`, on the build host `<state>/home`. The library finds its caches folder with
`NSSearchPathForDirectoriesInDomains` (its `URL.cachesDirectory` calls it), a C function that no replacement of a
class reaches, and that function reads the variable. The helper then asks for the caches folder and stops with
`NO_HOME` when it is not inside the home.

| What | Where | Why not the app's |
|---|---|---|
| caches of the library | `Library/Caches/rcec/` of the helper's home: a file `ovk` of 564 bytes rewritten at every request, and a file for each site key the library has fetched a configuration for | on 2026-11-19 these were found in the `Library/Caches/rcec/` of the home the helper was given after a run of the helper, outside its state; the file for a site key was from 17 November, older than any run of the helper |
| preferences | the domain named by the state, in `Library/Preferences/<state>.plist` of the home | `standardUserDefaults` in the helper is replaced before the load, so the SDK's event queue and its pairs never enter the app's domain |
| URL cache | a cache of the helper's own, named by the state, in `Library/Caches/<program>/<state>` of the home, set as the shared one before the load | the default one would be the app's `Cache.db`, opened from a second process |
| cookies | a store of the helper's own, in memory, made before the replacement of `sharedHTTPCookieStorage` is installed and returned by it from then on | the shared store the process was given held 211 cookies, 15 of them for Google's hosts: the SDK's requests would carry them and its responses would add to them |

The move changes everything the process resolves from its home, not only the caches: `NSHomeDirectory`, the
Documents, Library and Application Support folders, the preferences file of every domain, `Library/Cookies`. What the
library or the runtime write there lands in the helper's home. What the SDK reads that lives only in the real home is
the global preferences (`.GlobalPreferences.plist`): `AppleLanguages` and `AppleLocale`, which reach it through
`NSLocale` and which it sends. The helper reads both keys before the move and after it and stops with `NO_HOME` when
they differ, and on the phone its log line carries them (`regional=`). On the build host the move changes neither
(measured: the global domain is served by `cfprefsd`, which ignores the variable), so there the guard only ever
passes. The keychain is not under the home on iOS 6: `securityd` keeps it in `/var/Keychains` and a process reaches it
by access group (from how iOS is built, not measured here). The temporary folder is not under it either (`TMPDIR`).

The replacements of `standardUserDefaults`, of the URL cache and of the shared cookie store stay. Where a process
reads and writes its own files under the home, the move alone would already keep the standard domain's file, the
`Cache.db` and the cookie file out of the app's container. They stay because the build host, where the check runs,
has daemons (`cfprefsd` is measured) that ignore the variable, so the check can prove the replacements and not the
move for those three; and because iOS 6 honouring the variable is untested, where a replacement that turns out
redundant costs nothing and a missing one writes into the app's own data.

The order matters: the store is the one of an ephemeral `NSURLSessionConfiguration`, and the Foundation backport's
configuration asks `+sharedHTTPCookieStorage` while it is made. A helper that made the store on first use, inside its
own replacement, waited forever in `dispatch_once` on the phone (kit 2, 2026-11-19: no `ready`, `SIGALRM` after 270 s).
The log line says `own store: separate from the shared store` or `the shared store`, compared on the phone only.

The cookie store is not kept between helpers: each helper starts with none. What the server sees of a repeated login
is therefore what the SDK itself keeps in its preferences.

On the phone with the home moved, measured in pass137 (`<HOME>` is `/var/mobile`, the state is
`ph.telegra.Telegraph.recaptcha`): the helper's home `<HOME>/Library/Caches/ph.telegra.Telegraph.recaptcha/` holds
`Library/Preferences/ph.telegra.Telegraph.recaptcha.plist` (5694 bytes, mode 0600), the URL cache as an SQLite file
`Library/Caches/ph.telegra.Telegraph/ph.telegra.Telegraph.recaptcha` (4096 bytes) with its `-shm` (32768) and `-wal`
(168952) files, and `Library/Caches/rcec/ovk` (564 bytes). Outside the home nothing appeared: no
`<HOME>/Library/Caches/rcec`, no file with `recaptcha` in its name in `<HOME>/Library/Preferences`, and the app's own
preferences file did not change (1061 bytes, same time). The state survived a restart of the helper: its second start
counted one key in its preferences, the first none. Before the home was moved the same files were found in
`Library/Preferences` (5562 bytes after one request with the refused key, 11345 bytes after the second part) and in
`Library/Caches/<program>/`, with no `Cache.db` among them.

## Not yet measured

- The helper with the real library on the phone under Telegram's own build ran twice (pass125b and pass137, above).
  Not yet run there: a key the server accepts. The times of pass137 are good to one second only; the second request
  and the idle exit have no milliseconds, which a driver in C on the phone would give. The helper's own virtual size on
  the phone was measured with a refused key (about 402 MB idle, 409 MB at the peak, 21 MB resident; the table in
  [the design](../../explanation/recaptcha-helper-process.md), section Memory), not with a key the server accepts.
- The pause after a `failed` is the app's, not the helper's: `UNAVAILABLE_SECONDS` of 120 in Telegram's
  `recaptcha_helper.c`, after which a helper that stopped with `failed`, or died twice in a row, makes every request
  answer `HELPER_UNAVAILABLE` at once with no new spawn. Telegram's `tools/recaptcha_helper_test` checks it on the build
  host; it has not run on the phone, and a probe inside the app that starts a helper made to fail is not planned, since
  the rule is plain time arithmetic in C.
- The guard of the home move for languages and locale has no control on the build host, which never changes them; on
  the phone it passed in pass125b (no `NO_HOME`, `caches=` inside the helper's home).
- The crash report of a child of Telegram, and the runtime's record under `XL_CRASH` in the helper.
- Everything on the path that returns a token: no key that the server accepts has been used anywhere.
