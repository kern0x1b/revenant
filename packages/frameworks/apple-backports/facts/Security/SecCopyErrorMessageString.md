# SecCopyErrorMessageString

Introduced in iOS 11.3. `CFStringRef SecCopyErrorMessageString(OSStatus status, void *reserved)` answers a
sentence for a status, to be released by the caller. It lives in `libSecurityBackports.dylib`, built with the
`security` config.

Source: Security of the arm64 shared cache of iOS 12.0, `_SecCopyErrorMessageString` at `0x181bb6fa4`; the
English text of the tables from the Security bundle of iOS 16.0 (the two tables agree on every status they
share); the host's own function; an iPad 2 running 6.1.3.

## Behaviour

| case | answer |
|---|---|
| a status the table has | its sentence, a new string. |
| any other status | the text `OSStatus ` and the number in decimal, negative numbers with their sign. |
| `reserved` | not read. |

The function of iOS 12 asks the bundle of Security for the key of the status (`%d`) in the table
`SecErrorMessages`, then in `SecDebugErrorMessages`, and formats the fallback when neither has it; iOS 6 has
no such tables, so the sentences are carried in the library, 534 of them, from the status -67903 to 0.

## Differences

- English only. iOS 12 answers in the language of the device.
- The table is the one of iOS 16.0, the only Security bundle with these tables that is at hand. A status
  that iOS 16 added after iOS 12 answers its sentence here where iOS 12 answers `OSStatus` and the number.
- The host of the differential (a much newer macOS) has thirty statuses more than the table, all of them from
  the Authorization, remote signing and URL groups that iOS does not carry, and words one sentence
  differently (`-34018`, "isn't" against "is not"). The differential asserts both literally.
