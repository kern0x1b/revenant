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
}

@objc(FixtureSub) final class Sub: Client {
    var extra = 40
    @objc override func bump() -> Int {
        extra += 1
        return super.bump() + extra
    }
}

final class Plain { var v = 3 }

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

client()
sub()
release()
host()
names()
line("done")
