# `SFCertificatePresentation`, on the release's own Security and UIKit

The class arrived in iOS 18.4 and does one thing: show a sheet describing the certificate of a
`SecTrustRef` the application already holds, with a title, a message and a "Learn More" link. None
of that is a wall on this release:

- the trust is the caller's own, made with Security calls public since iOS 2, all measured present in
  the armv7 6.1.3 cache's ObjC metadata: `SecTrustEvaluate`, `SecTrustCopyProperties`,
  `SecTrustGetCertificateCount`, `SecTrustGetCertificateAtIndex`, `SecCertificateCopySubjectSummary`;
- a sheet is a `UIViewController` presented with `-presentViewController:animated:completion:` and
  dismissed with `-dismissViewControllerAnimated:completion:`, which iOS 5 gave UIKit and this
  release has, so there is no window-server surface to reach for either.

## What the sheet shows, and where each line comes from

`CharonCertificateLines` reads the trust and nothing else:

1. `SecCertificateCopySubjectSummary` of the leaf certificate, then of every certificate behind it,
   each prefixed `- ` so the chain is readable;
2. the trust's own evaluation, through `SecTrustEvaluate` and its `SecTrustResultType`, as *Trusted*,
   *Not trusted yet* or *Not trusted* - the three results the release distinguishes, mapped to the
   wording a sheet uses;
3. every `SecTrustCopyProperties` entry that has a label and a value that is not null, as
   `label: value`, so the dates and the policy the trust actually holds are on the sheet.

Nothing is filled in from the port's own knowledge. A trust the release cannot evaluate gives no
verdict line rather than one invented; a NULL trust - which is what the unavailable `-init` produces
- gives no line at all, and the sheet carries the title and message alone.

## The unavailable initialisers

`-init` and `+new` are `NS_UNAVAILABLE` in the header, and the registry's own convention for those
is the one `registry/UIKit/ios13diffable.json` already uses for
`+[UICollectionViewDiffableDataSource new]`: the call reaches `NSObject`'s, which is `alloc` and
`-init`, with the result of the initialiser above. Here `-init` is the designated initialiser's
default: `initWithTrust:NULL`. A presentation with no trust is a real, usable object - it presents,
it shows what it was given, and it dismisses - and it claims nothing about a certificate it does not
have.

## The host differential, and the two lines it cannot reach

`tests/backports/host/certificatepresentation` builds a real `SecTrustRef` on the host out of two
embedded certificates - a leaf for "Charon Backports" and the test CA that issued it, both written out
as DER so the chain is the same on every machine - and requires the port's sheet to say what the host's
own Security says about it: the same subject summary, the same chain line for the certificate behind
the leaf, the same wording for the same `SecTrustResultType`, and no line at all for the NULL trust the
header's unavailable `-init` holds. `title`, `message` and `helpURL` are read back through the port's
own accessors, and three mutations of the line-building - a different certificate, a different verdict,
an unmarked chain line - must each change a record or the run fails.

What the host cannot answer is `SecTrustCopyProperties`: it is `API_UNAVAILABLE(maccatalyst)`, not
deprecated, so a host build cannot even compile the call, and the `SecTrustCopyProperties` lines are
behind `#ifndef CHARON_HOST_DIFFERENTIAL` in the armv7 build and in no other. Those lines are the
trust's own dates and policy, and the emulator is what covers them. The host has no
`SFCertificatePresentation` of its own in this SDK either, so the oracle is the trust and not the
system's sheet - which is the same shape the port's `Security/SecTrustEvaluateWithError.m` is in.

The differential found one real defect the delivery had shipped: `-initWithTrust:` called
`CFRetain(trust)` unconditionally, and the `-init` the header marks unavailable passes NULL, so the one
caller the header says not to write trapped. The retain is now guarded, and the case that traps on it
(`sheet.trustOfUnavailableInit`) is in the suite.
