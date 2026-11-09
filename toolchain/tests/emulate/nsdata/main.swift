import Foundation

let sentinel: UInt8 = 0xAB
let payload: [UInt8] = [1, 2, 3, 4]
let margin = 16

let storage = UnsafeMutablePointer<UInt8>.allocate(capacity: margin + payload.count + margin)
storage.initialize(repeating: sentinel, count: margin + payload.count + margin)
for (index, byte) in payload.enumerated() {
  storage[margin + index] = byte
}
let data = NSData(bytesNoCopy: storage + margin, length: payload.count, freeWhenDone: false)

var failures = 0

func report(_ label: String, _ got: UInt8, _ expected: UInt8) {
  let verdict = got == expected ? "OK" : "WRONG"
  if got != expected {
    failures += 1
  }
  print("nsdata: \(label) \(verdict) got \(got) expected \(expected)")
  fflush(stdout)
}

for index in 0..<payload.count {
  report("inside\(index)", data[index], payload[index])
}
report("pastEnd", data[payload.count], 0)
report("farPastEnd", data[payload.count + margin - 1], 0)
report("beforeStart", data[-1], 0)
report("farBeforeStart", data[-margin], 0)

let regions = data.regions
let whole = regions.count == 1 && regions[0].elementsEqual(payload)
print("nsdata: regions \(whole ? "OK" : "WRONG") count \(regions.count)")
fflush(stdout)
if !whole {
  failures += 1
}

let empty = NSData()
report("empty", empty[0], 0)

print("nsdata: done failures \(failures)")
fflush(stdout)
exit(Int32(failures))
