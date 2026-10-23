# What iOS 6.1.3 can still reach over TLS

This measures the SecureTransport that iOS 6.1.3 ships, and what that means for the apps and the system
networking built on it. The measurement is the emulator probe `frameworks/Backports/tests/emulate/tlsprobe/`, run with
`./xmakew l -P . frameworks/Backports/tests/emulate/tlsprobe/tlsprobe.lua` on the iPhone4,1 6.1.3 image, with host
networking. The probe's offline facts are asserted by its driver. Its handshake lines depend on the network and are
evidence, not assertions.

## What the firmware offers

- Protocol versions: SSL 3.0 through TLS 1.2. `SSLSetProtocolVersionMax` accepts each of them, and the maximum is TLS
  1.2. TLS 1.3 does not exist on this system.
- Cipher suites: 49 in total. They are RSA key exchange and ECDHE, with AES-CBC, 3DES, RC4 and SHA-1 or SHA-256 MACs.
  No suite uses AES-GCM or ChaCha20, so no TLS 1.2 AEAD suite is offered.
- ALPN: the 6.1.3 dyld cache exports neither `SSLSetALPNProtocols` nor `SSLCopyALPNProtocols`. The backport's
  `dlsym` lookup therefore finds nothing on the device. The cache holds `SSLSetProtocolVersionMax`, so the check is
  not an empty table.

## What it reaches

Results from the run of this probe, with the firmware's trust store (`SecTrustEvaluate`):

| Host | Result | Negotiated |
| --- | --- | --- |
| www.google.com | handshake ok, trusted | TLS 1.2, ECDHE-RSA-AES128-CBC-SHA |
| www.cloudflare.com, tls13.cloudflare.com | handshake ok, trusted | TLS 1.2, ECDHE-ECDSA-AES128-CBC-SHA |
| example.com | ok in one run, closed by the server in another | TLS 1.2, ECDHE-ECDSA-AES128-CBC-SHA |
| www.apple.com, github.com, tls-v1-2.badssl.com | trust rejected: recoverable failure (result 5) | not completed |
| web.telegram.org, api.telegram.org, letsencrypt.org | handshake failure `-9824` (no shared parameters) | not completed |
| a TLS 1.3-only host | unreachable by definition: the client offers at most TLS 1.2 | not tested live |

The trust rejections are measured. Their cause is not isolated: the likely reason is roots or intermediates that the
2012-era trust store does not hold, and that is a hypothesis to confirm. The handshake failures for Telegram and
Let's Encrypt are inferred to come from the missing AES-GCM suites, and that is also unconfirmed.

## What it means

NSURLConnection, UIWebView and every app that calls SecureTransport directly inherit this set. Any endpoint that needs
TLS 1.3, an AEAD suite, or a root newer than the 2012 store is out of reach. The results show that many current
endpoints still work, because they accept TLS 1.2 with CBC suites. Telegram's web and API endpoints do not, which
matters for a Telegram client.

## Proposed platform-wide fix (not implemented)

Route the system's TLS through BoringSSL. The repository's BoringSSL package (`packages/b/boringssl`, armv7 assembly
proven in the emulator) can supply TLS 1.3, AES-GCM, ChaCha20 and ALPN. The shape of the change is:

- a SecureTransport-compatible layer, backed by BoringSSL, that SSLCreateContext and the handshake, read and write
  calls dispatch to, so existing callers keep their API;
- certificate evaluation stays with `SecTrust`, so the user's trust settings still apply, and the trust store question
  above is settled by which roots that layer hands to `SecTrust`;
- CFNetwork's TLS for NSURLConnection and UIWebView reaches the same layer, so the platform changes in one place.

This document proposes that fix and does not implement it.
