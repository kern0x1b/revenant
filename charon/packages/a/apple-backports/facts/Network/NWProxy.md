# The proxy configuration, the relay hops and the privacy context

`nw_privacy_context_create` and its calls, `nw_resolver_config_create_tls` and
`nw_resolver_config_create_https`, `nw_relay_hop_create`, and the five factories of
`nw_proxy_config_*` are what a program says about the names a connection resolves: which resolver to
ask, over TLS or over HTTPS, which proxy the names may go through, of what kind, with which
credentials, for which domains, and whether a connection may go direct when the proxy cannot be used.

The port carries that as what a program said. The release this port builds for resolves names with the
resolver the system gives it, which is not asked to encrypt its answers, and it has no per-connection
proxy: a connection is made to the peer its endpoint names, and the system proxy settings are not
consulted for it. A connection that is given a privacy context holding a proxy therefore does not go
through it, and its establishment report says so - `proxy_configured` and `used_proxy` are read from
what the connection actually did, not from what the parameters asked for. That is the honest answer for
this release, and it is the same answer a program gets where no proxy is configured at all.

The declarations of the two types here are the port's own: the SDK it compiles against is 16.4, which
has no `proxy_config.h` at all, and what the types are is what the header of a release that has them
says - a protocol and a typedef each, which is what `OS_OBJECT_DECL` writes for every `nw_*` type.
