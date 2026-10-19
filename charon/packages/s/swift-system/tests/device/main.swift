// The armv7 probe of swift-system, and its host twin. One source: on the device it imports the installed module SystemPackage
// (libswiftSystem.dylib); on the host the same source is built against the same module compiled from the same tree for macOS,
// or against Apple's System with `-module-alias SystemPackage=System`. Every output line starts with "P| " so a log is
// filtered with grep, and no line carries a path of the machine that ran it: the directory is an argument, its name is not printed.
//
// Usage: systemprobe <directory>   (the directory exists; the probe writes systemprobe.txt into it)
import SystemPackage

let args = CommandLine.arguments
let dir = FilePath(args.count > 1 ? args[1] : "/tmp")

// FilePath: components, root, last component, extension, stem, and the lexical operations, on fixed paths.
let sample = FilePath("/tmp/systemprobe/a/b.tar.gz")
print("P| components \(sample.components.map { $0.string })")
print("P| root \(sample.root?.string ?? "nil") absolute \(sample.isAbsolute)")
print("P| last \(sample.lastComponent?.string ?? "nil") ext \(sample.extension ?? "nil") stem \(sample.stem ?? "nil")")
print("P| removing-last \(sample.removingLastComponent().description)")
print("P| appending \(sample.appending("c.txt").description)")
let relative = FilePath("x/./y/../z")
print("P| relative \(relative.components.map { $0.string }) normalized \(relative.lexicallyNormalized().description)")

// FileDescriptor: write a fixed text into a file of the directory, read it back, close both times.
let file = dir.appending("systemprobe.txt")
let text: [UInt8] = Array("systemprobe line one\nline two\n".utf8)
do {
  let fd = try FileDescriptor.open(file, .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
  let written = try fd.writeAll(text)
  try fd.close()
  print("P| write bytes \(written)")
} catch let e as Errno {
  print("P| write errno \(e.rawValue)")
} catch {
  print("P| write threw other error")
}
do {
  let fd = try FileDescriptor.open(file, .readOnly)
  var buffer = [UInt8](repeating: 0, count: 64)
  let count = try buffer.withUnsafeMutableBytes { try fd.read(into: $0) }
  try fd.close()
  let back = Array(buffer[0..<count])
  print("P| read bytes \(count) same \(back == text)")
  print("P| read text \(String(decoding: back, as: UTF8.self).debugDescription)")
} catch let e as Errno {
  print("P| read errno \(e.rawValue)")
} catch {
  print("P| read threw other error")
}

// Errno: a file that is not there is refused with ENOENT, and the value is the constant's.
let missing = dir.appending("systemprobe-missing.txt")
do {
  _ = try FileDescriptor.open(missing, .readOnly)
  print("P| missing opened (unexpected)")
} catch let e as Errno {
  print("P| missing errno \(e.rawValue) is-no-such-file \(e == .noSuchFileOrDirectory)")
} catch {
  print("P| missing threw other error")
}
print("P| done")
