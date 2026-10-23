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

    init(status: Status, isExpensive: Bool, availableInterfaces: [NWInterface]) {
        self.status = status
        self.isExpensive = isExpensive
        self.availableInterfaces = availableInterfaces
    }

    public static func == (lhs: NWPath, rhs: NWPath) -> Bool {
        lhs.status == rhs.status && lhs.isExpensive == rhs.isExpensive && lhs.availableInterfaces == rhs.availableInterfaces
    }

    public var debugDescription: String {
        "status: \(status.debugDescription), isExpensive: \(isExpensive), interfaces: \(availableInterfaces.map { $0.name }.joined(separator: ", "))"
    }

    public func usesInterfaceType(_ type: NWInterface.InterfaceType) -> Bool {
        availableInterfaces.contains { $0.type == type }
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

func revenantInterfaceTypes(_ flags: SCNetworkReachabilityFlags) -> [NWInterface.InterfaceType] {
    guard flags.contains(.reachable) else {
        return []
    }
    if flags.contains(.isLocalAddress) {
        return [.loopback]
    }
    #if os(iOS)
    return flags.contains(.isWWAN) ? [.cellular] : [.wifi]
    #else
    return [.wifi]
    #endif
}

func revenantPath(for flags: SCNetworkReachabilityFlags) -> NWPath {
    let status: NWPath.Status
    if flags.contains(.reachable) {
        status = flags.contains(.connectionRequired) ? .requiresConnection : .satisfied
    } else {
        status = .unsatisfied
    }
    let types = revenantInterfaceTypes(flags)
    let interfaces: [NWInterface] = types.isEmpty ? [] : revenantAvailableInterfaces().filter { types.contains($0.type) }
    return NWPath(status: status, isExpensive: revenantIsExpensive(flags), availableInterfaces: interfaces)
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
        guard let reachability = revenantReachability() else {
            return NWPath(status: .unsatisfied, isExpensive: false, availableInterfaces: [])
        }
        return revenantPath(for: revenantCurrentFlags(reachability))
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
