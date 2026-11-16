import Foundation

var destroyed = 0

@inline(never) func line(_ text: String) {
    print(text)
    fflush(nil)
}

@inline(never) func report(_ name: String, _ ok: Bool) {
    line((ok ? "ok " : "FAIL ") + name)
}

@objc(FixtureToken) final class Token: NSObject {
    @objc let value: Int
    let text: String
    init(value: Int) {
        self.value = value
        self.text = "t" + String(value)
        super.init()
    }
    deinit {
        destroyed += 1
        line("deinit Token " + String(value))
    }
}

@objc(FixtureClient) class Client: NSObject {
    var counter = 0
    var items: [String] = []
    var last: Token?
    @objc func bump() -> Int {
        counter += 1
        items.append("x" + String(counter))
        return counter
    }
    @objc func me() -> Client { return self }
    @objc func make(_ value: Int) -> Token {
        let token = Token(value: value)
        last = token
        return token
    }
    @objc func run(_ done: @escaping (Token?) -> Void) { done(make(counter)) }
    @objc func copyMade(_ value: Int) -> Token { return Token(value: value) }
    @objc func newToken(_ value: Int) -> Token { return Token(value: value) }
}

@objc(FixtureError) final class FixtureError: NSError {
    @objc init(number: Int) {
        super.init(domain: "FixtureDomain", code: number, userInfo: ["number": number, "text": "n" + String(number)])
    }
    @objc required init?(coder: NSCoder) { super.init(coder: coder) }
}

@objc(FixtureSub) final class Sub: Client {
    var extra = 40
    @objc override func bump() -> Int {
        extra += 1
        return super.bump() + extra
    }
}

final class Plain { var v = 3 }

struct Point {
    var x = 1
    var y = 2
}

@inline(never) func client() {
    let c = Client()
    report("client.bump", c.bump() == 1 && c.bump() == 2 && c.items.count == 2)
    report("client.make", c.make(9).value == 9 && c.last?.text == "t9")
    var got = -1
    c.run { token in got = token?.value ?? -2 }
    report("client.block", got == 2)
    report("client.dyncast", ((c as AnyObject) as? Client) != nil && ((c as AnyObject) as? Sub) == nil)
    report("client.sametype", type(of: c) == Client.self)
    report("objc.responds", c.responds(to: #selector(Client.bump)))
    report("objc.perform", c.perform(#selector(Client.me))?.takeUnretainedValue() === c)
    report("objc.kind", (c as NSObject).isKind(of: NSObject.self))
    report("objc.hash", (c as NSObject).hash == (c as NSObject).hash)
}

@inline(never) func sub() {
    let s = Sub()
    let first = s.bump()
    report("sub.vtable", first == 42 && s.extra == 41 && s.counter == 1)
    let base: Client = s
    let second = base.bump()
    report("sub.dispatch", second == 44 && s.counter == 2)
    report("sub.dyncast", ((base as AnyObject) as? Sub) === s)
    report("sub.superclass", Sub.superclass() == Client.self)
}

@inline(never) func release() {
    let before = destroyed
    do {
        let c = Client()
        _ = c.make(77)
    }
    report("ivars.released", destroyed == before + 1)
    let subs = destroyed
    do {
        let s = Sub()
        _ = s.make(78)
    }
    report("ivars.released.sub", destroyed == subs + 1)
}

@inline(never) func host() {
    guard let found = objc_getClass("FixtureSub"), let cls = found as? AnyClass,
          let made = class_createInstance(cls, 0) else {
        report("host.create", false)
        return
    }
    report("host.create", (made as? Client) != nil && (made as? Sub) != nil)
    guard let initable = cls as? NSObject.Type else {
        report("host.init", false)
        return
    }
    let object = initable.init()
    let client = object as? Client
    report("host.init", client != nil)
    report("host.dispatch", client?.bump() == 42)
    report("host.subtype", (object as? Sub)?.extra == 41)
}

@inline(never) func names() {
    report("name.plain", _typeName(Plain.self, qualified: false) == "Plain")
    report("name.client", _typeName(Client.self, qualified: false) == "Client")
}

@inline(never) func errors() {
    var kept: [FixtureError] = []
    var fine = true
    autoreleasepool {
        for number in 0..<40 {
            let error = FixtureError(number: number)
            fine = fine && error.code == number && error.userInfo["number"] as? Int == number
            if number % 4 == 0 { kept.append(error) }
        }
    }
    var survivors = true
    for error in kept {
        survivors = survivors && error.userInfo["text"] as? String == "n" + String(error.code)
    }
    kept.removeAll()
    autoreleasepool {
        let again = FixtureError(number: 7)
        _ = again.userInfo
    }
    report("error.userinfo", fine)
    report("error.survives", survivors)
}

client()
sub()
release()
errors()
@inline(never) func reflection() {
    report("anycollection.int", AnyCollection([1, 2, 3]).count == 3)
    report("anycollection.string", AnyCollection("abc").count == 3)
    report("mirror.children", Mirror(reflecting: Point()).children.count == 2)
    report("describe.struct", String(describing: Point()) == "Point(x: 1, y: 2)")
    report("describe.class", String(describing: Plain.self) == "Plain")
}

@inline(never) func corefoundation() {
    let alpha = "alpha" as NSString
    let gamma = "gamma" as NSString
    let dictionary = ["alpha": 1, "beta": "two"] as [String: Any] as CFDictionary
    report("cf.dictionary.count", CFDictionaryGetCount(dictionary) == 2)
    report("cf.dictionary.contains", CFDictionaryContainsKey(dictionary, Unmanaged.passUnretained(alpha).toOpaque()))
    report("cf.dictionary.missing", !CFDictionaryContainsKey(dictionary, Unmanaged.passUnretained(gamma).toOpaque()))
    report("cf.dictionary.value", CFDictionaryGetValue(dictionary, Unmanaged.passUnretained(alpha).toOpaque()) != nil)
    report("cf.array.count", CFArrayGetCount(["a", "b", "c"] as CFArray) == 3)
    report("cf.data.length", CFDataGetLength(Data([1, 2, 3, 4]) as CFData) == 4)
    report("cf.string.length", CFStringGetLength("hello" as CFString) == 5)
}

host()
names()
reflection()
corefoundation()
line("done")
