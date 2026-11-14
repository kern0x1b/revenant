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
var rooted: Rooted?
final class Rooted {
}
var plainHashed: PlainHashed?
final class PlainHashed {
}

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

class Base<T> {
    let value: T

    init(_ value: T) {
        self.value = value
    }
}

final class Derived<T>: Base<T> {}

var xiDeinits = 0

final class XiRoot {
    deinit {
        xiDeinits += 1
    }
}

enum XiCase { case payload(XiRoot), c0, c1, c2, c3, c4, c5, c6, c7, c8, c9 }
enum XiPlain { case payload(XiRoot), c0, c1, c2, c3, c4, c5, c6, c7, c8, c9 }
struct XiBox { var root: XiRoot; var number: Int }
struct XiBoxPlain { var root: XiRoot; var number: Int }

@inline(never) func xiMake<T>(_ value: T, _ some: Bool) -> T? {
    return some ? value : nil
}

@inline(never) func xiIsSome<T>(_ value: T?) -> Bool {
    if case .some = value {
        return true
    }
    return false
}

final class XiKey: Hashable {
    deinit {
        xiDeinits += 1
    }

    static func == (left: XiKey, right: XiKey) -> Bool {
        return left === right
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

@inline(never) func xiConsume<T>(_ value: consuming T?) {
}

@inline(never) func xiCopies<T>(_ value: T?, _ count: Int) -> [T?] {
    var copies: [T?] = []
    for _ in 0..<count {
        copies.append(value)
    }
    return copies
}

@inline(never) func xiWord<T>(_ value: T?) -> UInt64 {
    var copy = value
    return withUnsafeBytes(of: &copy) { $0.load(as: UInt64.self) }
}

@inline(never) func xiName(_ value: XiCase?) -> Int {
    switch value {
    case .none: return -1
    case .some(.payload): return 100
    case .some(.c0): return 0
    case .some(.c1): return 1
    case .some(.c2): return 2
    case .some(.c3): return 3
    case .some(.c4): return 4
    case .some(.c5): return 5
    case .some(.c6): return 6
    case .some(.c7): return 7
    case .some(.c8): return 8
    case .some(.c9): return 9
    }
}

@inline(never) func xiAncestor(_ value: Mirror.AncestorRepresentation?) -> Int {
    switch value {
    case .none: return -1
    case .some(.generated): return 0
    case .some(.customized): return 1
    case .some(.suppressed): return 2
    @unknown default: return -3
    }
}

@inline(never) func xiCases() -> [XiCase] {
    return [.c0, .c1, .c2, .c3, .c4, .c5, .c6, .c7, .c8, .c9]
}

@objc(LibGenericsSequence) public final class LibGenericsSequence: NSObject, NSFastEnumeration {
    let members: [NSObject] = (0..<40).map { _ in NSObject() }

    public func countByEnumerating(with state: UnsafeMutablePointer<NSFastEnumerationState>, objects buffer: AutoreleasingUnsafeMutablePointer<AnyObject?>, count len: Int) -> Int {
        let start = Int(state.pointee.state)
        let batch = min(len, members.count - start)
        if batch <= 0 {
            return 0
        }
        let slots = unsafeBitCast(buffer, to: UnsafeMutablePointer<Unmanaged<AnyObject>?>.self)
        for index in 0..<batch {
            slots[index] = Unmanaged.passUnretained(members[start + index])
        }
        state.pointee.state = UInt(start + batch)
        state.pointee.itemsPtr = buffer
        state.pointee.mutationsPtr = withUnsafeMutablePointer(to: &state.pointee.extra.0) { $0 }
        return batch
    }
}

@objc(LibGenerics) public final class LibGenerics: NSObject {
    @objc public func fastSequence() -> AnyObject {
        return LibGenericsSequence()
    }

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

    @objc public func bridgedDictionary() -> AnyObject {
        return bridgedTable()
    }

    @objc public func stepProxyCount() {
        report("proxy.count", bridgedTable().count == 3)
    }

    @objc public func stepProxyObject() {
        let table = bridgedTable()
        let enumerator = table.perform(#selector(NSDictionary.keyEnumerator))!.takeUnretainedValue()
        let key = enumerator.perform(#selector(NSEnumerator.nextObject))
        let found = key == nil ? nil : table.perform(#selector(NSDictionary.object(forKey:)), with: key!.takeUnretainedValue())
        let absent = table.perform(#selector(NSDictionary.object(forKey:)), with: "absent-key-0123456789"._bridgeToObjectiveCImpl())
        report("proxy.object", found != nil && absent == nil)
    }

    @objc public func stepProxyKeys() {
        let keys = bridgedTable().perform(#selector(getter: NSDictionary.allKeys))
        report("proxy.keys", keys != nil && unsafeBitCast(keys!.takeUnretainedValue(), to: NSArray.self).count == 3)
    }

    @objc public func stepProxyValues() {
        let values = bridgedTable().perform(#selector(getter: NSDictionary.allValues))
        report("proxy.values", values != nil && unsafeBitCast(values!.takeUnretainedValue(), to: NSArray.self).count == 3)
    }

    @objc public func stepProxyEnumerate() {
        var seen = 0
        bridgedTable().enumerateKeysAndObjects { _, _, _ in
            seen += 1
        }
        report("proxy.enumerate", seen == 3)
    }

    @objc public func stepDlsymFunction() {
        let handle = UnsafeMutableRawPointer(bitPattern: -2)
        typealias TypeID = @convention(c) () -> UInt
        typealias GetTypeID = @convention(c) (UnsafeRawPointer?) -> UInt
        let typeID = dlsym(handle, "CFStringGetTypeID").map { unsafeBitCast($0, to: TypeID.self) }
        let getTypeID = dlsym(handle, "CFGetTypeID").map { unsafeBitCast($0, to: GetTypeID.self) }
        let null = Unmanaged.passUnretained(NSNull()).toOpaque()
        report("dlsym.typeid", typeID != nil && typeID!() == UInt(CFStringGetTypeID()))
        report("dlsym.object", getTypeID != nil && getTypeID!(UnsafeRawPointer(null)) == UInt(CFNullGetTypeID()))
    }

    @objc public func stepExtraInhabitants() {
        xiDeinits = 0
        do {
            let root = XiRoot()
            var generic = true
            var inline = true
            var words = true
            for (index, value) in xiCases().enumerated() {
                let made = xiMake(value, true)
                generic = generic && xiIsSome(made)
                inline = inline && xiName(made) == index
                words = words && xiWord(made) == UInt64(index)
            }
            let payload = xiMake(XiCase.payload(root), true)
            let none = xiMake(XiCase.c0, false)
            report("xi.enum.generic", generic && xiIsSome(payload) && !xiIsSome(none))
            report("xi.enum.inline", inline && xiName(payload) == 100 && xiName(none) == -1)
            report("xi.enum.word", words && xiWord(none) == 10)
            var kept = xiCopies(payload, 8)
            kept += xiCopies(xiMake(XiCase.c4, true), 8)
            kept += xiCopies(none, 4)
            var holding = 0
            for entry in kept where xiName(entry) == 100 {
                holding += 1
            }
            report("xi.enum.copies", kept.count == 20 && holding == 8 && xiDeinits == 0)
            kept.removeAll()
            report("xi.enum.destroyed", xiDeinits == 0)
            withExtendedLifetime(root) {}
        }
        report("xi.enum.balance", xiDeinits == 1)
        xiDeinits = 0
        do {
            let root = XiRoot()
            xiConsume(Optional(XiCase.payload(root)))
            report("xi.enum.consumed", xiDeinits == 0)
            withExtendedLifetime(root) {}
        }
        report("xi.enum.released", xiDeinits == 1)
        xiDeinits = 0
        xiConsume(Optional(XiRoot()))
        report("xi.class.released", xiDeinits == 1)
        xiDeinits = 0
        do {
            let root = XiRoot()
            let box = xiMake(XiBox(root: root, number: 7), true)
            let none = xiMake(XiBox(root: root, number: 0), false)
            var inline = false
            if case .some(let value) = box {
                inline = value.number == 7 && value.root === root
            }
            report("xi.struct.generic", xiIsSome(box) && !xiIsSome(none))
            report("xi.struct.inline", inline && xiWord(none) == 0)
            var kept = xiCopies(box, 8) + xiCopies(none, 4)
            report("xi.struct.copies", kept.count == 12 && xiDeinits == 0)
            kept.removeAll()
            report("xi.struct.destroyed", xiDeinits == 0)
            withExtendedLifetime(root) {}
        }
        report("xi.struct.balance", xiDeinits == 1)
        xiDeinits = 0
        do {
            let root = XiRoot()
            xiConsume(Optional(XiBox(root: root, number: 3)))
            report("xi.struct.consumed", xiDeinits == 0)
            withExtendedLifetime(root) {}
        }
        report("xi.struct.released", xiDeinits == 1)
    }

    @objc public func stepExtraInhabitantsStdlib() {
        xiDeinits = 0
        do {
            let root = XiRoot()
            let generated = xiMake(Mirror.AncestorRepresentation.generated, true)
            let suppressed = xiMake(Mirror.AncestorRepresentation.suppressed, true)
            let customized = xiMake(Mirror.AncestorRepresentation.customized({ withExtendedLifetime(root) { Mirror(reflecting: 7) } }), true)
            let none = xiMake(Mirror.AncestorRepresentation.generated, false)
            report("xi.stdlib.generic", xiIsSome(generated) && xiIsSome(suppressed) && xiIsSome(customized) && !xiIsSome(none))
            report("xi.stdlib.inline", xiAncestor(generated) == 0 && xiAncestor(customized) == 1 && xiAncestor(suppressed) == 2 && xiAncestor(none) == -1)
            var kept = xiCopies(customized, 8) + xiCopies(generated, 4) + xiCopies(none, 4)
            report("xi.stdlib.copies", kept.count == 16 && xiDeinits == 0)
            kept.removeAll()
            report("xi.stdlib.destroyed", xiDeinits == 0)
            withExtendedLifetime(customized) {}
        }
        report("xi.stdlib.balance", xiDeinits == 1)
        xiDeinits = 0
        do {
            let root = XiRoot()
            xiConsume(Optional(Mirror.AncestorRepresentation.customized({ withExtendedLifetime(root) { Mirror(reflecting: 7) } })))
            report("xi.stdlib.consumed", xiDeinits == 0)
            withExtendedLifetime(root) {}
        }
        report("xi.stdlib.released", xiDeinits == 1)
    }

    @objc public func stepExtraInhabitantsControl() {
        xiDeinits = 0
        do {
            let root = XiRoot()
            xiConsume(Optional(XiBoxPlain(root: root, number: 1)))
            withExtendedLifetime(root) {}
        }
        report("xi.control.struct", xiDeinits == 1)
        xiDeinits = 0
        do {
            let root = XiRoot()
            xiConsume(Optional(XiPlain.payload(root)))
            withExtendedLifetime(root) {}
        }
        report("xi.control.enum", xiDeinits == 1)
        xiDeinits = 0
        xiConsume(Optional(AnyHashable(XiKey())))
        report("xi.control.stdlib", xiDeinits == 1)
    }

    @objc public func stepShortString() {
        let bridged: AnyObject = "abc"._bridgeToObjectiveCImpl()
        let text = unsafeBitCast(bridged, to: NSString.self)
        report("short.string", text.length == 3 && text.character(at: 1) == 98)
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

    @objc public func stepClassesOfHost() {
        let key = unsafeBitCast(NSNumber(value: 1).perform(#selector(getter: NSNumber.stringValue)).takeUnretainedValue(), to: NSString.self)
        let literal = NSDictionary(object: NSNumber(value: 1), forKey: key)
        let mutable = NSMutableDictionary()
        mutable.setObject(NSNumber(value: 1), forKey: key)
        let copied = mutable.copy() as AnyObject
        let objects: [(String, AnyObject)] = [("literal", literal), ("mutable", mutable), ("copy", copied)]
        for (label, object) in objects {
            report("hostclass.guest." + label, (object as? LibGenerics) == nil && (object as? Holder<Int>) == nil && (object as? Base<Int>) == nil)
            report("hostclass.metatype." + label, !((type(of: object) as Any.Type) is Base<Int>.Type))
        }
        report("hostclass.conforms", ((literal as AnyObject) as Any as? CustomStringConvertible).map { _ in true } ?? true)
        report("hostclass.superclass", ((literal as AnyObject) as? NSMutableDictionary) == nil && ((mutable as AnyObject) as? NSDictionary) != nil)
        report("hostclass.number", ((NSNumber(value: 3) as AnyObject) as? NSString) == nil && ((NSNumber(value: 3) as AnyObject) as? NSNumber) != nil)
        let me: AnyObject = self
        report("hostclass.control", (me as? NSObject) != nil && (me as? NSDictionary) == nil && (me as? LibGenerics) != nil)
        let base: Any = Base(5)
        report("generic.dyncast", (base as? Base<Int>)?.value == 5 && (base as? Base<String>) == nil)
        report("generic.superclass", _getSuperclass(Derived<Int>.self) == Base<Int>.self && _getSuperclass(Derived<String>.self) == Base<String>.self)
        let derived: Any = Derived("s")
        report("generic.subclass", (derived as? Base<String>)?.value == "s" && (derived as? Base<Int>) == nil)
    }

    @objc public func stepSwiftObjectHash() {
        rooted = Rooted()
        let object = unsafeBitCast(rooted! as AnyObject, to: NSObject.self)
        report("swiftobject.hash", object.hash == object.hash && object.isEqual(object))
    }

    @objc public func stepProxyHash() {
        let object = unsafeBitCast(sharedObject(), to: NSObject.self)
        report("proxy.hash", object.hash == object.hash)
    }

    @objc public func stepPlainHash() {
        plainHashed = PlainHashed()
        let object = unsafeBitCast(plainHashed! as AnyObject, to: NSObject.self)
        report("plain.hash", object.hash == object.hash)
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
