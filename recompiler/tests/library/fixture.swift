import Foundation

private var created = 0

@objc(RCFToken) public final class Token: NSObject {
    @objc public let value: Int

    @objc public init(value: Int) {
        self.value = value
        super.init()
    }
}

@objc(RCFClient) public final class Client: NSObject {
    private let initial: Int
    private var counter = 0
    private var issued: [Int: Int] = [:]
    private var pendingAction = 0
    private var pendingCompletion: ((Token?, NSError?) -> Void)?

    private init(seed: Int) {
        initial = seed
        super.init()
    }

    @objc(clientWithSeed:) public static func client(seed: Int) -> Client {
        created += 1
        return Client(seed: seed)
    }

    @objc public func bump() -> Int {
        counter += 1
        return counter
    }

    @objc public func seed() -> Int {
        return initial
    }

    @objc public func describedLength() -> Int {
        return "client-\(initial)-\(counter)".count
    }

    @objc public func hostBundle() -> NSObject {
        return Bundle.main
    }

    @objc(tokenForAction:) public func token(action: Int) -> Token {
        issued[action, default: 0] += 1
        return Token(value: initial * 1000 + action * 10 + created)
    }

    @objc(executeWithAction:completion:) public func execute(action: Int, completion: @escaping (Token?, NSError?) -> Void) {
        pendingAction = action
        pendingCompletion = completion
        performSelector(inBackground: #selector(finish), with: nil)
    }

    @objc private func finish() {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(token(action: pendingAction), nil)
    }

    @objc public func threadNumber() -> Int {
        return Thread.isMainThread ? 1 : 2
    }
}
