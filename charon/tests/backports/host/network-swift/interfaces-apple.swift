import Network
import Dispatch

func firstPath(_ required: NWInterface.InterfaceType?) -> NWPath {
    let monitor = required.map { NWPathMonitor(requiredInterfaceType: $0.nwType) } ?? NWPathMonitor()
    let semaphore = DispatchSemaphore(value: 0)
    var first: NWPath?
    monitor.pathUpdateHandler = { path in
        if first == nil {
            first = path
            semaphore.signal()
        }
    }
    monitor.start(queue: DispatchQueue(label: "nwinterface.differential"))
    _ = semaphore.wait(timeout: .now() + 10)
    monitor.cancel()
    return first!
}

extension NWInterface.InterfaceType {
    var nwType: NWInterface.InterfaceType { self }
}

func report(_ scenario: String, _ interfaces: [NWInterface]) {
    print("scenario\tstr:\(scenario)")
    print("count\t\(interfaces.count)")
    for (position, interface) in interfaces.enumerated() {
        print("name.\(position)\tstr:\(interface.name)")
        print("index.\(position)\t\(interface.index)")
        print("type.\(position)\tstr:\(interface.type)")
        print("debug.\(position)\tstr:\(interface.debugDescription)")
        print("self.\(position)\t\(interface == interface)")
    }
    if interfaces.count >= 2 {
        print("equal.0.1\t\(interfaces[0] == interfaces[1])")
    }
}

report("all", firstPath(nil).availableInterfaces)
for kind in [NWInterface.InterfaceType.loopback, .wifi, .cellular, .wiredEthernet, .other] {
    report("required \(kind)", firstPath(kind).availableInterfaces)
}
