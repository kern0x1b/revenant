# SecTrustEvaluateWithError, SecCertificateCopyKey and the serial number of a certificate

`SecTrustEvaluateWithError` and `SecCertificateCopyKey` arrived in iOS 12.0 and
`SecCertificateCopySerialNumberData` in iOS 11.0. A program that pins a certificate or
checks a server's trust calls the first before anything else. They live in their own library,
`libSecurityBackports.dylib`, built with the `security` config, so that a process which never
evaluates a trust does not load Security for them.

Source: Security of the arm64 shared cache of iOS 12.0, `_SecTrustEvaluateWithError` at
`0x181bffe78`, read for its verdict; the host's Security for everything the function says
on failure, which is the same test the device holds the port to
(`tests/backports/device/security12.m`, twenty-four checks that pass unchanged against the
host's own function); and an iPad 2 running 6.1.3 for what that release reports of a
trust it fails.

## The verdict

The function evaluates the trust and answers YES when the result is *unspecified* or
*proceed* and the evaluation itself succeeded, and sets the error to NULL: the host
does it for a caller that passed a pointer holding something else. Any other result is
NO, and a caller may pass NULL for the error.

## The error

- The domain is `NSOSStatusErrorDomain`. The description is `“<summary>” certificate
  <reason>` with the subject summary of the first certificate, the curly quotes as
  written, and `NSUnderlyingError` carries an error of the same domain and code with the
  description `Certificate <index> “<summary>” has errors: <what>;`, the reasons joined
  by `, ` in this order: `SSL hostname does not match name(s) in certificate`,
  `Certificate is not temporally valid`, `Root is not trusted`.
- The code is the first that applies: **-67843** (not trusted, "is not trusted") when the
  root is not trusted, whatever else is wrong; **-67602** (the name, "name does not match
  input") when it does not match; **-67818** ("is expired") when a certificate is outside
  its dates. Measured on the host with a self-signed certificate: an untrusted root with a
  wrong name and an expired date is still -67843, and a trusted one with both is -67602.
- The host reports a certificate that may not be used for the purpose as **-67609**. That
  case, and the ones with the results *deny*, *fatal failure* and *other error*, were not
  measured, and the port answers the not trusted error for them.

## What iOS 6 gives, and what the port does with it

The release answers `SecTrustEvaluate` with the same results, and
`SecTrustCopyProperties` lists what it found as errors in the language it is set to:
`Root certificate is not trusted.`, `Hostname mismatch.` and
`One or more certificates have expired or are not valid yet.` in English, each measured on the
iPad, beside `Policy requirements not met.`, which comes with the last and says nothing
more. The port reads those three and makes the error above from them. So:

- in a language in which the release words them differently the port finds none of the
  three, and answers the not trusted error, which is right for an untrusted root and
  wrong for the other two;
- the properties name no certificate, so the index in the underlying description is 0
  except for the root, which is the last certificate of the chain; on the host the index is
  that of the certificate with the error. For a chain of one they agree.

## The other two

`SecCertificateCopyKey` is the release's own `SecCertificateCopyPublicKey`: the same key,
owned by the caller. `SecCertificateCopySerialNumberData` reads the serial out of the
certificate's own encoding: the content of the DER integer that follows the version, its
leading zero kept when the first bit is set - `00d3ce3069babf6016` for the test certificate,
which the host answers the same - and sets the error to NULL, or to a decoding error and
answers NULL when the encoding is not one.
