@_exported import Foundation

public struct XCTestRunStats {
    public var tests = 0, failedTests = 0, failures = 0, skipped = 0
}

public var _xctStats = XCTestRunStats()
var _currentFailures = 0
var _currentName = ""

struct _XCTUnwrapFailure: Error {}

public struct XCTSkip: Error {
    public let message: String
    public init(_ message: String = "") { self.message = message }
}

func _record(_ message: String, _ file: StaticString, _ line: UInt) {
    _currentFailures += 1
    print("\(file):\(line): error: \(_currentName) : \(message)")
}

open class XCTest {
    open var name: String { _currentName }
    public init() {}
}

public final class XCTestExpectation {
    public let expectationDescription: String
    public var expectedFulfillmentCount = 1
    public var assertForOverFulfill = true
    public var isInverted = false
    let lock = NSLock()
    var count = 0
    public init(description: String) { expectationDescription = description }
    public func fulfill() {
        lock.lock(); count += 1; let c = count; lock.unlock()
        if assertForOverFulfill && c > expectedFulfillmentCount {
            _record("API violation - multiple calls made to -[XCTestExpectation fulfill] for \(expectationDescription).", #file, #line)
        }
    }
    var done: Bool { lock.lock(); defer { lock.unlock() }; return count >= expectedFulfillmentCount }
}

open class XCTestCase: XCTest {
    public var continueAfterFailure = true
    public required override init() {}
    open func setUp() {}
    open func tearDown() {}
    open func setUpWithError() throws {}
    open func tearDownWithError() throws {}

    public func expectation(description: String) -> XCTestExpectation {
        XCTestExpectation(description: description)
    }

    public func wait(for expectations: [XCTestExpectation], timeout: TimeInterval,
                     file: StaticString = #file, line: UInt = #line) {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if expectations.allSatisfy({ $0.done }) { break }
            _ = RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        for e in expectations {
            if e.isInverted ? e.done : !e.done {
                _record("Asynchronous wait failed: Exceeded timeout of \(timeout) seconds, with unfulfilled expectations: \"\(e.expectationDescription)\".", file, line)
            }
        }
    }

