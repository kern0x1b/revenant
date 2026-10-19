# The request flags of iOS 13 to 26, kept per request

Six properties of `NSURLRequest` that arrived between iOS 13 and iOS 26:
`allowsPersistentDNS`, `allowsUltraConstrainedNetworkAccess`, `assumesHTTP3Capable`, `attribution`,
`cookiePartitionIdentifier` and `requiresDNSSECValidation`.

Source: the SDK 26.2 headers. The port's own session is built over the release's `NSURLConnection`
(`Foundation/NSURLSession.m`), which is the reason each one is either honoured or not.

- **`allowsUltraConstrainedNetworkAccess`** joins `allowsExpensiveAccess` and
  `allowsConstrainedAccess`, which `NSURLRequest+NetworkAccess13.m` already keeps and the session
  reads, so this one is kept in the same place and read the same way.
- **`assumesHTTP3Capable`** is what a session would use to pick a protocol. The port's session speaks
  HTTP/1.1 over the release's connection, so the value is kept and answered and is not acted on: the
  alternative would be a protocol the port does not implement.
- **`allowsPersistentDNS`, `requiresDNSSECValidation` and `cookiePartitionIdentifier`** ask of the
  release's resolver, its TLS stack and its cookie storage three things no 6.1.3 entry point takes. The
  values are kept, so an application that sets them and reads them back sees what it set, and the
  port's facts say which of them the release cannot act on.
