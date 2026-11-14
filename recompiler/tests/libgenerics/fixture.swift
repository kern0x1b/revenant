import Foundation

@inline(never) func line(_ text: String) {
    print(text)
    fflush(nil)
}

@inline(never) func report(_ name: String, _ passed: Bool) {
    line((passed ? "ok " : "FAIL ") + name)
}

@inline(never) func textLength(_ text: Unmanaged<AnyObject>!) -> Int {
    guard let text = text else {
        return 0
    }
    return unsafeBitCast(text.takeUnretainedValue(), to: NSString.self).length
}

var holderDeinits = 0
var keeper: AnyObject?
var keptArray: NSArray?
var sharedHolder: Holder<Int>?
var uniqueBox: Box?

final class Holder<T> {
    var value: T

    init(_ value: T) {
        self.value = value
    }

    deinit {
        holderDeinits += 1
    }
}

struct Box {
    var storage: Holder<Int>

    mutating func set(_ value: Int) -> Bool {
        let unique = isKnownUniquelyReferenced(&storage)
        if unique {
            storage.value = value
        } else {
            storage = Holder(value)
        }
        return unique
    }
}

@objc(LibGenerics) public final class LibGenerics: NSObject {
    @objc public func sharedObject() -> AnyObject {
        if sharedHolder == nil {
            sharedHolder = Holder(7)
        }
        return sharedHolder!
    }

    @objc public func stepProxyRace() {
        _ = sharedObject()
    }

    @objc public func stepProxyRaceAfter() {
        report("proxy.race.balanced", isKnownUniquelyReferenced(&sharedHolder) && holderDeinits == 0)
    }

    @objc public func stepProxyWeak() {
        _ = sharedObject()
    }

    @objc public func stepProxyWeakAfter() {
        report("proxy.weak.balanced", isKnownUniquelyReferenced(&sharedHolder) && holderDeinits == 0)
    }

    @objc public func stepProxyUnique() {
        var box = Box(storage: Holder(1))
        let inPlace = box.set(2)
        let originalID = ObjectIdentifier(box.storage)
        keptArray = NSArray(object: box.storage)
        let copied = !box.set(3)
        let seen = unsafeBitCast(keptArray!.object(at: 0) as AnyObject, to: Holder<Int>.self)
        report("proxy.unique.inplace", inPlace)
        report("proxy.unique.copied", copied && ObjectIdentifier(box.storage) != originalID)
        report("proxy.unique.values", seen.value == 2 && box.storage.value == 3 && ObjectIdentifier(seen) == originalID)
        uniqueBox = box
        keptArray = nil
    }

    @objc public func stepProxyUniqueAfter() {
        let unique = uniqueBox!.set(4)
        report("proxy.unique.balanced", unique && uniqueBox!.storage.value == 4 && holderDeinits == 1)
    }

    @inline(never) func bridgedTable() -> NSDictionary {
        let table: [String: String] = ["first-key-0123456789": "first-value-0123456789", "second-key-0123456789": "second-value-0123456789",
                                       "third-key-0123456789": "third-value-0123456789"]
        return unsafeBitCast(table._bridgeToObjectiveCImpl(), to: NSDictionary.self)
    }

    @objc public func stepProxyCount() {
        report("proxy.count", bridgedTable().count == 3)
    }

    @objc public func stepProxyKind() {
        report("proxy.kind", bridgedTable().isKind(of: NSDictionary.self))
    }

    @objc public func stepProxyDescription() {
        report("proxy.description", textLength(bridgedTable().perform(#selector(getter: NSObjectProtocol.description))) > 20)
    }

    @objc public func stepProxyIdentity() {
        let bridged: AnyObject = bridgedTable()
        report("proxy.identity", (NSArray(object: bridged).object(at: 0) as AnyObject) === bridged)
    }

    @objc public func stepProxyNested() {
        report("proxy.nested", textLength(NSArray(object: bridgedTable()).perform(#selector(getter: NSObjectProtocol.description))) > 20)
    }

    @objc public func stepProxyMutation() {
        var table: [String: String] = ["first-key-0123456789": "first-value-0123456789", "second-key-0123456789": "second-value-0123456789",
                                       "third-key-0123456789": "third-value-0123456789"]
        let dictionary = unsafeBitCast(table._bridgeToObjectiveCImpl(), to: NSDictionary.self)
        table["fourth-key-0123456789"] = "fourth-value-0123456789"
        report("proxy.mutation", dictionary.count == 3 && table.count == 4 && dictionary.object(forKey: "fourth-key-0123456789"._bridgeToObjectiveCImpl()) == nil)
    }

    @objc public func stepProxyAny() {
        let loose: [AnyHashable: Any] = [AnyHashable(1): "one", AnyHashable(2): "two"]
        let looseBridged: AnyObject = loose._bridgeToObjectiveCImpl()
        let looseDictionary = unsafeBitCast(looseBridged, to: NSDictionary.self)
        report("proxy.any", looseDictionary.count == 2 && looseDictionary.isKind(of: NSDictionary.self) && (NSArray(object: looseBridged).object(at: 0) as AnyObject) === looseBridged)
    }

    @objc public func stepProxyLifetime() {
        var holder: Holder<Int>? = Holder(41)
        keeper = NSArray(object: holder!)
        holder = nil
        report("proxy.alive", holderDeinits == 0)
        keeper = nil
    }

    @objc public func stepProxyLifetimeAfter() {
        report("proxy.released", holderDeinits == 1)
    }

    @objc public func stepDictionary() {
        var names = [String: String]()
        names["a"] = "alpha"
        names["b"] = "beta"
        report("dictionary.string", names.count == 2 && names["b"] == "beta")
    }

    @objc public func stepDictionaryAny() {
        var bag = [String: Any]()
        bag["count"] = 3
        bag["name"] = "x"
        bag["list"] = [1, 2, 3]
        report("dictionary.any", bag.count == 3 && (bag["count"] as? Int) == 3 && (bag["name"] as? String) == "x" && (bag["list"] as? [Int])?.count == 3)
    }

    @objc public func stepClosures() {
        var makers = [() -> Int]()
        for index in 1...3 {
            makers.append { index * 10 }
        }
        report("closures.array", makers.count == 3 && makers[2]() == 30)
    }

    @objc public func stepNested() {
        var grid = [[Int]]()
        for row in 0..<4 {
            grid.append(Array(0...row))
        }
        report("array.nested", grid.count == 4 && grid[3] == [0, 1, 2, 3] && grid.joined().reduce(0, +) == 10)
    }

    @objc public func stepSubstring() {
        let text = "alpha,beta,gamma,delta"
        var pieces = [Substring]()
        for chunk in text.split(separator: ",") {
            pieces.append(chunk)
        }
        pieces.append(text.dropFirst(6))
        report("substring.split", pieces.count == 5 && pieces[1] == "beta" && pieces[4] == "beta,gamma,delta")
    }

    @objc public func stepStress() {
        var numbers = [Int]()
        var words = [String]()
        var slices = [Substring]()
        var table = [String: Int]()
        let text = "0123456789"
        for index in 0..<10000 {
            numbers.append(index)
            words.append(String(index))
            slices.append(text.dropFirst(index % 10))
            table[words[index]] = index
        }
        var sum = 0
        for number in numbers {
            sum &+= number
        }
        let tail = slices[9999] == "9"
        report("stress.append", numbers.count == 10000 && sum == 49995000 && words[9999] == "9999" && slices.count == 10000 && tail && table.count == 10000 && table["4242"] == 4242)
    }
}
