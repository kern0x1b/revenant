# The reCAPTCHA helper: the app side's contract

What an app must do to start the helper process of the translated reCAPTCHA SDK, talk to it and survive it. The
reasons are in [the design](../../explanation/recaptcha-helper-process.md); this page is only the rules. The helper
is `recompiler/tests/recaptchahelper/helper.m`, and the check of that folder
([corpus](corpus.md), `recaptchahelper`) holds every rule here that names the helper. Its `driver.c` is an app side
in C that keeps the rules below (`start`, `put`, `get`), to read beside this page.

Proved on the build host against a fixture library. Not yet run on the phone with the real library; the last section
says what that leaves open.

## Starting it

`posix_spawn` with:

- arguments: the helper's path, the path of `RecaptchaEnterprise.dylib` (its `-classes` file beside it), the protocol
  version `1`; then, optional, `--state NAME` and `--idle-ms N`;
- file actions: the read end of a request pipe to descriptor 0, the write end of an answer pipe to descriptor 1, and
  descriptor 2 opened on a log file for appending (`posix_spawn_file_actions_addopen`, `O_WRONLY | O_CREAT |
  O_APPEND`);
- the flag `POSIX_SPAWN_CLOEXEC_DEFAULT`, so that nothing else of the app is open in the helper;
- the app's own environment. The helper needs the System and Foundation backports in its process as the app has
  them: either it is linked against them as the app's executable is, or the environment names them in
  `DYLD_INSERT_LIBRARIES`, which is what every measured run of `rcsdk` did. Which of the two the shipped helper uses
  is the build's decision and is open.

After the call the app closes the two ends it gave away and sets `F_SETNOSIGPIPE` on its write end of the request
pipe. Without it a write to a helper that has gone ends the app with `SIGPIPE` and no crash report (measured in
Telegram's process).

`--state` names the helper's preferences domain and its URL cache. Without it the name is the bundle identifier with
`.recaptcha` added; a helper that has neither says `failed NO_IDENTITY`, because it would have no place of its own.
The app passes it only when the helper does not lie at the top of the `.app`.

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
   cold and with a helper started at the login screen, are in [the design](../../explanation/recaptcha-helper-process.md),
   "One login, from the 403 to the retried request"; it also says why a failure must reach Telegram's code as a
   string and not as `nil`.
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
that ends in the default action.

## Descriptor 1, descriptor 2 and a crash

The helper moves the answer pipe to a descriptor of its own before it loads the library, and points descriptor 1 at
descriptor 2. So only protocol lines reach the app, and everything the library, the runtime or Foundation prints
goes to the log file of descriptor 2: `printf` and `write(1, …)` of the SDK, the runtime's `xlate:` lines, `NSLog`,
and the helper's own lines, which begin with `rchelper:`. At `ready` and at each exit of its own the helper writes
one line there with the name of its state, the number of keys in its preferences, the size of its URL cache and the
number of cookies its process sees (how many, and how many for Google's hosts; no name or value).

The log file is the app's: opened by the spawn so that `dyld`'s message about a missing library lands in it too,
appended to, and trimmed by the app before a spawn when it has grown (256 KiB is plenty: a run writes a few lines).
Not `/dev/null`: the last lines of a helper that died are the only account of why.

A fatal signal in the helper has its default action. The app sees the end of the answer pipe and the signal in
`waitpid`; the system writes its crash report for the helper as for any process. With `XL_CRASH=1` in the helper's
environment the runtime's handler first writes its record (the signal, the guest frames, the budget) to descriptor
2, so into the same log file ([library mode](library-mode.md), the diagnostics switches). The app does not set it in
a release.

## State

| What | Where | Why not the app's |
|---|---|---|
| preferences | the domain named by the state: `<bundle identifier>.recaptcha` | `standardUserDefaults` in the helper is replaced before the load, so the SDK's event queue and its pairs never enter the app's domain |
| URL cache | a cache of the helper's own, named by the state, set as the shared one before the load | the default one would be the app's `Cache.db`, opened from a second process |
| cookies | not redirected | nothing was seen of them; the helper's log line counts them so that a run shows it |

## Not yet measured

- The helper with the real library on the phone, alone and under Telegram.
- Where iOS 6 puts a cache made with a name, and whether the Foundation backport is in the process before the
  library asks for the preferences (the helper stops with a named line if it is not).
- The crash report of a child of Telegram, and the runtime's record under `XL_CRASH` in the helper.
- Everything on the path that returns a token: no key that the server accepts has been used anywhere.
