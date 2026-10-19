# The `sec_identity_t` family, and what the host case does and does not measure

Six rows in two objects, and the split is `release-split`'s, not mine: run on the pair as one object it
reported `MIXED-RELEASES 12.0,16.0`, which is the reason for two files. `sec_identity_access_certificates`
is in the 16.0 rung and the other five in the 12.0 one, and one release per object is what the tool then
agrees on - `release-split: clean, every object file's symbols first-appear in one release (4 files, 17
symbols, 50 releases checked)`.

**What "16.0" is worth, said plainly: it is a rung, not a measured first release.** The same run prints
`note: no release is held between 12.0 and 16.0, so 16.0 here means after 12.0 and by 16.0, not a
measured first release`. So the tool establishes that the symbol is in the 16.0 rung and not in the
12.0 one, and it cannot name the release that first exported it, because there is no release between
them. The 16.0 the row and the file name is the SDK's own annotation for the function
(`SecProtocolTypes.h`), and the two agree; the ladder is what backs the SPLIT, not the arrival.

**None of the six is exported by 6.1.3.** Read from that release's own cache — the Security image at
`0x32e79000`, UUID `FBC24F15BD9E37539CDD6E3576BDE938`, 660 exports — `_sec_identity_create`,
`_sec_identity_create_with_certificates`, `_sec_identity_copy_ref`,
`_sec_identity_copy_certificates_ref`, `_sec_identity_access_certificates` and
`_sec_protocol_options_set_local_identity` are all absent. The port supplies them. What the release does
have is `SecIdentityRef`, which is old, and that is the type they wrap.

## The stand-in, and the limit it puts on every row

**A real `SecIdentityRef` cannot be made on this Mac.** Every factory in `SecIdentity.h` is `__IPHONE_NA`
on iOS — `SecIdentityCreateWithCertificate` at `:65`, the preference, preferred and system-identity calls
at `:126`, `:150`, `:174` — and `SecIdentityCreate`, the one taking a key or a certificate directly, **is
not declared at all**.

So the host case passes an **ephemeral in-memory `CFDataRef`** where a `SecIdentityRef` would go, and
every row says so. **No keychain is touched** by anything here: no `SecItemAdd`, no `SecItemDelete`, no
query, no identity import, on this Mac or anywhere.

**A real identity is a GUEST MEASUREMENT and is owed.** What the case measures is the wrapper's
**ownership** — the part that can be wrong — and not the interaction with a real identity.

## What is measured, and the three mutations that prove it

Eleven assertions, and each mutation names the row it breaks:

| assertion | what it holds down | mutant |
| --- | --- | --- |
| `copy-ref-same` | copy_ref answers the ref it was given, by pointer | — |
| `certificates-copied`, `copy-survives-source-change` | the array is **copied**, not aliased | aliasing it → `copy-survives-source-change: got 0` |
| `access-true`, `handler-runs-per-certificate` | the handler runs once per certificate | never calling it → `handler-runs-per-certificate: got 0` |
| `access-empty-true`, `handler-runs-on-empty` | true, having run the handler zero times | — |
| `copy_ref-of-nil` | a nil identity is refused, as `_Nullable` says | — |
| `local-identity-holds` | the options object holds and reads back the identity | — |
| the retain balance | — | dropping the `+1` → `access-empty-true: got 0` |

The two objects the case links: `SecObjectWrappersIdentity12_0.m` holds `CharonSecIdentity`, and
`SecObjectWrappersIdentity16_0.m` holds the accessor and **declares** that class without implementing it —
a second `@implementation` would be a duplicate definition, and there is none.

## Two things the compiler taught, both about types

`sec_identity_t` is emitted as `NSObject<OS_sec_identity> * __attribute__((objc_independent_class))`, so
it is an **Objective-C pointer**: it takes a `__strong` ivar directly and passing it to a method of the
same type needs no cast. A `SecIdentityRef` is a `CFTypeRef` and cannot be `__strong` — ARC warns that it
will not manage one. And a case must **declare** the port classes it names, because they are implemented
in `.m` files it does not include.
