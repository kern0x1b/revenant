#if !REVENANT_BACKPORT
import Network
#endif
import Foundation

let done = DispatchSemaphore(value: 0)
Task {
    let monitor = NWPathMonitor()
    var count = 0
    for await path in monitor {
        count += 1
        print("element \(count) status \(path.status) interfaces \(path.availableInterfaces.count > 0)")
        if count == 1 {
            break
        }
    }
    print("iteration done: \(count)")
    done.signal()
}
_ = done.wait(timeout: .now() + 15)
