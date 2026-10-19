# NSHTTPCookie SameSite, iOS 13

sameSitePolicy, the two policies and the SameSite cookie property.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

The attribute is parsed from the cookie properties and header fields in the host's spelling and answered by sameSitePolicy. The release's cookie store does not keep it, so the policy lives in the process only and is lost when the cookie is read back from storage.
