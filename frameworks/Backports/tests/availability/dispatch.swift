@preconcurrency import Dispatch

final class Worker: @unchecked Sendable {
    let queue = DispatchQueue(label: "probe", attributes: .concurrent)
    let group = DispatchGroup()
    func run(_ work: @escaping @Sendable () -> Void) {
        queue.async(group: group) { work() }
        group.notify(queue: .main) { work() }
    }
}
