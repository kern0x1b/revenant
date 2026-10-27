import Foundation
import Dispatch
import SystemConfiguration
import _Concurrency

public struct NWPath: Equatable, CustomDebugStringConvertible {
    public enum Status: Equatable, CustomDebugStringConvertible {
        case satisfied
        case unsatisfied
        case requiresConnection

        public var debugDescription: String {
            switch self {
            case .satisfied:
                return "satisfied"
            case .unsatisfied:
                return "unsatisfied"
            case .requiresConnection:
                return "requiresConnection"
            }
        }
    }

    public enum UnsatisfiedReason: Equatable, CustomDebugStringConvertible {
        case notAvailable
        case cellularDenied
        case wifiDenied
        case localNetworkDenied
        case vpnInactive

        public var debugDescription: String {
            switch self {
            case .notAvailable:
                return "notAvailable"
            case .cellularDenied:
                return "cellularDenied"
            case .wifiDenied:
                return "wifiDenied"
            case .localNetworkDenied:
                return "localNetworkDenied"
            case .vpnInactive:
                return "vpnInactive"
            }
        }
    }

    public let status: Status
    public let unsatisfiedReason: UnsatisfiedReason
    public let availableInterfaces: [NWInterface]
    public let isExpensive: Bool
    public var isConstrained: Bool {
        false
    }
    public let supportsIPv4: Bool
    public let supportsIPv6: Bool
    public let supportsDNS: Bool
    public let gateways: [NWEndpoint]
    public var localEndpoint: NWEndpoint? {
        nil
    }
    public var remoteEndpoint: NWEndpoint? {
        nil
    }
    private let usedInterfaceType: NWInterface.InterfaceType?

    init(status: Status, isExpensive: Bool, availableInterfaces: [NWInterface], usedInterfaceType: NWInterface.InterfaceType? = nil,
         supportsIPv4: Bool = false, supportsIPv6: Bool = false, supportsDNS: Bool = false, gateways: [NWEndpoint] = []) {
        self.status = status
        self.unsatisfiedReason = .notAvailable
        self.availableInterfaces = availableInterfaces
        self.isExpensive = isExpensive
        self.supportsIPv4 = supportsIPv4
        self.supportsIPv6 = supportsIPv6
        self.supportsDNS = supportsDNS
        self.gateways = gateways
        self.usedInterfaceType = usedInterfaceType ?? NWPath.primaryInterfaceType(status: status, isExpensive: isExpensive, availableInterfaces: availableInterfaces)
    }

    public func usesInterfaceType(_ type: NWInterface.InterfaceType) -> Bool {
        usedInterfaceType == type
    }

    private static func primaryInterfaceType(status: Status, isExpensive: Bool, availableInterfaces: [NWInterface]) -> NWInterface.InterfaceType? {
        guard status != .unsatisfied else {
            return nil
        }
        if isExpensive {
            return .cellular
        }
        for type in [NWInterface.InterfaceType.wifi, .wiredEthernet, .loopback, .other] where availableInterfaces.contains(where: { $0.type == type }) {
            return type
        }
        return nil
    }

    public var debugDescription: String {
        "status: \(status.debugDescription), isExpensive: \(isExpensive), interfaces: \(availableInterfaces.map { $0.name }.joined(separator: ", "))"
    }
}

struct PathFilter {
    let required: NWInterface.InterfaceType?
    let prohibited: [NWInterface.InterfaceType]

    func allows(_ interface: NWInterface) -> Bool {
        if let required = required, interface.type != required {
            return false
        }
        return !prohibited.contains(interface.type)
    }
}

private struct LocalInterface {
    let interface: NWInterface
    let hasIPv4: Bool
    let hasIPv6: Bool
}

private func isGlobalIPv6(_ address: UnsafePointer<sockaddr>) -> Bool {
    address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer in
        withUnsafeBytes(of: pointer.pointee.sin6_addr) { bytes in
            let linkLocal = bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80
            let unspecifiedOrLoopback = bytes.prefix(15).allSatisfy { $0 == 0 } && bytes[15] <= 1
            return !linkLocal && !unspecifiedOrLoopback
        }
    }
}