    public func measure(_ block: () -> Void) { block() }
}

let _skipList: [String] = {
    var names = (ProcessInfo.processInfo.environment["XCT_SKIP"] ?? "").split(separator: ",").map(String.init)
    let dir = (CommandLine.arguments[0] as NSString).deletingLastPathComponent
    if let text = try? String(contentsOfFile: dir + "/xct-skip.txt", encoding: .utf8) {
        names += text.split(separator: "\n").map { String($0) }.filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
    return names
}()

var _resumeFrom: String? = {
    let dir = (CommandLine.arguments[0] as NSString).deletingLastPathComponent
    return (try? String(contentsOfFile: dir + "/xct-resume.txt", encoding: .utf8))?
        .trimmingCharacters(in: .whitespacesAndNewlines)
}()

public func _runTest<T: XCTestCase>(_ type: T.Type, _ testName: String, _ body: (T) -> () throws -> Void) {
    let full = "\(String(describing: type)).\(testName)"
    if let filter = ProcessInfo.processInfo.environment["XCT_FILTER"], !filter.isEmpty,
       !full.contains(filter) { return }
    if let r = _resumeFrom, !r.isEmpty {
        if full != r { return }
        _resumeFrom = nil
    }
    if _skipList.contains(where: { full.contains($0) }) {
        _xctStats.skipped += 1
        print("Test Case '\(full)' skipped (XCT_SKIP)")
        return
    }
    _currentName = full
    _currentFailures = 0
    print("Test Case '\(full)' started.")
    fflush(stdout)
    let start = Date()
    let instance = type.init()
    do {
        try instance.setUpWithError()
        instance.setUp()
        try body(instance)()
        instance.tearDown()
        try instance.tearDownWithError()
    } catch let skip as XCTSkip {
        _xctStats.skipped += 1
        print("Test Case '\(full)' skipped: \(skip.message)")
        return
    } catch is _XCTUnwrapFailure {
    } catch {
        _record("caught error: \"\(error)\"", #file, #line)
    }
    _xctStats.tests += 1
    _xctStats.failures += _currentFailures
    let t = String(format: "%.3f", Date().timeIntervalSince(start))
    if _currentFailures > 0 {
        _xctStats.failedTests += 1
        print("Test Case '\(full)' failed (\(t) seconds).")
        fflush(stdout)
    } else {
        print("Test Case '\(full)' passed (\(t) seconds).")
        fflush(stdout)
    }
}

public func _finishTests() -> Int32 {
    print("Executed \(_xctStats.tests) tests, with \(_xctStats.failures) failures (\(_xctStats.failedTests) tests failed), \(_xctStats.skipped) skipped")
    return _xctStats.failedTests == 0 ? 0 : 1
}

private func msg(_ m: () -> String) -> String { let s = m(); return s.isEmpty ? "" : " - \(s)" }

public func XCTFail(_ message: String = "", file: StaticString = #file, line: UInt = #line) {
    _record("failed\(message.isEmpty ? "" : " - \(message)")", file, line)
}

public func XCTAssert(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "",
                      file: StaticString = #file, line: UInt = #line) {
    XCTAssertTrue(try expression(), message(), file: file, line: line)
}

public func XCTAssertTrue(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "",
                          file: StaticString = #file, line: UInt = #line) {
    do { if try !expression() { _record("XCTAssertTrue failed\(msg(message))", file, line) } }
    catch { _record("XCTAssertTrue threw error \"\(error)\"\(msg(message))", file, line) }
}

public func XCTAssertFalse(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "",
                           file: StaticString = #file, line: UInt = #line) {
    do { if try expression() { _record("XCTAssertFalse failed\(msg(message))", file, line) } }
    catch { _record("XCTAssertFalse threw error \"\(error)\"\(msg(message))", file, line) }
}

public func XCTAssertNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "",
                         file: StaticString = #file, line: UInt = #line) {
    do { if let v = try expression() { _record("XCTAssertNil failed: \"\(v)\"\(msg(message))", file, line) } }
    catch { _record("XCTAssertNil threw error \"\(error)\"\(msg(message))", file, line) }
}

public func XCTAssertNotNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "",
                            file: StaticString = #file, line: UInt = #line) {
    do { if try expression() == nil { _record("XCTAssertNotNil failed\(msg(message))", file, line) } }
    catch { _record("XCTAssertNotNil threw error \"\(error)\"\(msg(message))", file, line) }
}

public func XCTAssertEqual<T: Equatable>(_ e1: @autoclosure () throws -> T, _ e2: @autoclosure () throws -> T,
                                         _ message: @autoclosure () -> String = "",
                                         file: StaticString = #file, line: UInt = #line) {
    do {
        let a = try e1(), b = try e2()
        if a != b { _record("XCTAssertEqual failed: (\"\(a)\") is not equal to (\"\(b)\")\(msg(message))", file, line) }
    } catch { _record("XCTAssertEqual threw error \"\(error)\"\(msg(message))", file, line) }
}

public func XCTAssertEqual<T: FloatingPoint>(_ e1: @autoclosure () throws -> T, _ e2: @autoclosure () throws -> T,
                                             accuracy: T, _ message: @autoclosure () -> String = "",
                                             file: StaticString = #file, line: UInt = #line) {
    do {
        let a = try e1(), b = try e2()
        if abs(a - b) > accuracy { _record("XCTAssertEqual failed: (\"\(a)\") is not equal to (\"\(b)\") +/- (\"\(accuracy)\")\(msg(message))", file, line) }
    } catch { _record("XCTAssertEqual threw error \"\(error)\"\(msg(message))", file, line) }
}

public func XCTAssertNotEqual<T: Equatable>(_ e1: @autoclosure () throws -> T, _ e2: @autoclosure () throws -> T,
                                            _ message: @autoclosure () -> String = "",
                                            file: StaticString = #file, line: UInt = #line) {
    do {
        let a = try e1(), b = try e2()
        if a == b { _record("XCTAssertNotEqual failed: (\"\(a)\") is equal to (\"\(b)\")\(msg(message))", file, line) }
    } catch { _record("XCTAssertNotEqual threw error \"\(error)\"\(msg(message))", file, line) }
}

public func XCTAssertLessThan<T: Comparable>(_ e1: @autoclosure () throws -> T, _ e2: @autoclosure () throws -> T,
                                             _ message: @autoclosure () -> String = "",
                                             file: StaticString = #file, line: UInt = #line) {
    do { let a = try e1(), b = try e2(); if !(a < b) { _record("XCTAssertLessThan failed: (\"\(a)\") is not less than (\"\(b)\")\(msg(message))", file, line) } }
    catch { _record("XCTAssertLessThan threw error \"\(error)\"", file, line) }
}

public func XCTAssertGreaterThan<T: Comparable>(_ e1: @autoclosure () throws -> T, _ e2: @autoclosure () throws -> T,
                                                _ message: @autoclosure () -> String = "",
                                                file: StaticString = #file, line: UInt = #line) {
    do { let a = try e1(), b = try e2(); if !(a > b) { _record("XCTAssertGreaterThan failed: (\"\(a)\") is not greater than (\"\(b)\")\(msg(message))", file, line) } }
    catch { _record("XCTAssertGreaterThan threw error \"\(error)\"", file, line) }
}

public func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "",
                                    file: StaticString = #file, line: UInt = #line,
                                    _ errorHandler: (_ error: Error) -> Void = { _ in }) {
    do { _ = try expression(); _record("XCTAssertThrowsError failed: did not throw an error\(msg(message))", file, line) }
    catch { errorHandler(error) }
}

public func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "",
                                file: StaticString = #file, line: UInt = #line) {
    do { _ = try expression() } catch { _record("XCTAssertNoThrow failed: threw error \"\(error)\"\(msg(message))", file, line) }
}

public func XCTUnwrap<T>(_ expression: @autoclosure () throws -> T?, _ message: @autoclosure () -> String = "",
                         file: StaticString = #file, line: UInt = #line) throws -> T {
    if let v = try expression() { return v }
    _record("XCTUnwrap failed: expected non-nil value of type \"\(T.self)\"\(msg(message))", file, line)
    throw _XCTUnwrapFailure()
}
