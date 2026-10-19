// The port half of the NWInterface differential: the same lines, for the interfaces this tree's C monitor reports.
import Network

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

report("all", _testFirstPathInterfaces(nil))
for kind in [NWInterface.InterfaceType.loopback, .wifi, .cellular, .wiredEthernet, .other] {
    report("required \(kind)", _testFirstPathInterfaces(kind))
}