private func revenantLocalInterfaces() -> [LocalInterface] {
    var list: UnsafeMutablePointer<ifaddrs>? = nil
    guard getifaddrs(&list) == 0, let first = list else {
        return []
    }
    defer {
        freeifaddrs(list)
    }
    var names: [String] = []
    var kernelTypes: [String: UInt8] = [:]
    var ipv4: Set<String> = []
    var ipv6: Set<String> = []
    var entry: UnsafeMutablePointer<ifaddrs>? = first
    while let current = entry {
        let name = String(cString: current.pointee.ifa_name)
        let flags = Int32(current.pointee.ifa_flags)
        if let address = current.pointee.ifa_addr, let data = current.pointee.ifa_data, address.pointee.sa_family == UInt8(AF_LINK) {
            kernelTypes[name] = data.assumingMemoryBound(to: if_data.self).pointee.ifi_type
        }
        if flags & IFF_UP != 0, let address = current.pointee.ifa_addr {
            switch Int32(address.pointee.sa_family) {
            case AF_INET:
                ipv4.insert(name)
            case AF_INET6 where isGlobalIPv6(address):
                ipv6.insert(name)
            default:
                break
            }
            if !names.contains(name) && (ipv4.contains(name) || ipv6.contains(name)) {
                names.append(name)
            }
        }
        entry = current.pointee.ifa_next
    }
    return names.compactMap { name -> LocalInterface? in
        guard let interface = NWInterface(named: name, kernelType: kernelTypes[name]), interface.type != .loopback else {
            return nil
        }
        return LocalInterface(interface: interface, hasIPv4: ipv4.contains(name), hasIPv6: ipv6.contains(name))
    }
}

private let routeHeaderSize = 92
private let routeFlagUp: Int32 = 0x1
private let routeFlagGateway: Int32 = 0x2

private struct DefaultRoute {
    let index: Int
    let family: Int32
    let host: NWEndpoint.Host
}

private func routeAddressLength(_ length: Int) -> Int {
    length > 0 ? ((length - 1) | 3) + 1 : 4
}

private func routeAddressIsZero(_ raw: UnsafeRawBufferPointer, at start: Int, family: Int32) -> Bool {
    switch family {
    case AF_INET:
        return (0..<4).allSatisfy { raw[start + 4 + $0] == 0 }
    case AF_INET6:
        return (0..<16).allSatisfy { raw[start + 8 + $0] == 0 }
    default:
        return false
    }
}

private func routeGateway(_ raw: UnsafeRawBufferPointer, at start: Int, family: Int32, index: Int) -> NWEndpoint.Host? {
    switch family {
    case AF_INET:
        return IPv4Address(Data((0..<4).map { raw[start + 4 + $0] })).map { NWEndpoint.Host.ipv4($0) }
    case AF_INET6:
        let bytes = Data((0..<16).map { raw[start + 8 + $0] })
        let interface = revenantLocalInterfaces().first { $0.interface.index == index }?.interface
        return IPv6Address(bytes, interface).map { NWEndpoint.Host.ipv6($0) }
    default:
        return nil
    }
}

private func revenantDefaultRoutes() -> [DefaultRoute] {
    var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_DUMP, 0]
    var length = 0
    guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else {
        return []
    }
    var buffer = [UInt8](repeating: 0, count: length)
    guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else {
        return []
    }
    let headerSize = routeHeaderSize
    var routes: [DefaultRoute] = []
    buffer.withUnsafeBytes { raw in
        var offset = 0
        while offset + headerSize <= length {
            let size = Int(raw.load(fromByteOffset: offset, as: UInt16.self))
            let index = Int(raw.load(fromByteOffset: offset + 4, as: UInt16.self))
            let flags = raw.load(fromByteOffset: offset + 8, as: Int32.self)
            let addresses = raw.load(fromByteOffset: offset + 12, as: Int32.self)
            guard size >= headerSize, offset + size <= length else {
                break
            }
            if flags & routeFlagUp != 0 && flags & routeFlagGateway != 0 {
                var cursor = offset + headerSize
                var destinationFamily: Int32?
                var destinationIsDefault = false
                var gateway: NWEndpoint.Host?
                for bit in 0..<8 where addresses & (1 << Int32(bit)) != 0 && cursor < offset + size {
                    let addressLength = Int(raw.load(fromByteOffset: cursor, as: UInt8.self))
                    let family = Int32(raw.load(fromByteOffset: cursor + 1, as: UInt8.self))
                    if bit == 0 {
                        destinationFamily = family
                        destinationIsDefault = addressLength == 0 || routeAddressIsZero(raw, at: cursor, family: family)
                    } else if bit == 1 {
                        gateway = routeGateway(raw, at: cursor, family: family, index: index)
                    }
                    cursor += routeAddressLength(addressLength)
                }
                if destinationIsDefault, let family = destinationFamily, let host = gateway {
                    routes.append(DefaultRoute(index: index, family: family, host: host))
                }
            }
            offset += size
        }
    }
    return routes
}

