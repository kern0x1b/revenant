# The sec_protocol_metadata family

Three rows, all `API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0))`:

| api | line | answers |
| --- | --- | --- |
| `sec_protocol_metadata_get_negotiated_tls_protocol_version` | `SecProtocolMetadata.h:109` | `0` |
| `sec_protocol_metadata_get_negotiated_tls_ciphersuite` | `:140` | `0` |
| `sec_protocol_metadata_access_pre_shared_keys` | `:267` | `false`, handler not run |

## The object

`clang -E` on the 16.4 SDK:

```
@protocol OS_sec_protocol_metadata <NSObject> @end
typedef NSObject<OS_sec_protocol_metadata> * __attribute__((objc_independent_class))
    sec_protocol_metadata_t;
```

So the port supplies the object under its own name. **The class is deliberately empty**: this header has
no setter, and nothing in 6.1.3 ever produces a metadata — one is handed to a TLS callback by the
handshake that negotiated it, and the release has no TLS stack that calls one. A held ciphersuite or
version would be a number that *looks* negotiated with no caller able to have set it.

## Two of the three have no documented absence, and the port does not invent one

```
58   typedef CF_ENUM(uint16_t, tls_protocol_version_t) {
         tls_protocol_version_TLSv10 = 0x0301   (deprecated alias)
         tls_protocol_version_TLSv12 = 0x0303
         tls_protocol_version_TLSv13 = 0x0304
         tls_protocol_version_DTLSv12 = 0xfefd };
101  typedef CF_ENUM(uint16_t, tls_ciphersuite_t) { ... }    every member a real ciphersuite
```

The header promises "A `tls_protocol_version_t` value" and "A `tls_ciphersuite_t`" and names **no
absence**, and neither enum has an invalid member. So `0` is not a member of either, and returning it is a
sentinel the port manufactures. The cost is in the row: **a caller cannot tell it from a value the enum
does not define.** It is the only answer that is not a lie about a negotiation.

## The third has a documented absence, and is answered properly

The header documents the return as true when the PSKs were accessible and false otherwise (`:267`).

It returns `false`, and **does not run the handler**. A block that ran would hand the caller a PSK and a
`psk_identity` that were never negotiated, and the caller would act on a secret that does not exist.

## The measurement

`.agent-work/runs/cc/protocolmeta.log` — `armv7-apple-ios6.0`, 16.4 SDK, the library's own flags,
`EXIT=0`, 0 diagnostics, `Mach-O object arm_v7`. The host case drives all three on a port object
reached with `NSClassFromString` (redeclaring the class would be a second definition), and proves the ARC
balance the only way an ObjC object can be shown under ARC: **alive in scope, deallocated after the pool
drains**, via a weak reference read outside the scope that owned it. `CFGetRetainCount` is not available
under ARC and must not be called.

The mutation runs the handler, and the only difference is `psk-handler-calls: got 1 and the port claims 0`.
Two earlier versions of that mutation did not compile — `dispatch_data_create`'s third argument is a
`dispatch_queue_t`, not a buffer, and passing bytes there is the error.
