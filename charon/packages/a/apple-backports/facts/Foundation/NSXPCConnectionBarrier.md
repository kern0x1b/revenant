# The proxy with an error handler, and the send barrier, iOS 9.0 and 13.0

Source: the SDK 26.2 headers; the 6.1.3 cache's selector table and its `libxpc.dylib` exports, read
with `tools/corpus/cache-value.lua`.

**`-synchronousRemoteObjectProxyWithErrorHandler:`** is the release's own
`-synchronousRemoteObjectProxy` with the failure handed to a block rather than raised: a proxy that
cannot be made answers nil and the handler hears the error. The modern header declares only the handler
spelling, so the plain one -- which the release's binary has carried since long before that spelling
existed (measured: the selector is in the 6.1.3 cache) -- is declared in the file and called.

**`-scheduleSendBarrierBlock:`** runs the block once everything queued on the connection before it has
gone. The release's connection sends synchronously and offers no barrier of its own, so the block goes
behind the connection's own target queue when it has one, which for a connection that sends as it is
given a message is the same order. `xpc_connection_send_barrier` **is** exported by `libxpc.dylib` in
6.1.3 (measured), and the port does not reach it: the release's `NSXPCConnection` keeps its connection
in an ivar no public API returns, and a private ivar is not what this port builds on. The divergence
is this sentence rather than a silent difference.

The other three XPC rows are decided the other way round and are in `NSDecidedRows.md`: `xpc_type_t`
is the type the XPC framework introduced in iOS 8, and a coder's connection belongs to the system's
own machinery.
