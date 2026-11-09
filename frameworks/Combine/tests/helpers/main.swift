import COpenCombineHelpers
import Combine
import Dispatch
import Darwin
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)
alarm(120)

var failures = 0
var trapped = false

func check(_ name: String, _ condition: Bool) {
    print((condition ? "ok   " : "FAIL ") + name)
    if !condition {
        failures += 1
    }
}

func waitFor(_ condition: () -> Bool, seconds: Int) -> Bool {
    var waited = 0
    while !condition() && waited < seconds * 100 {
        usleep(10_000)
        waited += 1
    }
    return condition()
}

func terminationSignal(of arguments: [String]) -> Int32? {
    var pid: pid_t = 0
    var argv: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) }
    argv.append(nil)
    var environment: [UnsafeMutablePointer<CChar>?] = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") }
    environment.append(nil)
    defer {
        for string in argv + environment {
            free(string)
        }
    }
    guard posix_spawn(&pid, arguments[0], nil, nil, argv, environment) == 0 else {
        return nil
    }
    var status: Int32 = 0
    guard waitpid(pid, &status, 0) == pid else {
        return nil
    }
    return status & 0x7f
}

func osUnfairLockIsAvailable() -> Bool {
    if #available(iOS 10.0, macOS 10.12, *) {
        return true
    }
    return false
}

if CommandLine.arguments.count > 1 {
    let lock = __UnfairLock.allocate()
    switch CommandLine.arguments[1] {
    case "relock":
        lock.lock()
        lock.lock()
    case "unlock-unowned":
        lock.unlock()
    default:
        break
    }
    exit(0)
}

let workers = 8
let identifiersPerWorker = 20_000
let incrementsPerWorker = 50_000

let first = __nextCombineIdentifier()
var sequential = true
for step in 1...1000 {
    if __nextCombineIdentifier() != first + UInt64(step) {
        sequential = false
    }
}
check("identifiers count up by one on one thread", sequential)

let base = __nextCombineIdentifier() + 1
var taken = [[UInt64]](repeating: [], count: workers)
taken.withUnsafeMutableBufferPointer { slots in
    let results = slots
    DispatchQueue.concurrentPerform(iterations: workers) { worker in
        var mine = [UInt64]()
        mine.reserveCapacity(identifiersPerWorker)
        for _ in 0..<identifiersPerWorker {
            mine.append(__nextCombineIdentifier())
        }
        results[worker] = mine
    }
}
let everything = taken.flatMap { $0 }.sorted()
var contiguous = everything.count == workers * identifiersPerWorker
for (offset, identifier) in everything.enumerated() where identifier != base + UInt64(offset) {
    contiguous = false
}
check("identifiers from \(workers) threads are all distinct and leave no gap", contiguous)

var received = [Int]()
var completed = false
let subject = PassthroughSubject<Int, Never>()
let subscription = subject.map { $0 * 10 }.sink(receiveCompletion: { _ in completed = true },
                                                receiveValue: { received.append($0) })
subject.send(1)
subject.send(2)
subject.send(3)
subject.send(completion: .finished)
check("a subject through map delivers its values to a sink and completes", received == [10, 20, 30] && completed)
subscription.cancel()
check("combine identifiers differ", CombineIdentifier() != CombineIdentifier())

let counter = UnsafeMutablePointer<Int>.allocate(capacity: 1)

counter.pointee = 0
let plain = __UnfairLock.allocate()
DispatchQueue.concurrentPerform(iterations: workers) { _ in
    for _ in 0..<incrementsPerWorker {
        plain.lock()
        counter.pointee += 1
        plain.unlock()
    }
}
check("the lock excludes: \(workers) threads lose no increment", counter.pointee == workers * incrementsPerWorker)

counter.pointee = 0
let recursive = __UnfairRecursiveLock.allocate()
DispatchQueue.concurrentPerform(iterations: workers) { _ in
    for _ in 0..<incrementsPerWorker {
        recursive.lock()
        recursive.lock()
        counter.pointee += 1
        recursive.unlock()
        recursive.unlock()
    }
}
check("the recursive lock excludes: \(workers) threads lose no increment", counter.pointee == workers * incrementsPerWorker)

var deepest = 0
let depthDone = DispatchSemaphore(value: 0)
DispatchQueue.global().async {
    let lock = __UnfairRecursiveLock.allocate()
    for _ in 0..<32 {
        lock.lock()
        deepest += 1
    }
    for _ in 0..<32 {
        lock.unlock()
    }
    lock.deallocate()
    depthDone.signal()
}
check("the recursive lock is entered 32 deep by its owner without blocking",
      depthDone.wait(timeout: .now() + 5) == .success && deepest == 32)

recursive.lock()
recursive.lock()
recursive.lock()
var acquiredRecursive = false
DispatchQueue.global().async {
    recursive.lock()
    acquiredRecursive = true
    recursive.unlock()
}
usleep(200_000)
check("another thread waits while the recursive lock is held 3 deep", !acquiredRecursive)
recursive.unlock()
recursive.unlock()
usleep(200_000)
check("another thread still waits with 1 level held", !acquiredRecursive)
recursive.unlock()
check("another thread gets the recursive lock once every level is released", waitFor({ acquiredRecursive }, seconds: 5))

plain.lock()
plain.assertOwner()
var acquiredPlain = false
DispatchQueue.global().async {
    plain.lock()
    acquiredPlain = true
    plain.unlock()
}
usleep(200_000)
check("another thread waits while the lock is held", !acquiredPlain)
plain.unlock()
check("another thread gets the lock once it is released", waitFor({ acquiredPlain }, seconds: 5))

signal(SIGTRAP) { _ in
    trapped = true
}
__stopInDebugger()
check("stop in debugger raises SIGTRAP", trapped)

if osUnfairLockIsAvailable() {
    print("skip locking a pthread error-check mutex twice and unlocking one not held: this release locks with os_unfair_lock")
} else {
    check("locking the lock twice from its owner ends the process with SIGABRT",
          terminationSignal(of: [CommandLine.arguments[0], "relock"]) == SIGABRT)
    check("unlocking a lock the thread does not hold ends the process with SIGABRT",
          terminationSignal(of: [CommandLine.arguments[0], "unlock-unowned"]) == SIGABRT)
}

recursive.deallocate()
plain.deallocate()
counter.deallocate()

print(failures == 0 ? "combinehelpers: every check held" : "combinehelpers: \(failures) checks failed")
exit(failures == 0 ? 0 : 1)
