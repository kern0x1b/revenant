# The state of a progress, iOS 7.0 and 9.0

`-indeterminate`, `-paused`, `localizedAdditionalDescription`, `resumingHandler` and `-resume`, on the
release's own `NSProgress`.

Source: the SDK 26.2 headers; the host's own `NSProgress`, read through
`tests/backports/host/foundationbatch` (the cases are in `tests/backports/device/foundation15batch.m`
for the device run).

## What the header says and what the host answers

The header: `-isIndeterminate` returns YES when the total or the completed count is **less than
zero**, and NO when both are zero, in which case `-fractionCompleted` is 1.0. The host answers **YES**
for both zero (measured: a fresh `NSProgress` with no units answers YES, and one with 10 of 10 units
answers NO). So the port follows the host, and the rule is the one measured over seven pairs rather
than the one guessed first:

| total | completed | the host | the port |
| --- | --- | --- | --- |
| 0 | 0 | YES | YES |
| 0 | 1 | **NO** | NO |
| 10 | 5 | NO | NO |
| 10 | 10 | NO | NO |
| 100 | 1 | NO | NO |
| -1 | 0 | YES | YES |
| 10 | -1 | YES | YES |

A negative total, a negative completed count, or both counts zero. The first version of this said "a
total of zero or less", which answers YES for the second row where the host answers NO; the
differential found it. Where the header and the host disagree, the host is followed, and the divergence
is here rather than hidden.

`-pause` and `-resume` set and clear the flag; the file `NSProgress+Additions.m` has the two handlers
the header describes, and this file has the flag they set.

`resumingHandler` runs only when the progress **was** paused: the host does not call it when `-resume`
is invoked on a progress that was never paused (measured), and the port does the same. The header
says the block is invoked when `-resume` is invoked, and the host is the release the port matches.

`localizedAdditionalDescription` is null-resettable: nil puts the default back, and the default is
what `NSProgressFileTotalCountKey` and `NSProgressFileCompletedCountKey` in the user info make of
themselves. A fresh host progress has a non-nil one (measured), so the port builds the same text from
those two keys and answers nil when they are not both there.
