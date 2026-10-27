import Foundation

struct Case {
    let name: String
    let status: NWPath.Status
    let expensive: Bool
    let interfaces: [NWInterface]
    let uses: [NWInterface.InterfaceType]
}

let types: [NWInterface.InterfaceType] = [.wifi, .cellular, .wiredEthernet, .loopback, .other]
let wifi = NWInterface(name: "en0", index: 14, type: .wifi)
let loopback = NWInterface(name: "lo0", index: 1, type: .loopback)
let cellular = NWInterface(name: "pdp_ip0", index: 5, type: .cellular)
let wired = NWInterface(name: "en1", index: 6, type: .wiredEthernet)
let tunnel = NWInterface(name: "utun0", index: 9, type: .other)

let cases: [Case] = [
    Case(name: "recorded on the host: satisfied, wifi en0 listed twice", status: .satisfied, expensive: false,
         interfaces: [wifi, wifi], uses: [.wifi]),
    Case(name: "unsatisfied uses no interface", status: .unsatisfied, expensive: false, interfaces: [], uses: []),
    Case(name: "loopback only", status: .satisfied, expensive: false, interfaces: [loopback], uses: [.loopback]),
    Case(name: "cellular while expensive", status: .satisfied, expensive: true, interfaces: [cellular], uses: [.cellular]),
    Case(name: "wired ethernet", status: .satisfied, expensive: false, interfaces: [wired], uses: [.wiredEthernet]),
    Case(name: "tunnel", status: .satisfied, expensive: false, interfaces: [tunnel], uses: [.other]),
]

var failures = 0
for entry in cases {
    let path = NWPath(status: entry.status, isExpensive: entry.expensive, availableInterfaces: entry.interfaces)
    if path.status != entry.status {
        failures += 1
        print("FAIL \(entry.name): status is \(path.status), expected \(entry.status)")
    }
    for type in types {
        let expected = entry.uses.contains(type)
        if path.usesInterfaceType(type) != expected {
            failures += 1
            print("FAIL \(entry.name): usesInterfaceType(\(type)) is \(!expected), expected \(expected)")
        }
    }
}
if failures > 0 {
    exit(1)
}
print("mapping ok \(cases.count) cases")
