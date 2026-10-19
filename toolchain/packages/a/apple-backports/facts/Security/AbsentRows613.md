# The fourteen absent rows of Security, and what 6.1.3 answers for each

The fourteen rows `coordination/corpus/queue/Security.tsv` names, adjudicated. For each: what the
release this port runs answers for the same call, what the port answers, and where the two differ.

**Six are implemented, eight are inert, none is `absent` and none is `owed`.** That last pair is the
result, not a convention: every one of the fourteen was `absent` in the registry, and `absent` means
the release cannot carry the API. Security on 6.1.3 is not that case. The release HAS the facilities —
the trust object, the policy object, both their iOS 2.0 creators, the keychain — and what it lacks is
four accessors and one constant's effect. So the work here was measuring what the release answers,
which is what this page is.

`inert` is not a parking space. It means the symbol exists, loads and is callable, and the effect
field says in words what a caller gets back — for all eight, and in every case the answer is smaller
than the host's, and each difference is named in the row itself.

## What was measured, and with what

| | tool | what it answers |
| --- | --- | --- |
| presence, 6.1.3 and 4.3, armv7 | `tools/cache-index/first-rung.lua`, over the 50 per-release indexes in `~/.revenant/cache-index` | whether a name exists in a release's export trie and symbol table |
| what this Mac answers | `tests/backports/host/security/trust-accessors.m`, linked with the port's own eight objects | the host's Security.framework beside the port's, on one run, key by key |
| the release's own accessors | the same case, through the port | which chain, which verdict, which property keys |

The presence table, armv7, `yes` meaning the symbol is in that release's export trie:

| symbol | 6.1.3 | 4.3 |
| --- | --- | --- |
| `_SecPolicyCreateBasicX509` | yes | yes |
| `_SecPolicyCreateSSL` | yes | yes |
| `_SecPolicyGetTypeID` | yes | yes |
| `_SecTrustEvaluate` | yes | yes |
| `_SecTrustGetCertificateCount` | yes | yes |
| `_SecTrustGetCertificateAtIndex` | yes | yes |
| `_SecTrustSetAnchorCertificates` | yes | yes |
| `_SecTrustSetAnchorCertificatesOnly` | yes | yes |
| `_SecTrustSetPolicies` | yes | **no** |
| `_SecPolicyCopyProperties` | no | no |
| `_SecPolicyCreateWithProperties` | no | no |
| `_SecTrustCopyPolicies` | no | no |
| `_SecTrustCopyCustomAnchorCertificates` | no | no |
| `_SecTrustCopyCertificateChain` | no | no |
| `_SecTrustCopyResult` | no | no |
| `_SecTrustEvaluateAsync` | no | no |
| `_SecTrustEvaluateAsyncWithError` | no | no |
| `_SecTrustSetOCSPResponse` | no | no |
| `_SecTrustSetSignedCertificateTimestamps` | no | no |
| `_SecAccessControlGetTypeID` | no | no |
| `_SecAccessControlCreateWithFlags` | no | no |
| `_kSecAttrPersistentReference` | no | no |
| `_kSecAttrPersistantReference` | no | no |
| `_kSecUseDataProtectionKeychain` | no | no |

Two of those lines carry more than presence, and both were measured rather than read:

- **The literals.** `persistref` — the value both persistent-reference spellings carry — is in **no
  held rung below 11.0**: all fifty per-release indexes were read for it, and it appears in 11.0,
  12.0, 16.0 and 18.0 and nowhere else. A keychain matches an attribute against the very string a
  caller passes, so an attribute whose name is in no image of the release cannot be one it compares
  against. The same reading puts `accc` (kSecAttrAccessControl) and `akpu` first at 8.0.
- **The ladder has a hole above 12.0.** `first-rung.lua` answers 9.0 for
  `_SecTrustSetSignedCertificateTimestamps` and 16.0 for `_SecTrustEvaluateAsyncWithError` and
  `_SecTrustCopyCertificateChain`, and `release-split` prints the reason itself: "no release is held
  between 12.0 and 16.0". So a rung here is a PRESENCE answer over the rungs that exist, and the
  registry's `introduced` stays what the header declares — 12.1.1, 13.0 and 15.0 respectively.

## The host's answers, which is the oracle for every value

From `trust-accessors.m` over the committed fixture certificate. The column that matters is the third:
what this Mac answers for the same call.

