# The sec_trust / sec_identity / sec_certificate family, and the obstacle measured

Nine rows, all from **`Security/SecProtocolTypes.h`**, not from `SecIdentity.h` or `SecTrust.h` as the
names suggest:

| api | line |
| --- | --- |
| `sec_trust_create` | :188 |
| `sec_trust_copy_ref` | :203 |
| `sec_identity_create` | :218 |
| `sec_identity_create_with_certificates` | :237 |
| `sec_identity_access_certificates` | :256 |
| `sec_identity_copy_ref` | :273 |
| `sec_identity_copy_certificates_ref` | :288 |
| `sec_certificate_create` | :303 |
| `sec_certificate_copy_ref` | :318 |

## What the header says they are

```
    34  #ifndef SEC_OBJECT_IMPL
    41  SEC_OBJECT_DECL(sec_trust);
    42  SEC_OBJECT_DECL(sec_identity);
    43  SEC_OBJECT_DECL(sec_certificate);
```

and the comment above them (`SecProtocolTypes.h:36`), which is the specification, in our words: the wrappers make
the trust, identity and certificate CoreFoundation types usable in os_object-style APIs and under ARC, and the
client can take the underlying CF type back out.

So a wrapper is an **object that holds a CF ref** — the honest shape is a small class per type, holding
the ref with a `CFRetain` its `dealloc` gives back, and the getters handing it out `+1`.

## The obstacle, measured rather than assumed

**The types are already declared by the headers a Security port must include.** Writing the family as
three `@interface` declarations in the port's own file does not compile:

```
error: conflicting types for 'sec_identity_access_certificates'
     (SecProtocolTypes.h, the SDK's own declaration)
```

`Security.h` reaches `SecProtocolTypes.h`, so on a build that links the release's headers the port sees
`@interface sec_identity` and the function prototypes **already**, and a second declaration of either is a
conflict rather than an override. Two consequences follow, and they are the decisions this family needs:

1. **The port must not redeclare the class.** It can only implement the nine functions the header
   declares — which is fine, and is what a backport does — but then it cannot add an ivar to hold the
   `CFTypeRef`, because the class's storage is already fixed by the header.
2. **The held state has to live outside the class**: a side table keyed by the object, or a category with
   an associated object. That is a real design choice with a real cost — a side table keyed by object
   pointer needs a lock, needs a removal on `dealloc`, and cannot be a category ivar — and it is the
   reason this family is not a mechanical transcription of the nine functions.

The alternative, declaring the class in the port and **not** including `SecProtocolTypes.h`, is not
available either: the header carries `API_AVAILABLE(ios(13.0))` on all nine, so a file compiled for
`armv7-apple-ios6.0` with `-Werror=unguarded-availability-new` fails on the header's own availability
macros for the very API it provides. That much is in the build log either way.

## State of the nine

**All nine are built**, as the table below says: the four `sec_certificate_*` and `sec_trust_*` rows are
measured on real refs, and the five `sec_identity_*` rows are measured on a STAND-IN `CFTypeRef` — the
wrapper's own ownership, with a real `SecIdentityRef` an owed GUEST measurement. That second half moved
with the identity series and is recorded where it was measured, in
[SecObjectWrappersIdentity.md](SecObjectWrappersIdentity.md); this section keeps the header facts, the
exact error and the two design options, so the next attempt at the guest measurement starts from the
measurement rather than from the nine greps again.

## The nine rows, measured from the registry, and which of them is a `sec_identity_t`

| api | kind | introduced | state | file |
| --- | --- | --- | --- | --- |
| `sec_identity_access_certificates()` | function | 16.0 | **built** | `ios16.json` |
| `sec_certificate_copy_ref()` | function | 12.0 | **built** | `ios12.json` |
| `sec_certificate_create()` | function | 12.0 | **built** | `ios12.json` |
| `sec_identity_copy_certificates_ref()` | function | 12.0 | **built** | `ios12.json` |
| `sec_identity_copy_ref()` | function | 12.0 | **built** | `ios12.json` |
| `sec_identity_create()` | function | 12.0 | **built** | `ios12.json` |
| `sec_identity_create_with_certificates()` | function | 12.0 | **built** | `ios12.json` |
| `sec_trust_copy_ref()` | function | 12.0 | **built** | `ios12.json` |
| `sec_trust_create()` | function | 12.0 | **built** | `ios12.json` |

Eight of the nine are introduced at **12.0**, not 13.0; the ninth, `sec_identity_access_certificates`, is
16.0, and it is in `ios16.json` for that reason — `release-split` puts it in a different rung from the
other eight, which is why there are two identity objects. The `sec_identity_*` five are declared in
`SecProtocolTypes.h` at `:218` (create), `:237`
(create_with_certificates), `:256` (access_certificates), `:273` (copy_ref) and `:288`
(copy_certificates_ref), in the same header that declares the three types at `:41-43`.

## Why no REAL identity can be measured here, exactly

**A real `SecIdentityRef` cannot be made on this Mac without the Mac's keychain**, which is why the five
`sec_identity_*` rows and `set_local_identity` are measured on a stand-in and not on an identity. The
rows themselves are NOT owed — they are built, and what is owed is the guest measurement. Every factory
in `SecIdentity.h` is unavailable on iOS:
`SecIdentityCreateWithCertificate` at `:65` is `__OSX_AVAILABLE_STARTING(__MAC_10_5, __IPHONE_NA)`, and
the preference, preferred and system-identity calls at `:126`, `:150` and `:174` are
`__IPHONE_NA` too. `SecIdentityCreate` — the one that takes a key or a certificate directly and so would
be the in-memory path — **is not among the factories the header declares**. So an identity built from an
ephemeral in-memory key is not possible on this release by any public route, and the test the coordinator
asked for cannot be written rather than merely being hard.

The slice that IS buildable is the two types whose refs are made without a keychain, and those four rows
(`sec_certificate_create`, `sec_certificate_copy_ref`, `sec_trust_create`, `sec_trust_copy_ref`) are
REAL WRAPPERS OF REAL REFS rather than answers that report an absence.

**Nine built; the real-identity measurement is what is owed.** The four certificate and trust rows are
measured on real refs: a real `SecCertificateRef` from
`SecCertificateCreateWithData` and a real `SecTrustRef` from `SecTrustCreateWithCertificates`, neither
touching a keychain, with the retain balance **1 2 3 2 1**, `copy_ref` answering the same ref by pointer
equality, and the weak-reference release reading nil after the scope drains.

**The five identity rows are built, and they were never impossible** — a claim of mine said otherwise and
it is withdrawn: `sec_identity_create` and its siblings take a `SecIdentityRef` the caller already has and
wrap it, exactly as `sec_certificate_create` wraps a `SecCertificateRef`, and no sentence of the header
forbids it. What was missing was the TEST, and it is now written: the case uses a stand-in `CFTypeRef`,
says in every row that it is one, and a real `SecIdentityRef` stays a guest measurement that the
[identity facts file](SecObjectWrappersIdentity.md) carries as owed.
