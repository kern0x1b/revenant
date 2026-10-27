#if !REVENANT_BACKPORT
import Network
#endif
import Foundation
import Dispatch

func endpointText(_ endpoint: NWEndpoint) -> String {
    switch endpoint {
    case .hostPort(let host, let port):
        return "hostPort \(host) \(port)"
    default:
        return "other"
    }
}

func describe(_ path: NWPath) -> [String] {
    var lines: [String] = []
    lines.append("status \(path.status)")
    lines.append("expensive \(path.isExpensive)")
    lines.append("constrained \(path.isConstrained)")
    lines.append("ipv4 \(path.supportsIPv4) ipv6 \(path.supportsIPv6) dns \(path.supportsDNS)")
    let interfaces = path.availableInterfaces.map { "\($0.name)/\($0.index)/\($0.type)" }.sorted()
    lines.append("interfaces \(interfaces.joined(separator: " "))")
    let gateways = path.gateways.map(endpointText).sorted()
    lines.append("gateways \(gateways.joined(separator: " "))")
    lines.append("local \(path.localEndpoint.map(endpointText) ?? "nil") remote \(path.remoteEndpoint.map(endpointText) ?? "nil")")
    let types: [NWInterface.InterfaceType] = [.wifi, .cellular, .wiredEthernet, .loopback, .other]
    lines.append("uses " + types.map { "\($0)=\(path.usesInterfaceType($0))" }.joined(separator: " "))
    return lines
}

let marker = DispatchSpecificKey<Int>()
let queue = DispatchQueue(label: "revenant.network.paths")
queue.setSpecific(key: marker, value: 7)

let monitor = NWPathMonitor()
print("before start current:")
for line in describe(monitor.currentPath) {
    print("  \(line)")
}

let lock = NSLock()
var delivered: [NWPath] = []
var offQueue = 0
let first = DispatchSemaphore(value: 0)
monitor.pathUpdateHandler = { path in
    if DispatchQueue.getSpecific(key: marker) != 7 {
        lock.lock()
        offQueue += 1
        lock.unlock()
    }
    lock.lock()
    delivered.append(path)
    lock.unlock()
    first.signal()
}
monitor.start(queue: queue)
print("queue specific on monitor.queue: \(monitor.queue?.getSpecific(key: marker) == 7)")
guard first.wait(timeout: .now() + 10) == .success else {
    print("FAIL no path update arrived")
    exit(1)
}
monitor.cancel()
queue.sync {}
lock.lock()
let seen = delivered.count
let fromQueue = offQueue
let path = delivered[0]
lock.unlock()
Thread.sleep(forTimeInterval: 1)
queue.sync {}
lock.lock()
let after = delivered.count
lock.unlock()

print("updates before cancel: \(seen)")
print("updates after cancel: \(after - seen)")
print("handler off the given queue: \(fromQueue)")
print("monitor.queue after cancel is nil: \(monitor.queue == nil)")
for line in describe(path) {
    print("  \(line)")
}

let immediate = NWPathMonitor()
let immediateQueue = DispatchQueue(label: "revenant.network.paths.immediate")
let immediateFirst = DispatchSemaphore(value: 0)
immediate.pathUpdateHandler = { _ in
    immediateFirst.signal()
}
immediate.start(queue: immediateQueue)
print("right after start status: \(immediate.currentPath.status)")
_ = immediateFirst.wait(timeout: .now() + 10)
immediate.cancel()

for (label, monitor) in [
    ("required wifi", NWPathMonitor(requiredInterfaceType: .wifi)),
    ("required wiredEthernet", NWPathMonitor(requiredInterfaceType: .wiredEthernet)),
    ("prohibited wifi", NWPathMonitor(prohibitedInterfaceTypes: [.wifi])),
] {
    let filtered = DispatchQueue(label: "revenant.network.paths.filtered")
    let got = DispatchSemaphore(value: 0)
    var result: NWPath?
    let filterLock = NSLock()
    monitor.pathUpdateHandler = { path in
        filterLock.lock()
        if result == nil {
            result = path
            got.signal()
        }
        filterLock.unlock()
    }
    monitor.start(queue: filtered)
    _ = got.wait(timeout: .now() + 10)
    monitor.cancel()
    print(label)
    for line in describe(result ?? monitor.currentPath) {
        print("  \(line)")
    }
}
