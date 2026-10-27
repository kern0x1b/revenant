#if !REVENANT_BACKPORT
import Network
#endif
import Foundation
import Dispatch

final class PathMonitorUse {
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private(set) var gateways: [String] = []
    private(set) var hasPath = false
    private(set) var networkType = 0

    init(queue: DispatchQueue) {
        self.queue = queue
        self.monitor = NWPathMonitor()
        self.monitor.pathUpdateHandler = { [weak self] path in
            guard let strongSelf = self else {
                return
            }
            let networkType: Int
            if path.status == .satisfied {
                networkType = path.usesInterfaceType(.cellular) ? 2 : 1
            } else {
                networkType = 0
            }
            strongSelf.networkType = networkType
            let interface = path.availableInterfaces.first?.name ?? "gateway"
            strongSelf.gateways = path.gateways.compactMap { gateway in
                guard case let .hostPort(host, _) = gateway else {
                    return nil
                }
                return "\(interface) \(host)"
            }
            strongSelf.hasPath = true
        }
        self.monitor.start(queue: self.queue)
        _ = self.monitor.currentPath.isExpensive
    }

    deinit {
        self.monitor.cancel()
    }
}

let watch = PathMonitorUse(queue: DispatchQueue(label: "revenant.network.telegram"))
Thread.sleep(forTimeInterval: 1)
print("telegram usage ok: \(watch.hasPath) \(watch.networkType)")