private typealias ResolverInit = @convention(c) (UnsafeMutableRawPointer) -> Int32
private typealias ResolverDestroy = @convention(c) (UnsafeMutableRawPointer) -> Void

private func revenantHasDNSServers() -> Bool {
    guard let library = dlopen("/usr/lib/libresolv.9.dylib", RTLD_NOW),
          let initSymbol = dlsym(library, "res_9_ninit"),
          let destroySymbol = dlsym(library, "res_9_ndestroy") else {
        return false
    }
    let resolverInit = unsafeBitCast(initSymbol, to: ResolverInit.self)
    let resolverDestroy = unsafeBitCast(destroySymbol, to: ResolverDestroy.self)
    let state = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: 16)
    defer { state.deallocate() }
    state.initializeMemory(as: UInt8.self, repeating: 0, count: 4096)
    guard resolverInit(state) == 0 else {
        return false
    }
    defer { resolverDestroy(state) }
    let nscountOffset = 2 * MemoryLayout<Int32>.size + MemoryLayout<UInt>.size
    return state.load(fromByteOffset: nscountOffset, as: Int32.self) > 0
}

private func revenantIsExpensive(_ flags: SCNetworkReachabilityFlags) -> Bool {
    #if os(iOS)
    return flags.contains(.isWWAN)
    #else
    return false
    #endif
}

private func revenantReachability() -> SCNetworkReachability? {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    return withUnsafePointer(to: &address) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            SCNetworkReachabilityCreateWithAddress(nil, socketAddress)
        }
    }
}

private func revenantPath(for flags: SCNetworkReachabilityFlags, filter: PathFilter) -> NWPath {
    let reachable: NWPath.Status
    if flags.contains(.reachable) {
        reachable = flags.contains(.connectionRequired) ? .requiresConnection : .satisfied
    } else {
        reachable = .unsatisfied
    }
    let local = reachable == .unsatisfied ? [] : revenantLocalInterfaces().filter { filter.allows($0.interface) }
    if reachable == .unsatisfied || (filter.required != nil && local.isEmpty) {
        return NWPath(status: .unsatisfied, isExpensive: false, availableInterfaces: [])
    }
    let interfaces = local.map { $0.interface }
    let defaults = revenantDefaultRoutes().filter { route in interfaces.contains { $0.index == route.index } }
    let primary = defaults.first { $0.family == AF_INET } ?? defaults.first
    let used = filter.required.flatMap { required in interfaces.first { $0.type == required } }
        ?? primary.flatMap { route in interfaces.first { $0.index == route.index } }
    let routes = used.map { interface in defaults.filter { $0.index == interface.index } } ?? []
    return NWPath(status: reachable, isExpensive: revenantIsExpensive(flags), availableInterfaces: interfaces,
                  usedInterfaceType: used?.type, supportsIPv4: routes.contains { $0.family == AF_INET },
                  supportsIPv6: routes.contains { $0.family == AF_INET6 }, supportsDNS: revenantHasDNSServers(),
                  gateways: routes.map { NWEndpoint.hostPort(host: $0.host, port: 0) })
}

func revenantCurrentPath() -> NWPath {
    guard let reachability = revenantReachability() else {
        return NWPath(status: .unsatisfied, isExpensive: false, availableInterfaces: [])
    }
    return revenantPath(for: revenantCurrentFlags(reachability), filter: PathFilter(required: nil, prohibited: []))
}

private final class PathCallbackBox {
    weak var monitor: NWPathMonitor?
    let generation: Int

    init(monitor: NWPathMonitor, generation: Int) {
        self.monitor = monitor
        self.generation = generation
    }
}

