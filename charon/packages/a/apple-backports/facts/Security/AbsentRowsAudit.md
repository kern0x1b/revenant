# Every `absent` row in the files this series touches, and whether `absent` is the right word

The policy: **`absent` is only for what the release truly cannot carry.** Unfinished work is **owed**,
recorded in the decision table and in a report, and it must not sit in the registry as an `absent` row —
because a reader scanning the registry for unreachable API finds it there and cannot tell it from a row
that describes a real absence.

**This series did not add any of the rows below.** Every one of them predates it: the series only ever
*removed* rows from `absent_Security.json` and `ios11.json`, and *added* rows to `ios13.json`. So per the
rule they are **left in place and listed as crutches with a fix path**, not deleted.

**Update, and the table below is a record of the past, not the present state.** The fix path the nine
wrapper rows were given here has been taken: all nine are `implemented` now, in `ios12.json` — and
`sec_identity_access_certificates` in `ios16.json`, in its own object because `release-split` puts it in a
different rung. The `file` column below is where each row sat when this audit was written, which is why it
says `ios11.json` and `absent_Security.json` for rows that have since moved; what each row is now is in
the registry, and the identity half is measured in
[SecObjectWrappersIdentity.md](SecObjectWrappersIdentity.md). Nothing below is edited to match: this file
is the record of the decision and of the reasoning that produced it, and the one sentence that would now
read as a claim about the tree — the fix path's "then flip the nine to `implemented`" — is what happened.

## The nine wrapper rows, and the "Network.framework" reason

| api | file | why `absent` is the wrong word |
| --- | --- | --- |
| `sec_identity_access_certificates()` | `absent_Security.json:10` | carryable: the port supplies the class |
| `sec_certificate_create()` | `ios11.json:26` | carryable: the port supplies the class |
| `sec_certificate_copy_ref()` | `ios11.json:25` | carryable: the port supplies the class |
| `sec_identity_create()` | `ios11.json:29` | carryable: the port supplies the class |
| `sec_identity_create_with_certificates()` | `ios11.json:30` | carryable: the port supplies the class |
| `sec_identity_copy_ref()` | `ios11.json:28` | carryable: the port supplies the class |
| `sec_identity_copy_certificates_ref()` | `ios11.json:27` | carryable: the port supplies the class |
| `sec_trust_create()` | `ios11.json:32` | carryable: the port supplies the class |
| `sec_trust_copy_ref()` | `ios11.json:31` | carryable: the port supplies the class |

**Is the reason a real fact?** *Directionally yes, and one line short of proven.* Eight of the nine carry
the reason *"the security types Network.framework hands its TLS callbacks, and this release has no
Network.framework"*, and that is the right shape: `SecProtocolTypes.h` declares the three types with
`SEC_OBJECT_DECL` and every function on them `API_AVAILABLE(ios(13.0))`, and they exist to hand
`SecTrustRef`/`SecIdentityRef`/`SecCertificateRef` to a TLS callback. **But the greps I ran for
Network.framework's own availability line returned nothing**, so the one line that reason rests on — that
Network.framework post-dates 6.1.3 — is **not independently verified here**, and this file says so rather
than repeating the claim as a fact.

**Where the carrier is.** None. That is the finding: the release carries no such call, and the port does
not either. The carrier is *owed*, and the design is settled — the port's own class implementing
`OS_sec_trust` / `OS_sec_identity` / `OS_sec_certificate`, holding the `CFTypeRef` in its own ivar, as
`clang -E` shows the type is `NSObject<OS_sec_*> *`.

**Fix path:** write them with a **real conformance compile** — `-Werror=protocol`, the `OS_object` shape
checked by `clang -E`, and a negative control — then flip the nine to `implemented`. The ninth row
(`sec_identity_access_certificates`) carries the generic *"arrived in iOS 13, and nothing in iOS 6 has
what it names"* reason instead, which is the same boilerplate as every arrival row and says nothing about
whether the release could carry it. **It could: the design above is the port's own.**

## The other `absent` rows in `absent_Security.json`, all predating this series

`SecPolicyCopyProperties`, `SecPolicyCreateWithProperties`, `SecTrustCopyCustomAnchorCertificates`,
`SecTrustCopyPolicies`, `SecTrustCopyResult`, `SecTrustEvaluateAsync`, `SecTrustSetOCSPResponse`,
`SecTrustEvaluateAsyncWithError`, `SecTrustCopyCertificateChain`, `SecAccessControlGetTypeID`,
`kSecUseDataProtectionKeychain`, `sec_identity_access_certificates` — every one carries the same generic
*"the X arrived in iOS N, and nothing in iOS 6 has what it names"*. That is an **arrival** statement, not
a hardware-absence statement, so `absent` overstates it for any of them the port could carry. None is
added by this series; all are **crutches with a fix path** (the decision table already decides most of
them `inert` with an effect stated, and the registry row should follow the decision).

