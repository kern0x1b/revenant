# SFSpeechRecognizer, SFSpeechRecognitionTask, their delegates and SFSpeechErrorDomain, iOS 10 and later

The recognizer of iOS 10 and its task, with the two delegate protocols and the error domain. The release (6.1.3) has no
Speech framework, and no recognizer runs on this device: the library answers as a system on which speech recognition is
not available. Nothing here opens the microphone, captures audio, or sends audio anywhere.

Sources: the Speech headers of the macOS 27.0 SDK (`SFSpeechRecognizer.h`, `SFSpeechRecognitionTask.h`, `SFErrors.h`) for
every declaration, availability and selector. The answers are measured on the host, a Mac, as a bare command-line tool (no
bundle, no usage description). The probes that measured them were run by hand and are not committed; the cases the
committed harness compares are `tests/backports/host/speech-data/` cases 8, 9, 10, 12 and 13.

## What is measured on the host

| question | host answer |
| --- | --- |
| `+authorizationStatus`, no usage description | NotDetermined (0), no prompt |
| `+requestAuthorization:`, no usage description | returns to the caller, then the process ends (SIGABRT, signal 6) before the handler runs |
| `+supportedLocales` | 62 locales, `tlh-US` not among them |
| `-initWithLocale:` with `tlh_US` (not supported) | nil; the host writes a line to stderr naming the supported locales |
| `-init` (the device locale, en-US) | a recognizer; `isAvailable` YES, `supportsOnDeviceRecognition` YES, `queue` set, `delegate` nil, `defaultTaskHint` 0 |
| `-[SFSpeechRecognitionTask init]`, a fresh task | a task; `finishing` NO, `cancelled` NO |
| `state`, `error`, `-finish`, `-cancel` of a fresh task | the process ends (SIGSEGV, signal 11) |
| `SFSpeechErrorDomain` | exported; its value is the string `SFSpeechErrorDomain` |

The differential compares cases 8, 9, 10, 13 and 14 with the host. Case 12 (the authorization request) is named as a host crash,
not as agreement, and the state, error, finish and cancel rows are not in any case because the host ends the process on them.

## What the port answers

- `+supportedLocales`: an empty set. No locale is one this device can recognize.
- `+authorizationStatus`: NotDetermined, the host's answer for an application with no usage description (case 8), until
  the application asks; Restricted after it.
- `+requestAuthorization:`: calls the handler once, on a global queue, with Restricted, after the call returns. The host
  never calls it: it ends the process (case 12). See the decision below.
- `-init` and `-initWithLocale:`: nil. A recognizer for a locale the port does not support is not made, which is the
  host's answer for a locale it does not support (case 10).
- `SFSpeechRecognitionTask`: a fresh task is not finishing and not cancelled (case 13). No task is ever started.
- `SFSpeechRecognizerDelegate` and `SFSpeechRecognitionTaskDelegate`: declared in `RevenantSpeechProtocols.h` with their
  optional methods, as the SDK declares them.
- `SFSpeechErrorDomain`: the constant the build exports from the constants record `spec/Speech/constants.tsv`, with the
  value the host has.

## Where the port differs from the host

- **`+supportedLocales`.** The host has 62 locales; the port has none. This is the port's design: no recognizer runs on
  this device, so no locale is one it can recognize. The count is not compared (case 9 compares only `tlh-US`, which both
  sides lack).
- **`-init` with the device locale.** The host makes a recognizer for en-US; the port makes none, for the same reason as
  `supportedLocales`.
- **`+requestAuthorization:` on an application with no usage description.** The host ends the process; the port returns
  and calls the handler once with Restricted, and the status reads Restricted from then on. Restricted is not a host
  measurement: it is the coordinator's decision, below.

## Not carried in this library

- The instance surface of `SFSpeechRecognizer`: `available`, `locale`, `supportsOnDeviceRecognition`, `delegate`,
  `defaultTaskHint`, `queue`, and both `recognitionTaskWithRequest:` methods. No recognizer instance exists on this device,
  so nothing answers them. The six properties are declared `@dynamic` in `SFSpeechRecognizer.m`, so the compiler does not
  synthesize accessors that would answer the zeros of ivars; a caller that asks reaches an unrecognized selector.
- The instance surface of `SFSpeechRecognitionTask` other than `finishing` and `cancelled`: `state`, `error`, `-finish`,
  `-cancel`. The host ends the process when they are read or sent to a fresh task. `state` and `error` are `@dynamic`, for
  the same reason.
- The iOS 13 and later classes and properties of the recognizer and task. Listed in `facts/Speech/recognition-data.md`.
- `SFSpeechLanguageModel`, `SFSpeechRecognitionMetadata` and the other classes of iOS 13 and later.

## Not measured

- The queue and the once-or-never of `+requestAuthorization:` on the host: the process ends before the handler runs, so the
  handler's queue and count cannot be read.
- The error domain and code of `recognitionTaskWithRequest:` on an unavailable recognizer, the task state, and the order
  of the delegate calls. The host has no recognizer that is unavailable and reachable without authorization: a task needs
  authorization, and the host ends a bare tool that asks for it without a usage description.
- `isAvailable` and `supportsOnDeviceRecognition` for a recognizer that is not available: the host's only reachable
  recognizer is available.

## Decision of the coordinator

- `+requestAuthorization:` calls its handler once, on a global queue, with `SFSpeechRecognizerAuthorizationStatusRestricted`,
  and `+authorizationStatus` reads Restricted from then on. The band left the handler uncalled, so that the port gave no
  answer the host did not give; the coordinator overruled it on 2026-10-15. Ending the process, the host's reaction, is not
  an answer an application can act on, and a handler never called leaves an application waiting forever. The header
  documents Restricted as the status of a device that keeps the application from recognizing speech, which is what this device
  does: it has no recognizer. The header does not promise the main queue for this handler. Before the request the status
  stays NotDetermined, which is the host's measured answer (case 8).