| what | host | port | agree? |
| --- | --- | --- | --- |
| `kSecAttrPersistentReference` | `persistref` | `persistref` | yes |
| `kSecAttrPersistantReference` | `persistref` | `persistref` | yes |
| `kSecUseDataProtectionKeychain` | `nleg` | `nleg` | yes |
| basic X.509 policy from an identifier | a policy | a policy | yes |
| its properties | 1 key, `SecPolicyOid = 1.2.840.113635.100.1.2` | the same, same string | yes |
| SSL policy with a hostname | 2 keys | 2 keys | yes |
| SSL client policy | 2 keys | 2 keys | yes |
| `SecPolicyCreateWithProperties(kSecPolicyAppleSMIME)` | a policy | **NULL** | **differ** |
| properties of a policy neither side made | a dictionary | **NULL** | **differ** |
| `SecTrustCopyCertificateChain` | array of 1, the fixture | array of 1, the fixture | yes |
| `SecTrustCopyResult` | **4 keys** | **2 keys** | **differ** |
| the verdict in it | 5 | 5 | yes |
| the date in it | a CFDate | a CFDate | yes |
| `SecTrustCopyPolicies` | **array of 1** | **empty array** | **differ** |
| `SecTrustCopyCustomAnchorCertificates` | **array of 1** | **NULL** | **differ** |
| `SecTrustEvaluateAsync` | errSecSuccess, verdict 5, not inline | errSecSuccess, verdict 5 | yes |
| `SecTrustEvaluateAsyncWithError` | errSecSuccess, `false`, not inline | errSecSuccess, `false` | yes |
| `SecTrustSetOCSPResponse` | errSecSuccess | errSecSuccess | yes |
| `SecTrustSetSignedCertificateTimestamps` | errSecSuccess | errSecSuccess | yes |
| `SecAccessControlGetTypeID` | 77, not CFString's | the port's own class, not CFString's | **differ** |

Three of those measurements are worth keeping even though the row lands the same way as the host:

- **The host's result dictionary carries four keys, two of which SecTrust.h declares.** Printed key by
  key they are `TrustResultDetails`, `TrustResultValue`, `TrustEvaluationDate` and `TrustEvaluationID`.
  Only the middle two are keys the header declares (:163-178); `TrustResultDetails` and
  `TrustEvaluationID` are undocumented, which is why no row here exists for them. `TrustResultDetails`
  is a dictionary of per-certificate status codes — `AnchorTrusted`, `StatusCodes` — and **6.1.3 has no
  per-certificate status accessor at all**, so there is nothing that could fill it. That is the one
  difference the port cannot close, and it is in the row.
- **`CFEqual` does not rescue `SecPolicyCopyProperties`.** On the host two separately created basic
  X.509 policies compare equal, a basic and an SSL policy do not, two SSL server policies with the
  same host do and two with different hosts do not. So equality identifies a policy only for a caller
  prepared to build every candidate — a guess with extra steps — and 6.1.3's own CFEqual was not
  measured at all. The port answers from its own record instead.
- **The host TRAPS on `SecTrustEvaluateAsyncWithError` called off the queue it is handed.** Measured:
  exit 133 from inside Security.framework, which is what SecTrust.h:427-431's "MUST be called from
  that queue" means in practice. The port does not enforce it, and the row says so.

## Row by row

The three that turned out to be the release's own answer rather than a port's reconstruction:

- **`SecTrustCopyCertificateChain()` — implemented.** 6.1.3 HAS the chain, through
  `SecTrustGetCertificateCount` and `SecTrustGetCertificateAtIndex`, both iOS 2.0 and both on 4.3, and
  the header names this function as the replacement for the second of them (:518). So this is one loop
  over the release's own accessors. The difference the header itself names at :514-515 is that those
  two accessors are not thread-safe, so a concurrent evaluation can change the chain under the walk.
- **`SecPolicyCreateWithProperties()` — implemented.** 6.1.3's policy creators are fixed and take no
  dictionary, and there are exactly two of them, both iOS 2.0: `SecPolicyCreateBasicX509` (:167) and
  `SecPolicyCreateSSL` (:180). The identifier is mapped onto them. For the thirteen identifiers 6.1.3
  cannot build — SMIME, EAP, IPSec, revocation, code signing — the answer is NULL, which is the
  header's own answer for a policy that could not be created (:241-242), and the host builds one of
  them, so the difference is named.
- **`SecTrustCopyResult()` — implemented.** 6.1.3 gives the verdict (`SecTrustEvaluate`, iOS 2.0) and
  nothing else; no call on this release reads a result dictionary back. The dictionary is therefore
  built, and carries the two keys the release can answer: the verdict out of that call, and the date of
  it. `SecTrustGetTrustResult`'s facts page records the same fact for the accessor of that name — there
  is no stored result on this release, so a reader gets a verdict computed on the call.

The five where the port does real work and the release has nothing underneath:

- **`SecPolicyCopyProperties()` — implemented.** A round trip, not a reconstruction: for a policy that
  came through the port's own `SecPolicyCreateWithProperties`, the dictionary read back is the
  dictionary passed, plus the OID of the creator the port called. For a policy the release made and
  the port never saw — the ordinary way to make a policy on this release — it answers NULL, the
  header's own nullable result, and NOT a guessed OID.