Two rows in `ios11.json` state a *release* fact rather than an arrival one — `SecTrustSetSignedCertificateTimestamps`
("the release evaluates no certificate transparency") and the two `kSecAttrPersistentReference` spellings
("the keychain of iOS 6 was not read for this attribute"). Those are honest reasons and the spelling pair
is deliberate, but "not read" is a measurement that was never taken, so they are owed measurements rather
than absences.

**That measurement was taken on 2026-10-01 and all three rows are now decided; see
[AbsentRows613.md](AbsentRows613.md).** The measurement did not need a 6.1.3 guest: `persistref` — the
value both persistent-reference spellings carry, read by `dlsym` off the host's own framework — is in
**no held rung below 11.0**, read out of all fifty per-release indexes, so no code path in 6.1.3 compares
a keychain query against that attribute's name. That is the sentence "not read" was reaching for, and it
is a fact about the release rather than an assumption. All fourteen rows of `absent_Security.json` and
`ios11.json` are decided in the same series: six `implemented`, eight `inert`, none `absent`, none
`owed`. Two verdicts in `DecisionTable.md` were overturned by it and say so in place — the port cannot
hold what a caller passed to a **release** setter, and 6.1.3 **does** hold the certificate chain.

## A claim withdrawn: "the release offers neither half of the pair"

An earlier version of this file, and of the probe beside it, said the release has no
`SSLSetProtocolVersionEnabled` because the 16.4 SDK declares it inside `#if TARGET_OS_OSX`
(`SecureTransport.h:511`). **That was an over-claim and it is withdrawn.** A symbol DECLARED IN THE SDK
and a symbol EXPORTED BY 6.1.3 are different facts: the `#if` is the SDK's view of `TARGET_OS_OSX`, and a
release can export a name the SDK no longer declares. What the header establishes is only that a symbol
declared there for macOS cannot be *called through a declaration* by a binary built against that SDK.

## Measured: what 6.1.3 EXPORTS, and the one real absence

Read out of iOS 6.1.3's own dyld shared cache by walking the export trie of the Security image, which is
at **`0x32e79000`, UUID `FBC24F15BD9E37539CDD6E3576BDE938`, 660 exports**:

| symbol | on 6.1.3 |
| --- | --- |
| `_SSLCreateContext` | **exported** — the control, and it appears |
| `_SSLGetProtocolVersionMin` | **exported** |
| `_SSLGetProtocolVersionMax` | **exported** |
| `_SSLSetProtocolVersionMin` | **exported** |
| `_SSLSetProtocolVersionMax` | **exported** |
| `_SSLSetProtocolVersionEnabled` | **exported** |
| `_SSLGetNegotiatedProtocolVersion` | **exported** |
| `_SSLGetProtocolVersionEnabled` | **not exported** |
| `_SSLGetProtocolVersion` | **not exported** |
| `_SSLNoSuchFunctionForControl` | **not exported** — the negative control, and it does not |

Evidence, cited not copied:
`charon/.agent-work/runs-archive/coord-exports/exports.py` sha256
`6f550db0400871de3999dfd31de39dac67374d9440d67176ffb08f4528d5224f`; `exports-613.txt` sha256
`a3aa4fa2aee74efcafbcb5a22a392878ef7c6c5ff8e7852518727acfa368fb51`. This band reproduced all three
numbers by running that script itself.

**So the earlier statement stands, stated as an EXPORT FACT and not as a header fact: 6.1.3 does not
export `SSLGetProtocolVersionEnabled`,** and a string hit in the cache is not an export — the trie is.
**And the conclusion I drew from the header was wrong in the other direction:** `SSLSetProtocolVersionEnabled`
is declared for macOS only in the 16.4 SDK and is nevertheless **exported by 6.1.3**, so the SDK's `#if`
stopped a call that the release can make. The guest measurement therefore uses the **Min/Max getters and
the Set\* calls**, and has no way to enumerate one protocol at a time.

The eight `sec_protocol_options_*` block setters are unaffected either way: they are `inert` because 6.1.3
has no stack that takes a `sec_protocol_options_t`, which does not depend on any of this.
