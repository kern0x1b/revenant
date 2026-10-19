# UIPrinter, iOS 8

Introduced in iOS 8.0 as a printer named by its URL, with a description of it and a check that it can be reached. The
SDK 16.4 header is the contract: `+printerWithURL:`, `-contactPrinter:` and seven read-only properties (`URL`,
`displayName`, `displayLocation`, `makeAndModel`, `supportedJobTypes`, `supportsColor`, `supportsDuplex`), all 8.0.

The release (6.1.3) has no public printer object; its print panel is `UIPrintInteractionController`
(facts in `registry/UIKit/ios15-16.json`). So a `UIPrinter` here is a value: the URL it was made with, and the
descriptive properties the host gives a printer it cannot describe. Nothing about a printer is read from the printing
system.

## Answers, measured on the host

A probe on Mac Catalyst, and the differential in `tests/backports/host/uikit-printer/` for the matching lines:

- `+printerWithURL:` returns an object for every URL, including nil, and a new object on each call (not identical).
  The `URL` reads back the URL given, or nil for nil.
- `displayName` is the empty string, not nil, for every URL tried; `displayLocation`, `makeAndModel` are nil;
  `supportedJobTypes` is 0; `supportsColor` and `supportsDuplex` are NO.
- `-contactPrinter:` answers NO for every URL nothing answers: a connection refused on 127.0.0.1:9, a URL with no host
  (`ipp:///ipp/print`), a file URL, and a name that does not resolve (`nonexistent.invalid`). The handler runs once, on
  the main queue, after the call has returned.
- A nil URL: the handler runs at once, before `-contactPrinter:` returns, with NO. This is the one case that answers
  synchronously.
- A nil handler: the call returns and nothing is reached.
- A black-hole address (192.0.2.1:631, which nothing answers): the handler runs with NO after 30.5 s on the host. This
  was measured once; the differential does not run it, because it waits half a minute.
- A live IPP queue does not get YES from the host. The Mac's CUPS (localhost:631) answers a Get-Printer-Attributes for
  an existing queue with successful-ok (checked with `ipptool`), and the host's `-contactPrinter:` answers NO for that
  queue, for the same URL in six forms: `ipp://localhost:631/printers/<queue>`, the same without the port, with a
  trailing slash, with the Mac's Bonjour name in place of localhost, `ipps://` and `https://`. Each answers NO in under
  0.1 s, after the call has returned, and the handler runs once. The host's reason is not known:
  the probe is a plain command-line process, not an application, and the host's answer may depend on that. Measured
  2026-10-15 on this Mac.
- A missing queue on the same server (CUPS answers client-error-not-found) is NO on the host, and on the port.

## What the port does

- The descriptive properties return the host's defaults above.
- `-contactPrinter:` sends an IPP Get-Printer-Attributes request (RFC 8011, version 1.1, request-id 1, with
  `attributes-charset`, `attributes-natural-language` and `printer-uri`, each written as RFC 8010 attributes) as an HTTP
  POST of `application/ipp` to the URL's host and port (631 for ipp and ipps, 80 for http, 443 for https; an explicit port
  wins), and answers
  YES only when the HTTP status is 200 and the IPP status is successful (below 0x0100). Every other answer is NO: a URL
  with no host, another scheme, a name that does not resolve, a refused or timed-out connection, a non-200 response, a
  malformed one, and an IPP status that is not successful. The request is written and the response read on one
  non-blocking connection, with a 30 s bound from the call, matching the host's black-hole time. The name lookup itself
  is not bounded by that bound. The request sends `Connection: close` and reads to the server's close; a chunked
  response is de-chunked.
- `ipps://` and `https://` URLs are contacted over TLS: the connected descriptor is wrapped by `CFStreamCreatePairWithSocket`,
  both streams get the TLSv1 security level and the URL's host as the SSL peer name, and no other SSL setting. The
  certificate is validated against the release's default trust and must match that host; an untrusted or mismatched
  certificate answers NO, and validation is never turned off. A failure after the response starts answers NO. The 30 s
  bound covers the TLS exchange, and the answer is delivered on the main queue as for the plain forms.
- The answer is delivered on the main queue, after the call returns, except for a nil URL, which answers at once.
- Measured on the port: a live queue on the Mac's CUPS answers YES, and a missing queue answers NO
  (`tests/backports/host/uikit-printer/`, the `open:live-queue` line and the `queue-missing` compared line).
  The YES is the same answer `ipptool` gives for that queue, not the host's answer: the host's is NO (above).

## Open

- The YES side is not equal to the host's. For a live queue the host answers NO and the port answers YES. The port's
  answer is the IPP one, which the CUPS oracle gives; the host's is not explained. A reviewer who wants the host's answer
  must first find why the host says NO for a reachable IPP queue.
- Status of the TLS path, measured 2026-10-15 on this Mac, with a probe that calls the port's `-contactPrinter:` and
  nothing outside this machine. (a) The Mac's CUPS TLS listener on localhost:631 was not listening (connection refused),
  so it is not measured. (b) A self-signed localhost listener (`openssl s_server`, a certificate generated for the run)
  answers NO in 0.01 s; CFNetwork reports SSLHandshake failed -9807 (errSSLXCertChainInvalid) after the server
  certificate was sent, and the server saw the client abort at key exchange, so the handshake reached certificate
  evaluation. (c) Refused ports answer NO at once (`https://127.0.0.1:9`, `ipps://localhost:631`). A local peer that
  accepts TCP and never speaks TLS answers NO at 30.01 s, the handler once, on the main queue. The host answers
  `ipps://`/`https://` NO in the differential (matrix rows `https-unreachable`, `ipps-unreachable`), so the rows match.
  Not measured: the YES side over trusted TLS (no trusted responder here, and the trust store is not changed); a server
  that closes the connection without close_notify, where the stream error answers NO but no server was tested.
- The chunked decoding path is not measured against a server. CUPS sends a Content-Length, not a chunked body.
- The port's 30 s bound is not run by the differential. The host's 30.5 s is measured; the port's timeout is not.
- Object identity is not kept: each `printerWithURL:` call returns a new object, as on the host.

## Device

Not run on a device. The 6.1.3 device has no printer to contact and no print system to query for one.
