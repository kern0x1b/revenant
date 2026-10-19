# SecTrustGetTrustResult, and the counterpart that was never on iOS

    456  OSStatus SecTrustGetTrustResult(SecTrustRef trust, SecTrustResultType *result)
         __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_7_0);

## The verdict this row had, and why it was wrong

The decision table said the release answers this one, and named the release's `SecTrustGetResult`
(`SecTrust.h:758`) as `__IPHONE_2_0`. That was read off the deprecation message on line 472, which
quotes `SecTrustGetTrustResult` as the replacement and reads as though the release has the older twin —
the shape that `SecTrustCopyKey` and `SecTrustCopyPublicKey` really have.

**They do not.** The availability line is:

    758  OSStatus SecTrustGetResult(SecTrustRef trustRef, SecTrustResultType *result, ...)
    760      __OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_2, __MAC_10_7, __IPHONE_NA, __IPHONE_NA);

`__IPHONE_NA` is not "old on iOS" and not "deprecated on iOS": **the function has never been part of iOS
in any release.** A wrapper for it would not link on a 6.1.3 band at all, so the one-call version the
first verdict described was not buildable.

## What the port does instead

What iOS 6.1.3 has is the evaluation itself:

    359  OSStatus SecTrustEvaluate(SecTrustRef trust, SecTrustResultType *result)
         API_DEPRECATED_WITH_REPLACEMENT("SecTrustEvaluateWithError", macos(10.3, 10.15), ios(2.0, 10.0))

so the port calls it and reports the release's own verdict.

## The effect, stated because it is a real difference

This function's contract is to return the result of an **earlier** evaluation. On 6.1.3 there is no stored
result to read, so the verdict is **computed on the call**. A caller that evaluated a trust, changed a
policy, and asked again gets a freshly evaluated answer here, where a later release hands back the
earlier one. That is a difference in what the caller can conclude, and it is in the row as well as here.

## What the case found

The case looks the port's own symbol up by name (`dlsym(RTLD_DEFAULT, ...)`) as well as the host's, off
the system framework handle. Calling by name left the *linker* to decide which definition a call reached,
and with `-framework Security` in the link that is not a safe assumption to leave unstated.

Two mutations were run. The **first one did not fail, and the reason was not the harness**: it claimed
`kSecTrustResultRecoverableTrustFailure`, which is what this fixture *really* evaluates to — a
self-signed certificate over a self-signed anchor. A mutant that reproduces the correct answer is not a
weak mutation, it is a useless one, and the only tell was that the port and the host agreed. The second
claims `kSecTrustResultProceed` and is named:

    verdict  0  0  1  5
    WRONG  verdict: port [0/1] and the host says [0/5]
