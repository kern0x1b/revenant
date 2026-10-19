# NSXPC members, iOS 13 and 14

activate, scheduleSendBarrierBlock: and the interface XPC types.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

Not carried. An iOS 6 application cannot ship an XPC service, and the connection needs launchd to hand out an endpoint, so no working substitute exists.
