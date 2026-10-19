# The eight configuration settings of iOS 9 to 26

`shouldUseExtendedBackgroundIdleMode`, the two TLS versions, `requiresDNSSECValidation`,
`allowsUltraConstrainedNetworkAccess`, `usesClassicLoadingMode`, `enablesEarlyData` and
`multipathServiceType`. Each is kept beside the configuration, which is what the header promises: a
configuration carries them and a session built from it reads them back.

Which of them the port can *act on* differs each way, and that is written down rather than left to a
reader:

- **Nothing here is read by anything.** The port's session does not read
  `shouldUseExtendedBackgroundIdleMode`, and there is no stream task in the port that reads the two
  TLS versions: the port's data path runs over the release's own `NSURLConnection`, which is the
  system's TLS and takes no version from a port, and 6.1.3 has no extended background idle mode for a
  session to enter. All three are **kept and answered**: the value an application sets is the value it
  reads back, and that is the whole of what they do on this release. When the port gains a task that
  negotiates its own TLS, the TLS two become read by it and this paragraph names it; until then it
  must not.
- **`requiresDNSSECValidation`** is kept and answered. The release's resolver validates what it
  validates, and 6.1.3 has no such validation to ask for, so the value the application sets is the
  value it reads back.
- **`allowsUltraConstrainedNetworkAccess` and `usesClassicLoadingMode`** are kept and answered for the
  same reason: the release's connection is not a port's to change. The first sits beside the SDK's
  `allowsExpensiveNetworkAccess` and `allowsConstrainedNetworkAccess`, which
  `NSURLRequest+NetworkAccess13.m` already keeps under its own names.
- **`enablesEarlyData` and `multipathServiceType`** are kept and answered, and for a second reason as
  well: 6.1.3 has neither early data nor multipath, so there is nothing here to switch on, and the
  header's own answer on a system without them is the default.

Measured by `tests/backports/device/foundation15batch.m` on the device, and the defaults by a fresh
configuration: every flag false, every version nil, and `multipathServiceType` at its own `None`.