public final class NWPathMonitor {
    private let filter: PathFilter
    private let lock = NSLock()
    private var reachability: SCNetworkReachability?
    private var generation = 0
    private var monitorQueue: DispatchQueue?
    private var latest: NWPath?
    private var observers: [UUID: AsyncStream<NWPath>.Continuation] = [:]

    public var pathUpdateHandler: ((NWPath) -> Void)?

    public var queue: DispatchQueue? {
        lock.lock()
        defer {
            lock.unlock()
        }
        return monitorQueue
    }

    public init() {
        filter = PathFilter(required: nil, prohibited: [])
    }

    public init(requiredInterfaceType: NWInterface.InterfaceType) {
        filter = PathFilter(required: requiredInterfaceType, prohibited: [])
    }

    public init(prohibitedInterfaceTypes: [NWInterface.InterfaceType]) {
        filter = PathFilter(required: nil, prohibited: prohibitedInterfaceTypes)
    }

    deinit {
        cancel()
    }

    public var currentPath: NWPath {
        lock.lock()
        defer {
            lock.unlock()
        }
        return latest ?? NWPath(status: .unsatisfied, isExpensive: false, availableInterfaces: [])
    }

    public func start(queue: DispatchQueue) {
        lock.lock()
        guard reachability == nil, let reachability = revenantReachability() else {
            lock.unlock()
            return
        }
        generation += 1
        let box = PathCallbackBox(monitor: self, generation: generation)
        self.reachability = reachability
        self.monitorQueue = queue
        self.latest = nil
        lock.unlock()
        var context = SCNetworkReachabilityContext(version: 0, info: Unmanaged.passRetained(box).toOpaque(), retain: nil, release: { info in
            Unmanaged<PathCallbackBox>.fromOpaque(info).release()
        }, copyDescription: nil)
        SCNetworkReachabilitySetCallback(reachability, { _, flags, info in
            guard let info = info else {
                return
            }
            let box = Unmanaged<PathCallbackBox>.fromOpaque(info).takeUnretainedValue()
            box.monitor?.deliver(flags: flags, generation: box.generation)
        }, &context)
        SCNetworkReachabilitySetDispatchQueue(reachability, queue)
        queue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.lock.lock()
            let current = self.reachability
            self.lock.unlock()
            if let current = current {
                self.deliver(flags: revenantCurrentFlags(current), generation: box.generation)
            }
        }
    }

    public func cancel() {
        lock.lock()
        guard let reachability = reachability else {
            lock.unlock()
            return
        }
        self.reachability = nil
        generation += 1
        lock.unlock()
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
    }

    fileprivate func deliver(flags: SCNetworkReachabilityFlags, generation: Int) {
        lock.lock()
        let running = self.generation == generation && reachability != nil
        lock.unlock()
        guard running else {
            return
        }
        let path = revenantPath(for: flags, filter: filter)
        lock.lock()
        guard self.generation == generation, reachability != nil else {
            lock.unlock()
            return
        }
        let changed = latest != path
        latest = path
        let subscribers = Array(observers.values)
        lock.unlock()
        if changed {
            pathUpdateHandler?(path)
            subscribers.forEach { $0.yield(path) }
        }
    }

    fileprivate func updates() -> AsyncStream<NWPath> {
        AsyncStream { continuation in
            let identifier = UUID()
            lock.lock()
            observers[identifier] = continuation
            let current = latest
            let running = reachability != nil
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.observers[identifier] = nil
                self?.lock.unlock()
            }
            if let current = current {
                continuation.yield(current)
            }
            if !running {
                start(queue: DispatchQueue(label: "revenant.network.path.updates"))
            }
        }
    }
}

extension NWPathMonitor: AsyncSequence {
    public typealias Element = NWPath
    public typealias AsyncIterator = Iterator

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = NWPath

        private var updates: AsyncStream<NWPath>.Iterator

        fileprivate init(updates: AsyncStream<NWPath>.Iterator) {
            self.updates = updates
        }

        public mutating func next() async -> NWPath? {
            await updates.next()
        }
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(updates: updates().makeAsyncIterator())
    }
}

private func revenantCurrentFlags(_ reachability: SCNetworkReachability) -> SCNetworkReachabilityFlags {
    var flags: SCNetworkReachabilityFlags = []
    _ = SCNetworkReachabilityGetFlags(reachability, &flags)
    return flags
}