- **`SecTrustEvaluateAsync()` and `SecTrustEvaluateAsyncWithError()` — implemented.** Both run the
  release's own synchronous evaluation and deliver the release's own verdict on the queue the caller
  named, so the callback arrives after the call returns as the contract promises. What differs is
  visible as blocking: the evaluation has already happened when the callback fires. The WithError
  variant adds a second named difference, that the port does not enforce the queue precondition the
  host enforces by trapping.
- **`SecTrustCopyPolicies()` — inert.** 6.1.3 has the setter — `SecTrustSetPolicies` is iOS 6.0 — and
  no reader. The setter a caller reaches is the RELEASE'S, so the port never sees that call and cannot
  report what was set; the answer is an empty array, and the effect says the empty array does not mean
  "this trust has no policies", it means 6.1.3 cannot be asked. The host returns the caller's one
  policy. 4.3 has no setter at all and answers the same way, which is right.

The four that are accepted and change nothing, each with the consequence written down:

- **`SecTrustSetOCSPResponse()` and `SecTrustSetSignedCertificateTimestamps()` — inert.** 6.1.3 has no
  OCSP input to its evaluation and no certificate transparency in it at all, so both accept and hold
  nothing. The consequence is the row: a revocation a caller's OCSP response would have proved is not
  proved by it, and a caller stapling timestamps gets no additional scrutiny and no error.
- **`SecAccessControlGetTypeID()` — inert.** 6.1.3 has no SecAccessControl at all — neither this
  function nor `SecAccessControlCreateWithFlags`, and the literals that would carry it first appear at
  8.0 — so there is no instance for a type ID to identify. The port's answer is the runtime's own
  CFTypeID for the port's private class, which is a real and unique number rather than an invented
  constant; returning some other type's ID would be worse than returning nothing, because a caller
  writing `CFGetTypeID(x) == SecAccessControlGetTypeID()` would be told a CFString was an access
  control.
- **`kSecUseDataProtectionKeychain` — inert.** The key selects a data-protection keychain, and this
  release has one keychain and neither `kSecAttrAccessControl` nor a protection class to put in it, both
  first appearing at 8.0. The port carries the host's own value, `nleg`, so a caller that logs the
  dictionary it built sees what it would see on a newer release, and 6.1.3 addresses the same keychain
  it would have without it.

And the two spellings, which are one key:

- **`kSecAttrPersistantReference` and `kSecAttrPersistentReference` — inert.** `SecItem.h:553-556`
  declares both on consecutive lines with the same availability, and dlsym off the host's own framework
  hands back the same string, `persistref`, for each — which is how Apple declares a deprecated alias
  kept for source compatibility. The port carries both with that one value. 6.1.3 ignores the
  attribute: the string is in no held rung below 11.0, so no code path in the release compares a query
  against it. A caller that adds an item with this attribute and later queries by it gets no match,
  while the item is still findable by its other attributes — a persistent reference that does not
  persist a reference.

## The check, and that it can fail

`tests/backports/host/security/trust-accessors.m` asks each of the fourteen of BOTH the port and the
host and prints one line per answer, and `compare-trust-accessors.py` holds **twenty-one keys that must
agree and seven that must differ**. A comparison that only ever said "the same" would be worthless
here, so the file names every expected difference and fails on any difference it does not name.

The port is reached by `dlsym(RTLD_DEFAULT, …)` and the host by `dlsym` off a separate `dlopen` handle
of the system framework. That is not tidiness: the case DEFINES the same fourteen names, so calling one
would let the linker choose and it chose the framework's the last time this repository hit that
(`trust-result.m`'s header records it — a mutant that invents a verdict instead of asking the release
ran, and the case reported the framework's answer as the port's).

Eight mutations, each built the way its case is built and each noticed for the right reason:
the chain's guard, the result dictionary losing its date, losing its verdict, an SSL policy given the
basic X.509 OID, the misspelled constant given a value of its own, the OCSP setter refusing, the SCT
setter refusing, and the access control type ID answering CFString's.

    $ sh tests/backports/host/security/run-cases.sh
    run-cases: OK - 21 cases, 26 mutants, 25 noticed

The twenty-sixth is `identity`, a byte-identical copy that is REQUIRED not to be noticed, and its
absence from the count is what proves the count can go lower.

## What is NOT measured here

- **6.1.3's own `CFEqual` on a `SecPolicyRef`.** The host's is measured above; the release's is not,
  and nothing here depends on it: `SecPolicyCopyProperties` answers from the port's own record.
- **What `SecItemCopyMatching` does when handed an attribute the release does not know** — read,
  ignored, or refused. The registry rows claim the narrower thing that is measured: no code path in
  6.1.3 compares a query against the attribute's name, because the name is in no image of the release.
  A guest run would settle the rest, and it is not owed for any row here, because every row's effect
  is already true without it.
- **`SecTrustEvaluate` over a chain longer than one.** The fixture is one certificate, so the result
  dictionary's answer is measured on a one-certificate chain. The keys are the same either way —
  `SecTrustCopyResult`'s per-certificate key is the one the port cannot fill — but the chain's length
  under a real evaluation is not measured.