# NSURLSessionWebSocketTask, iOS 13

The task, the message class and the delegate.

Source: the host's own Foundation and the public headers of the SDK, held against the port by the foundation14 groups of `tests/backports/host/uikit2/run.sh` and by `tests/backports/device/foundation14.m` on the device.

A client of RFC 6455 over CFStream on one run loop thread: the upgrade handshake with the key and accept check, the protocols header, masked frames, fragmented messages, ping and pong, close with a code and reason, maximumMessageSize. The delegate receives didOpenWithProtocol and didCloseWithCode. Ordering of pings and pending handler delivery, delegate capture and deferred invalidation follow the host. The device test runs against a server in the test process.
