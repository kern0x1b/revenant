import CxxStdlib
import ProbeCxx

let cxxText: std.string = std.string("h\u{e9}llo")
let back: String = String(cxxText)
let echoed: String = String(probe.echo(cxxText))
let parts = probe.split(std.string("a,b,c"))
var pieces: [String] = []
for part in parts { pieces.append(String(part)) }
let add = probe.adder(5)
let sum: Int32 = add(3)
let doubled: Int32 = probe.apply(probe.adder(1), 4)
let shared = probe.makeCounter(9)
let maybe = probe.maybe(4)
let counts = probe.counts()
let one: Int32 = counts[std.string("one")]!
let table = probe.table()
print(back, echoed, pieces, sum, doubled, shared.pointee.next(), maybe.hasValue, one, counts.size(), table.size())
