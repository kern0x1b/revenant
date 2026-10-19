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

@_cdecl("revenant_interface_named")
public func _testInterfaceNamed(_ name: UnsafePointer<CChar>) -> nw_interface_t? {
    let wanted = String(cString: name)
    return _testFirstPathInterfaces(nil).first { $0.name == wanted }?.interface
}
