// Test-only, built into the port's module for the differential and into no shipped module: the interfaces of the first path the
// C monitor reports, read through the same calls the backports answer with, as NWInterface values. A required type is passed
// as the InterfaceType the test names, and maps to the C type of the same meaning.
import Dispatch

func cInterfaceType(_ kind: NWInterface.InterfaceType) -> nw_interface_type_t {
    switch kind {
    case .wifi:
        return nw_interface_type_wifi
    case .cellular:
        return nw_interface_type_cellular
    case .wiredEthernet:
        return nw_interface_type_wired
    case .loopback:
        return nw_interface_type_loopback
    case .other:
        return nw_interface_type_other
    }
}

public func _testFirstPathInterfaces(_ required: NWInterface.InterfaceType?) -> [NWInterface] {
    let monitor = required.map { nw_path_monitor_create_with_type(cInterfaceType($0)) } ?? nw_path_monitor_create()
    let queue = DispatchQueue(label: "nwinterface.helper")
    let semaphore = DispatchSemaphore(value: 0)
    var found: [NWInterface]?
    nw_path_monitor_set_queue(monitor, queue)
    nw_path_monitor_set_update_handler(monitor) { path in
        if found == nil {
            var list: [NWInterface] = []
            nw_path_enumerate_interfaces(path) { interface in
                list.append(NWInterface(interface))
                return true
            }
            found = list
            semaphore.signal()
        }
    }
    nw_path_monitor_start(monitor)
    _ = semaphore.wait(timeout: .now() + 10)
    nw_path_monitor_cancel(monitor)
    return found ?? []
}

// The zone lookup the address types read (Foundation/NWPathMonitor.m, charon_interface_named), for the host: the interface of
// the first path that has the name, nil when the path has none. The seam of the device is the C function; the test's module
// defines it here so the port's address types read the same name the host's monitor lists.
@_cdecl("charon_interface_named")
public func _testInterfaceNamed(_ name: UnsafePointer<CChar>) -> nw_interface_t? {
    let wanted = String(cString: name)
    return _testFirstPathInterfaces(nil).first { $0.name == wanted }?.interface
}
