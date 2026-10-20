# Reading a Name out of the certificate the release already has

`SecCertificateCopyNormalizedIssuerSequence` and `SecCertificateCopyNormalizedSubjectSequence`
(`__IPHONE_10_3`, `SecCertificate.h:135` and `:145`) return the DER of a certificate's issuer and
subject Names.

## Where the release's data ends and the port's parsing begins

The release ends at **`SecCertificateCopyData`**, `__IPHONE_2_0` (`SecCertificate.h:86`). It hands over
the certificate's whole DER, and the issuer and subject Names are fields of that. There is **no release
call that returns a Name** — not `SecCertificateCopySubjectSummary` (`__IPHONE_2_0`, `:101`), which is a
human summary string, and not the deprecated `SecCertificateGetSubject`/`GetIssuer` (`:319`, `:337`),
which take a `CSSM_X509_NAME *` and are not used here at all.

So the port does two separable things and the split matters: the **bytes** are the release's, unaltered;
the **walk** is the port's. What comes back is a slice of the release's own DER with nothing re-encoded.

An earlier revision of `DecisionTable.md` pointed these two rows at the deprecated CSSM path and called
them **owed pending a guest measurement**. That was unnecessary: the data the CSSM call would have
supplied is already in the release's DER, so a bounded reader removes both the deprecated dependency and
the measurement.

## The walk, and why it is bounded

`Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }` and
`TBSCertificate ::= SEQUENCE { version [0] EXPLICIT DEFAULT v1, serialNumber, signature, issuer,
validity, subject, ... }`, so the walk is: SEQUENCE, SEQUENCE, step over `[0]` if present, INTEGER,
SEQUENCE, and the Name is next — stop at the issuer, or step over validity for the subject.

**No offset is hard-coded.** The reader finds each field by its tag, so another certificate of another
length, key or issuer walks the same way.

One rule governs the whole walk and both of its bugs: **the cursor advances to `next`, never to
`content`.** A TLV's content is where its bytes begin; the next field begins where the whole TLV ends.
Stepping by `content` lands *inside* the field just read, which is a place the structure never
describes.

## Malformed input is NULL

The reader is reachable from a case so this is exercised rather than assumed — a certificate the host
refuses to build never reaches the port. Five shapes are refused: a length that runs past the buffer, a
first tag that is not a SEQUENCE, an **indefinite length** (`0x80`, which DER does not allow at all), a
long-form length naming more bytes than exist, and a `tbsCertificate` too short to hold the fields the
walk needs. A NULL certificate answers NULL.

## The differential, and the two bugs it found

The host has these two functions, so this is a differential rather than a self-comparison. The host's
copy is reached by **`dlopen` of the system framework and `dlsym` off that handle** — *not* by calling
the name, because the case defines the same function and a call to the name resolves to the port. The
first version of the case called the name twice and passed while the port returned NULL for everything:
it compared the port with itself.

**Both lengths are printed**, because "the bytes are not the host's" does not say whether the host has
different bytes or a different number of them — and that is how the two-byte header was found: the port
returned 66 (the Name's content) against the host's 68. A normalized sequence is the Name's **whole TLV,
tag and length included**.

The self-signed property is asserted in the direction that is stronger: the fixture is self-signed, so
its issuer and subject **must** be identical, and a reader that walked to the wrong field twice would
pass a "they differ" check and fails this one.

Three bugs were found this way, all of the same shape and none visible to a length check:
1. the walk resumed at the version's `content`, one byte inside its own integer, and read the rest of the certificate as garbage;
2. every step after it had the same defect, and the walk was NULL for both Names;
3. the slice was copied **after** `CFRelease` on the `CFDataRef` that `bytes` pointed into — the right length and zero bytes, which is what a use-after-free looks like when nothing else is watching.
