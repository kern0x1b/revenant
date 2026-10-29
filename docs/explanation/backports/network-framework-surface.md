# The Network framework surface Telegram 13.0.0 uses

Nine Telegram files import the Network framework, and eight of them call it. The backport exists in `frameworks/Backports/src/Network`:
`NWPathMonitor.swift` defines `public final class NWPathMonitor` (line 338), and the same directory has the connection,
endpoint, listener, framer and TLS sources. This page lists the exact members Telegram calls, so the Network worker can
check the backport against them. It proposes no change.

## Why Reachability reports `cannot find type 'NWPathMonitor'`

The type is in the backport source, so the missing piece is the module. Reachability imports `Network`, and that module
is built and installed by the package `revenant@network` (`packages/n/network/xmake.lua`: iphoneos only, depends on
`revenant@swift-runtime`). On this machine the store has no installation of it: `.xmake/packages/n/` holds `ninja` and an empty `network` lock
directory left by a failed install attempt, and no package.
The overlay generator also refuses to run without it (`tools/bazel-overlay.lua:126`).

Verified: the type exists in the source, and the module is not installed. Not verified: that installing it makes
`Reachability.swift` typecheck. The Network worker should confirm that first.

The package description says TLS is not yet backported, but the tree has `NWProtocolTLS.swift` and `RevenantTLS/`. The
Network worker should reconcile the two.

## Members Telegram calls

| File | Members called | Used for |
| --- | --- | --- |
| `submodules/Reachability/Sources/Reachability.swift:90–122` | `NWPathMonitor()`, `pathUpdateHandler`, `start(queue:)`, `currentPath`, `NWPath.status == .satisfied`, `usesInterfaceType(.cellular)` | Network type: none, cellular or wifi |
| `submodules/MTProtoRustEngine/.../RustNetworkIdentity.swift:122` | `NWPathMonitor()`, `pathUpdateHandler`, `start`, `cancel`, `status`, `availableInterfaces` | Network identity for the Rust engine |
| `submodules/TelegramCore/Sources/Network/NetworkFrameworkTcpConnectionInterface.swift` | `NWConnection`, `NWParameters`, `NWProtocolTCP.Options`, `NWEndpoint`, `stateUpdateHandler`, `pathUpdateHandler`, `start`, `send`, `receive`, `cancel`, `currentPath`, `usesInterfaceType` | TCP connection to a Telegram data centre |
| `submodules/MTProtoRustEngine/.../RustStreamHost.swift` | `NWParameters(tls:…)` with `.tls`, `endpoint`, `receive` | Stream host for the Rust engine; TLS comes from here |
| `submodules/TelegramVoip/Sources/OngoingCallContext.swift` | `NWConnection`, `NWEndpoint`, `NWProtocolFramer` (`Definition`, `Instance`, `Message`, `StartResult`), `setup`, `receiveMessage`, `send`, `receive`, `stateUpdateHandler`, `cancel` | Call transport with a custom framer |
| `submodules/TelegramVoip/Sources/ReflectorBenchmark.swift` | `NWConnection`, `NWEndpoint`, `start`, `send`, `receive`, `cancel`, `endpoint` | Reflector benchmark |
| `submodules/TelegramVoip/Sources/WrappedMediaStreamingContext.swift` | `NWConnection`, `NWListener(using:on:)`, `newConnectionHandler`, `stateUpdateHandler`, `NWEndpoint`, `start`, `send`, `receive`, `cancel` | Local media streaming listener |
| `submodules/TelegramCore/Sources/Network/Network.swift` | imports `Network`; the grep matched only `start`, `parameters`, `.wifi` and `.cellular`, which may be Telegram's own names | not read; check before use |
| `submodules/TelegramCore/Sources/Utils/Log.swift` | imports `Network`; no member matched the grep | none found |

The counts behind this table are word matches: `NWConnection` 19, `NWEndpoint` 13, `NWProtocolFramer` 10, `NWPathMonitor` 6,
`NWListener` 3, `NWParameters` 1, `NWProtocolTCP` 1. Call forms the grep shows:

- `NWConnection(host: NWEndpoint.Host(host), …)` and `NWConnection(to: endpoint, using: .udp)`
- `NWListener(using: .tcp, on: self.port)`
- `NWParameters(tls: nil, tcp: tcpOptions)` and `NWProtocolTCP.Options()`
- `NWEndpoint.Host(String)`, `NWEndpoint.Port(rawValue:)`, `NWEndpoint.Port(integerLiteral:)`, `NWEndpoint.hostPort(host:port:)`
- `NWConnection.State` cases, and `NWProtocolFramer.Instance` (7 uses in OngoingCallContext.swift)

## Minimum for Reachability

Only `NWPathMonitor` is needed for Reachability: `init()`, `pathUpdateHandler`, `start(queue:)`, `currentPath`, and on
`NWPath` the `status` value `.satisfied` and `usesInterfaceType(_:)`. The gap doc (`backports-gaps.md`, T18) records
that `usesInterfaceType` is an approximation from flags and interface names. It was written against an older line
number; the current definition is at `NWPathMonitor.swift:79`.

## Not in this page

Whether each member's behaviour matches the system's is the Network worker's question. The surface above is what
that check must cover, and TLS (`RustStreamHost.swift`, `.tls`) is also covered by `docs/explanation/backports/tls-reach-ios-6.md`.
