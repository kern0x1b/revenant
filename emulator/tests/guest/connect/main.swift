import Dispatch
import Foundation

setvbuf(stdout, nil, _IONBF, 0)
let rounds = 20
let count = 32
let queue = DispatchQueue(label: "revenant.connect.backport")

for round in 0..<rounds {
    var states = [String](repeating: "pending", count: count)
    var connections: [NWConnection] = []
    let settled = DispatchSemaphore(value: 0)
    for index in 0..<count {
        let connection = NWConnection(host: NWEndpoint.Host("104.16.124.96"), port: NWEndpoint.Port(rawValue: 443)!, using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                states[index] = "ready"
                settled.signal()
            case .failed(let error), .waiting(let error):
                states[index] = "failed \(error.debugDescription)"
                settled.signal()
            default:
                break
            }
        }
        connections.append(connection)
    }
    for connection in connections {
        connection.start(queue: queue)
    }
    let deadline = DispatchTime.now() + .seconds(5)
    var reported = 0
    while reported < count {
        if settled.wait(timeout: deadline) != .success {
            break
        }
        reported += 1
    }
    let ready = queue.sync { states.filter { $0 == "ready" }.count }
    for (index, state) in queue.sync(execute: { states }).enumerated() where state != "ready" {
        print("connect_backport round \(round) connection \(index) \(state)")
    }
    print("connect_backport round \(round) \(ready) of \(count) ready")
    for connection in connections {
        connection.cancel()
    }
}
print("connect_backport \(rounds) rounds done")
