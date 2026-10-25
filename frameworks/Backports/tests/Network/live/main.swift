import Foundation
import Dispatch

let types: [NWInterface.InterfaceType] = [.wifi, .cellular, .wiredEthernet, .loopback, .other]
let physical: [NWInterface.InterfaceType] = [.wifi, .wiredEthernet, .loopback, .other]
let queue = DispatchQueue(label: "revenant.network.live")
let monitor = NWPathMonitor()
let first = DispatchSemaphore(value: 0)
var current: NWPath?
monitor.pathUpdateHandler = { path in
    if current == nil {
        current = path
        first.signal()
    }
}
monitor.start(queue: queue)
guard first.wait(timeout: .now() + 10) == .success, let path = current else {
    print("FAIL no path update arrived")
    exit(1)
}
monitor.cancel()

let used = types.filter { path.usesInterfaceType($0) }
var failures: [String] = []
if used.count > 1 {
    failures.append("more than one type is used: \(used)")
}
if path.status == .unsatisfied && !used.isEmpty {
    failures.append("an unsatisfied path uses \(used)")
}
for type in used where type != .cellular && !path.availableInterfaces.contains(where: { $0.type == type }) {
    failures.append("\(type) is used without an interface of that type")
}
if path.status == .satisfied && path.availableInterfaces.contains(where: { physical.contains($0.type) }) && used.isEmpty {
    failures.append("a satisfied path with a wifi, wired, loopback or other interface uses none")
}
if !failures.isEmpty {
    for line in failures {
        print("FAIL \(line)")
    }
    exit(1)
}
print("live invariants ok")
