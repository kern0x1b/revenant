import Foundation
import SystemConfiguration

public final class NWPath: Equatable, CustomDebugStringConvertible {
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

    public let status: Status
    public let isExpensive: Bool
    public let availableInterfaces: [NWInterface]
    let defaultInterface: NWInterface?
    private let usedInterfaceType: NWInterface.InterfaceType?

    init(status: Status, isExpensive: Bool, availableInterfaces: [NWInterface], defaultInterface: NWInterface?) {
        self.status = status
        self.isExpensive = isExpensive
        self.availableInterfaces = availableInterfaces
        self.defaultInterface = defaultInterface
        self.usedInterfaceType = NWPath.primaryInterfaceType(status: status, isExpensive: isExpensive, defaultInterface: defaultInterface)
    }

    public func usesInterfaceType(_ type: NWInterface.InterfaceType) -> Bool {
        usedInterfaceType == type
    }

    private static func primaryInterfaceType(status: Status, isExpensive: Bool, defaultInterface: NWInterface?) -> NWInterface.InterfaceType? {
        guard status != .unsatisfied else {
            return nil
        }
        if let type = defaultInterface?.type {
            return type
        }
        return isExpensive ? .cellular : nil
    }

    public static func == (lhs: NWPath, rhs: NWPath) -> Bool {
        lhs.status == rhs.status && lhs.isExpensive == rhs.isExpensive && lhs.availableInterfaces == rhs.availableInterfaces
    }

    public var debugDescription: String {
        "status: \(status.debugDescription), isExpensive: \(isExpensive), interfaces: \(availableInterfaces.map { $0.name }.joined(separator: ", "))"
    }
}

private func revenantAvailableInterfaces() -> [NWInterface] {
    var list: UnsafeMutablePointer<ifaddrs>? = nil
    guard getifaddrs(&list) == 0, let first = list else {
        return []
    }
    defer {
        freeifaddrs(list)
    }
    var names: [String] = []
    var kernelTypes: [String: UInt8] = [:]
    var entry: UnsafeMutablePointer<ifaddrs>? = first
    while let current = entry {
        let flags = Int32(current.pointee.ifa_flags)
        if let address = current.pointee.ifa_addr, let data = current.pointee.ifa_data, address.pointee.sa_family == UInt8(AF_LINK) {
            kernelTypes[String(cString: current.pointee.ifa_name)] = data.assumingMemoryBound(to: if_data.self).pointee.ifi_type
        }
        if flags & IFF_UP != 0, let address = current.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) || address.pointee.sa_family == UInt8(AF_INET6) {
            let name = String(cString: current.pointee.ifa_name)
            if !names.contains(name) {
                names.append(name)
            }
        }
        entry = current.pointee.ifa_next
    }
    return names.compactMap { NWInterface(named: $0, kernelType: kernelTypes[$0]) }.filter { $0.type != .loopback }
}

private func revenantDefaultRouteSource() -> in_addr_t? {
    let descriptor = socket(AF_INET, SOCK_DGRAM, 0)
    guard descriptor >= 0 else {
        return nil
    }
    defer {
        close(descriptor)
    }
    var peer = sockaddr_in()
    peer.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    peer.sin_family = sa_family_t(AF_INET)
    peer.sin_port = UInt16(9).bigEndian
    peer.sin_addr.s_addr = inet_addr("192.0.2.1")
    let connected = withUnsafePointer(to: &peer) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            connect(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard connected == 0 else {
        return nil
    }
    var local = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let named = withUnsafeMutablePointer(to: &local) { pointer in
        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
            getsockname(descriptor, socketAddress, &length)
        }
    }
    guard named == 0, local.sin_addr.s_addr != 0 else {
        return nil
    }
    return local.sin_addr.s_addr
}

private func revenantDefaultInterface(in interfaces: [NWInterface]) -> NWInterface? {
    guard let source = revenantDefaultRouteSource() else {
        return nil
    }
    var list: UnsafeMutablePointer<ifaddrs>? = nil
    guard getifaddrs(&list) == 0, let first = list else {
        return nil
    }
    defer {
        freeifaddrs(list)
    }
    var name: String?
    var entry: UnsafeMutablePointer<ifaddrs>? = first
    while let current = entry, name == nil {
        if let address = current.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) {
            let inet = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            if inet.sin_addr.s_addr == source {
                name = String(cString: current.pointee.ifa_name)
            }
        }
        entry = current.pointee.ifa_next
    }
    return interfaces.first { $0.name == name }
}

private func revenantPath(for flags: SCNetworkReachabilityFlags) -> NWPath {
    let status: NWPath.Status
    if flags.contains(.reachable) {
        status = flags.contains(.connectionRequired) ? .requiresConnection : .satisfied
    } else {
        status = .unsatisfied
    }
    let interfaces = status == .unsatisfied ? [] : revenantAvailableInterfaces()
    let defaultInterface = status == .unsatisfied ? nil : revenantDefaultInterface(in: interfaces)
    return NWPath(status: status, isExpensive: revenantIsExpensive(flags), availableInterfaces: interfaces, defaultInterface: defaultInterface)
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

private func revenantCurrentFlags(_ reachability: SCNetworkReachability) -> SCNetworkReachabilityFlags {
    var flags: SCNetworkReachabilityFlags = []
    _ = SCNetworkReachabilityGetFlags(reachability, &flags)
    return flags
}

func revenantCurrentPath() -> NWPath {
    guard let reachability = revenantReachability() else {
        return NWPath(status: .unsatisfied, isExpensive: false, availableInterfaces: [], defaultInterface: nil)
    }
    return revenantPath(for: revenantCurrentFlags(reachability))
}

public final class NWPathMonitor {
    private let requiredInterfaceType: NWInterface.InterfaceType?
    private var reachability: SCNetworkReachability?
    private var queue: DispatchQueue?
    private var started = false

    public var pathUpdateHandler: ((NWPath) -> Void)?

    public init() {
        requiredInterfaceType = nil
    }

    public init(requiredInterfaceType: NWInterface.InterfaceType) {
        self.requiredInterfaceType = requiredInterfaceType
    }

    public var currentPath: NWPath {
        revenantCurrentPath()
    }

    public func start(queue: DispatchQueue) {
        guard !started, let reachability = revenantReachability() else {
            return
        }
        started = true
        self.queue = queue
        self.reachability = reachability
        var context = SCNetworkReachabilityContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        SCNetworkReachabilitySetCallback(reachability, { _, flags, info in
            guard let info = info else {
                return
            }
            let monitor = Unmanaged<NWPathMonitor>.fromOpaque(info).takeUnretainedValue()
            monitor.pathUpdateHandler?(revenantPath(for: flags))
        }, &context)
        SCNetworkReachabilitySetDispatchQueue(reachability, queue)
        queue.async { [weak self] in
            guard let self = self, self.started, let reachability = self.reachability else {
                return
            }
            self.pathUpdateHandler?(revenantPath(for: revenantCurrentFlags(reachability)))
        }
    }

    public func cancel() {
        guard started, let reachability = reachability else {
            return
        }
        started = false
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        self.reachability = nil
        self.queue = nil
    }
}
