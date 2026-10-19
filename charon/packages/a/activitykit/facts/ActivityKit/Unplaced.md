# ActivityKit's 10 unplaced rows, and why none of them is a missing declaration

162 rows, **152 placed**, 10 missing, 0 wrong-kind, built for `armv7-apple-ios6.1.3` from the
sources with the recipe's own flags. `.agent-work/host/classify.py` against the digester's own dump
(`activitykit-dump.json`) sorts the ten three ways:

| rows | which | what they are |
| --- | --- | --- |
| 7 | digester naming | `ActivityAuthorizationError.==(a:b:)`, `ActivityState.==(a:b:)`, `ActivityUIDismissalPolicy.==(a:b:)`, `PushType.==(a:b:)` and three more — the operator's argument labels, which the digester drops |
| 3 | digester naming, **and the digester prints them** | `AlertConfiguration.init(title:body:sound:)`, `AlertConfiguration.title`, `AlertConfiguration.body` |
| 3 rows counted once | member not printed | `ActivityStyle.==(a:b:)`, `AlertConfiguration.==(a:b:)`, `AlertConfiguration.AlertSound.==(a:b:)` — the digester prints each type's cases and `hashValue` and no equality member, the same behaviour measured on `IntentParameter.Acceleration` and refuted as to its cause three ways in the handoff |

**The second row is a matcher finding, not a port gap, and it is new.** The dump's printed names for
`AlertConfiguration` are

```
['body', 'default', 'init(title:body:sound:)', 'sound', 'title']
```

which are the ledger's three rows *exactly*, and the rows are still in
`the missing-rows list, **regenerated** from the corpus ledger and a digester dump, not kept`. So a member that the dump prints under the ledger's
own name can still read `missing`, and this is the smallest reproducer in the four modules: three
rows, one type, no spelling difference. The likely cause is that the two are keyed on something the
dump does not carry for a type whose members are typed with another module's (`LocalizedStringResource`
from `charon@appintents`), which is worth the ledger band checking before anything else in the
naming list.

**So there is no ActivityKit declaration to write.** What the port's own source has to answer for,
it has: the activity's authorisation, its state and dismissal, its push type, the alert
configuration, and the availability facts in `facts/ActivityKit/Availability.md`. The rows move when
the matcher moves, and the three enum-equality rows move when the digester prints a member it has
been asked to print.
