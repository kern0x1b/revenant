# Expensive and constrained network access, iOS 13

allowsExpensiveNetworkAccess and allowsConstrainedNetworkAccess on requests and configurations, and NSURLErrorNetworkUnavailableReasonKey.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

The flags are stored (default YES). A request with expensive access off is refused with NSURLErrorNotConnectedToInternet and the reason key when SCNetworkReachability, opened with dlopen, reports the WWAN flag. Constrained access has no equivalent on iOS 6 and is only stored. The session wire request applies the configuration flags. Absent: the TLS minimum and maximum versions and the transaction metrics properties added in 13 and 14, which would need values from the network stack that the port does not read.
