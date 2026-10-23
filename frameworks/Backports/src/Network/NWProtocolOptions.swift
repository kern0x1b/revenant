import Darwin
import Foundation

public final class NWProtocolStack: @unchecked Sendable {
    public var applicationProtocols: [NWProtocolFramer.Options] = []

    public init() {}
}

public enum NWProtocolTCP {
    public final class Options: @unchecked Sendable {
        public var noDelay = false
        public var enableKeepalive = false
        public var keepaliveIdle = 0
        public var keepaliveCount = 0
        public var keepaliveInterval = 0
        public var enableFastOpen = false

        public init() {}

        func apply(to descriptor: Int32) {
            var on: Int32 = 1
            let size = socklen_t(MemoryLayout<Int32>.size)
            if noDelay {
                setsockopt(descriptor, IPPROTO_TCP, TCP_NODELAY, &on, size)
            }
            if enableKeepalive {
                setsockopt(descriptor, SOL_SOCKET, SO_KEEPALIVE, &on, size)
                if keepaliveIdle > 0 {
                    var idle = Int32(keepaliveIdle)
                    setsockopt(descriptor, IPPROTO_TCP, TCP_KEEPALIVE, &idle, size)
                }
                if keepaliveCount > 0 {
                    var count = Int32(keepaliveCount)
                    setsockopt(descriptor, IPPROTO_TCP, TCP_KEEPCNT, &count, size)
                }
                if keepaliveInterval > 0 {
                    var interval = Int32(keepaliveInterval)
                    setsockopt(descriptor, IPPROTO_TCP, TCP_KEEPINTVL, &interval, size)
                }
            }
            if enableFastOpen {
                setsockopt(descriptor, IPPROTO_TCP, TCP_FASTOPEN, &on, size)
            }
        }
    }
}
