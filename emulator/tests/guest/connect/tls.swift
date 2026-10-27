import Dispatch
import Foundation
import Network
import Security

final class Locked<Value> {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withValue<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

struct Handshake {
    let state: String
    let milliseconds: Double
    let connection: NWConnection
}

func milliseconds(since start: DispatchTime) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
}

func format(_ milliseconds: Double) -> String {
    String(format: "%.1fms", milliseconds)
}

func handshake(host: String, maximum: tls_protocol_version_t) -> Handshake {
    let tls = NWProtocolTLS.Options()
    sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, host)
    sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, tls_protocol_version_t.TLSv12)
    sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, maximum)
    let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: 443)!,
                                  using: NWParameters(tls: tls, tcp: NWProtocolTCP.Options()))
    let state = Locked("timeout")
    let elapsed = Locked(0.0)
    let settled = DispatchSemaphore(value: 0)
    let start = DispatchTime.now()
    connection.stateUpdateHandler = { update in
        switch update {
        case .ready:
            state.withValue { $0 = "ready" }
            elapsed.withValue { $0 = milliseconds(since: start) }
            settled.signal()
        case .failed(let error):
            state.withValue { $0 = "failed \(error.debugDescription)" }
            elapsed.withValue { $0 = milliseconds(since: start) }
            settled.signal()
        case .waiting(let error):
            state.withValue { $0 = "waiting \(error.debugDescription)" }
            elapsed.withValue { $0 = milliseconds(since: start) }
            settled.signal()
        default:
            break
        }
    }
    connection.start(queue: DispatchQueue(label: "revenant.tls.probe.handshake"))
    _ = settled.wait(timeout: .now() + 30)
    return Handshake(state: state.withValue { $0 }, milliseconds: elapsed.withValue { $0 }, connection: connection)
}

func fetch(_ connection: NWConnection, host: String) -> String {
    let request = "GET / HTTP/1.1\r\nHost: \(host)\r\nConnection: close\r\n\r\n"
    let received = Locked("none")
    let done = DispatchSemaphore(value: 0)
    connection.send(content: Data(request.utf8), completion: .contentProcessed { _ in })
    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
        if let data {
            let text = String(decoding: data, as: UTF8.self)
            received.withValue { $0 = String(text.prefix { $0 != "\r" && $0 != "\n" }) }
        }
        done.signal()
    }
    _ = done.wait(timeout: .now() + 30)
    connection.cancel()
    return received.withValue { $0 }
}

func system(host: String) -> String {
    let start = DispatchTime.now()
    var response: URLResponse?
    do {
        _ = try NSURLConnection.sendSynchronousRequest(URLRequest(url: URL(string: "https://\(host)/")!), returning: &response)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return "\(status) \(format(milliseconds(since: start)))"
    } catch {
        return "failed \(error.localizedDescription) \(format(milliseconds(since: start)))"
    }
}

let hosts = [
    "www.apple.com",
    "www.google.com",
    "www.cloudflare.com",
    "tls13.cloudflare.com",
    "web.telegram.org",
    "api.telegram.org",
    "github.com",
    "letsencrypt.org",
    "example.com",
    "tls-v1-2.badssl.com",
]

@main
enum TLSProbe {
    static func main() {
        setvbuf(stdout, nil, _IONBF, 0)
        for host in hosts {
            let tls12 = handshake(host: host, maximum: tls_protocol_version_t.TLSv12)
            tls12.connection.cancel()
            print("tls_backport \(host) tls12 \(tls12.state) \(format(tls12.milliseconds))")
            let tls13 = handshake(host: host, maximum: tls_protocol_version_t.TLSv13)
            print("tls_backport \(host) tls13 \(tls13.state) \(format(tls13.milliseconds))")
            if tls13.state == "ready" {
                print("tls_backport \(host) get \(fetch(tls13.connection, host: host))")
            } else {
                tls13.connection.cancel()
                print("tls_backport \(host) get none")
            }
            print("tls_backport \(host) system \(system(host: host))")
        }
        print("tls_backport \(hosts.count) hosts done")
    }
}
