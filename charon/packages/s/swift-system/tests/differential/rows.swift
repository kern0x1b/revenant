// Per-row differential: one line per carried row (carried-rows.txt, the 420 names of the surface that upstream 1.8.1
// implements). Each row is probed on inputs generated from the seed (main.swift prints it) and printed as
// "row <api> n=<observations> fnv=<hash>"; the observations go to rows-detail.txt so a DIFFERENT row can be read.
// A row the host cannot reach prints "not-exercised: <reason>", and that line is counted apart from the comparisons.
#if OURS
import SystemUnderTest
#else
import System
#endif

var rowRng = SplitMix64(state: 1)
var rowDetail = ""
var rowRunDir = ""

func fnv(_ s: String) -> String {
  var h: UInt64 = 0xcbf2_9ce4_8422_2325
  for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01B3 }
  return String(h, radix: 16)
}

func emit(_ api: String, _ raw: [String]) {
  let obs = raw.map { $0.replacing("SystemUnderTest.", with: "System.") }
  let text = obs.joined(separator: "\n")
  let status = obs.first?.hasPrefix("not-exercised") == true ? " not-exercised" : ""
  print("row \(api) n=\(obs.count) fnv=\(fnv(text))\(status)")
  rowDetail += "== \(api)\n\(text)\n"
}

func probe(_ api: String, _ body: () throws -> [String]) {
  do { emit(api, try body()) } catch { emit(api, ["threw \(error)"]) }
}

func notExercised(_ api: String, _ reason: String) { emit(api, ["not-exercised: \(reason)"]) }

// The module name is the only difference the reflection shows (System. against SystemUnderTest.): it is normalised.
func describeBoth<T>(_ v: T) -> [String] { [String(describing: v), String(reflecting: v)].map { $0.replacing("SystemUnderTest.", with: "System.") } }

func constant<T>(_ api: String, _ v: T) { probe(api) { describeBoth(v) } }

func constantAlias<T>(_ api: String, _ target: String, _ v: T) {
  probe(api) { ["alias of \(target)"] + describeBoth(v) }
}

func shape<T: ~Copyable>(_ api: String, _ t: T.Type) {
  probe(api) { ["size \(MemoryLayout<T>.size) align \(MemoryLayout<T>.alignment) stride \(MemoryLayout<T>.stride)"] }
}

func genBytes(_ n: Int) -> [UInt8] { (0..<n).map { _ in UInt8(truncatingIfNeeded: rowRng.next()) } }

// FilePath observations shared by the FilePath rows: the same fields for every generated path.
func pathObs(_ p: FilePath) -> [String] {
  [p.description, p.debugDescription, "\(p.isAbsolute) \(p.isRelative) \(p.isEmpty) \(p.isLexicallyNormal)",
   "root=\(p.root?.string ?? "nil") length=\(p.length)", "last=\(p.lastComponent?.string ?? "nil") stem=\(p.stem)",
   "removingLast=\(p.removingLastComponent().description) lastComponent=\(p.lastComponent?.string ?? "nil")",
   "components=\(p.components.map { $0.string })", p.string]
}

let rowAlphabet = ["a", "b", ".", "/", "..", " ", "\u{E9}", "x.y", "//", "name.ext", "c"]
func rowPath() -> String {
  var s = rowRng.below(3) == 0 ? "/" : ""
  for _ in 0..<(1 + rowRng.below(6)) { s += rowAlphabet[rowRng.below(rowAlphabet.count)] }
  return s
}
func rowName() -> String { ["a", "bc", "x.y", "\u{E9}", "name.ext"][rowRng.below(5)] }

func rowFile(_ tag: String) -> String { "\(rowRunDir)/row-\(tag).bin" }

func runRows(seed: UInt64, runDir: String) {
  rowRng = SplitMix64(state: seed &+ 7)
  rowRunDir = runDir
  constantRows()

  // Errno: the raw values the test reaches, and a generated set.
  probe("Errno.init(rawValue:)") {
    var out: [String] = []
    for raw in Int32(0)...140 { out += describeBoth(Errno(rawValue: raw)) + ["\(raw) \(Errno(rawValue: raw) == .noSuchFileOrDirectory)"] }
    for _ in 0..<32 { let raw = Int32(rowRng.below(300)); out += describeBoth(Errno(rawValue: raw)) }
    return out
  }

  // FilePermissions: the instance members and the generated raw values.
  probe("FilePermissions.init(rawValue:)") {
    (0..<64).map { _ in FilePermissions(rawValue: CModeT(truncatingIfNeeded: rowRng.next()) & 0o7777).rawValue.description }
  }
  probe("FilePermissions.rawValue") { [FilePermissions.ownerRead, .groupWrite, .otherExecute].map { $0.rawValue.description } }
  probe("FilePermissions.description") { [FilePermissions.ownerRead, .groupWrite, .otherExecute].map { $0.description } }
  probe("FilePermissions.debugDescription") { [FilePermissions.ownerRead, .groupWrite, .otherExecute].map { $0.debugDescription } }

  // FileDescriptor: the raw values, the open modes, and the calls on generated files.
  probe("FileDescriptor.init(rawValue:)") { (0..<8).map { raw in FileDescriptor(rawValue: CInt(raw)).rawValue.description } }
  probe("FileDescriptor.rawValue") { [FileDescriptor.standardInput, .standardOutput, .standardError].map { $0.rawValue.description } }
  probe("FileDescriptor.AccessMode.init(rawValue:)") {
    (0..<4).map { raw in describeBoth(FileDescriptor.AccessMode(rawValue: CInt(raw))).joined(separator: " ") }
  }
  probe("FileDescriptor.AccessMode.rawValue") {
    [FileDescriptor.AccessMode.readOnly, .writeOnly, .readWrite].map { $0.rawValue.description }
  }
  probe("FileDescriptor.AccessMode.description") {
    [FileDescriptor.AccessMode.readOnly, .writeOnly, .readWrite].map { $0.description }
  }
  probe("FileDescriptor.AccessMode.debugDescription") {
    [FileDescriptor.AccessMode.readOnly, .writeOnly, .readWrite].map { $0.debugDescription }
  }
  probe("FileDescriptor.OpenOptions.init(rawValue:)") {
    (0..<16).map { raw in describeBoth(FileDescriptor.OpenOptions(rawValue: CInt(raw) << 2)).joined(separator: " ") }
  }
  probe("FileDescriptor.OpenOptions.rawValue") {
    [FileDescriptor.OpenOptions.create, .truncate, [.create, .exclusiveCreate]].map { $0.rawValue.description }
  }
  probe("FileDescriptor.OpenOptions.description") {
    [FileDescriptor.OpenOptions.create, .truncate, [.create, .exclusiveCreate]].map { $0.description }
  }
  probe("FileDescriptor.OpenOptions.debugDescription") {
    [FileDescriptor.OpenOptions.create, .truncate, [.create, .exclusiveCreate]].map { $0.debugDescription }
  }
  probe("FileDescriptor.SeekOrigin.init(rawValue:)") {
    (0..<5).map { raw in describeBoth(FileDescriptor.SeekOrigin(rawValue: CInt(raw))).joined(separator: " ") }
  }
  probe("FileDescriptor.SeekOrigin.rawValue") {
    [FileDescriptor.SeekOrigin.start, .current, .end].map { $0.rawValue.description }
  }
  probe("FileDescriptor.SeekOrigin.description") {
    [FileDescriptor.SeekOrigin.start, .current, .end].map { $0.description }
  }
  probe("FileDescriptor.SeekOrigin.debugDescription") {
    [FileDescriptor.SeekOrigin.start, .current, .end].map { $0.debugDescription }
  }

  probe("FileDescriptor.open(_:_:options:permissions:retryOnInterrupt:)") {
    var out: [String] = []
    for i in 0..<16 {
      let path = rowFile("open-\(i)")
      let mode: FileDescriptor.AccessMode = [.readOnly, .writeOnly, .readWrite][rowRng.below(3)]
      let options: FileDescriptor.OpenOptions = [[], [.create], [.create, .truncate], [.create, .exclusiveCreate]][rowRng.below(4)]
      do {
        let fd = try FileDescriptor.open(path, mode, options: options, permissions: .ownerReadWrite)
        out.append("opened \(fd.rawValue >= 0)")
        try fd.close()
      } catch let e as Errno {
        out.append("errno \(e.rawValue)")
      }
    }
    return out
  }

  probe("FileDescriptor.close()") {
    let fd = try FileDescriptor.open(rowFile("close"), .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
    try fd.close()
    do { try fd.close(); return ["second close: no error"] } catch let e as Errno { return ["second close: errno \(e.rawValue)"] }
  }

  probe("FileDescriptor.closeAfter(_:)") {
    let fd = try FileDescriptor.open(rowFile("closeafter"), .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
    let value = try fd.closeAfter { 42 }
    return ["returned \(value)"]
  }

  probe("FileDescriptor.seek(offset:from:)") {
    let fd = try FileDescriptor.open(rowFile("seek"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
    defer { try? fd.close() }
    let bytes = genBytes(64)
    _ = try bytes.withUnsafeBytes { try fd.write($0) }
    let off = Int64(rowRng.below(64))
    return ["start \(try fd.seek(offset: off, from: .start))", "current \(try fd.seek(offset: -2, from: .current))",
            "end \(try fd.seek(offset: 0, from: .end))"]
  }

  probe("FileDescriptor.lseek(offset:from:)") {
    let fd = try FileDescriptor.open(rowFile("lseek"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
    defer { try? fd.close() }
    _ = try genBytes(32).withUnsafeBytes { try fd.write($0) }
    // 1.8.1 marks lseek unavailable, renamed to seek: the row is probed through seek.
    return ["alias of seek(offset:from:)", "end \(try fd.seek(offset: 0, from: .end))", "start \(try fd.seek(offset: 5, from: .start))"]
  }

  probe("FileDescriptor.write(_:retryOnInterrupt:)") {
    let fd = try FileDescriptor.open(rowFile("write"), .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
    defer { try? fd.close() }
    let bytes = genBytes(100 + rowRng.below(900))
    let n = try bytes.withUnsafeBytes { try fd.write($0) }
    return ["written \(n) of \(bytes.count)"]
  }

  probe("FileDescriptor.read(into:retryOnInterrupt:)") {
    let bytes = genBytes(300)
    let w = try FileDescriptor.open(rowFile("read"), .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
    _ = try bytes.withUnsafeBytes { try w.write($0) }
    try w.close()
    let r = try FileDescriptor.open(rowFile("read"), .readOnly)
    defer { try? r.close() }
    var back = [UInt8](repeating: 0, count: 512)
    let n = try back.withUnsafeMutableBytes { try r.read(into: $0) }
    return ["read \(n)", "equal \(Array(back[0..<n]) == bytes)"]
  }

  probe("FileDescriptor.read(fromAbsoluteOffset:into:retryOnInterrupt:)") {
    let bytes = genBytes(200)
    let w = try FileDescriptor.open(rowFile("aread"), .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
    _ = try bytes.withUnsafeBytes { try w.write($0) }
    try w.close()
    let r = try FileDescriptor.open(rowFile("aread"), .readOnly)
    defer { try? r.close() }
    var back = [UInt8](repeating: 0, count: 50)
    let n = try back.withUnsafeMutableBytes { try r.read(fromAbsoluteOffset: 70, into: $0) }
    return ["read \(n)", "equal \(Array(back[0..<n]) == Array(bytes[70..<(70 + n)]))"]
  }

  probe("FileDescriptor.pread(fromAbsoluteOffset:into:retryOnInterrupt:)") {
    let bytes = genBytes(200)
    let w = try FileDescriptor.open(rowFile("pread"), .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
    _ = try bytes.withUnsafeBytes { try w.write($0) }
    try w.close()
    let r = try FileDescriptor.open(rowFile("pread"), .readOnly)
    defer { try? r.close() }
    var back = [UInt8](repeating: 0, count: 50)
    // 1.8.1 marks pread unavailable, renamed to read: the row is probed through read(fromAbsoluteOffset:into:).
    let n = try back.withUnsafeMutableBytes { try r.read(fromAbsoluteOffset: 10, into: $0) }
    return ["alias of read(fromAbsoluteOffset:into:)", "read \(n)", "equal \(Array(back[0..<n]) == Array(bytes[10..<(10 + n)]))"]
  }

  probe("FileDescriptor.write(toAbsoluteOffset:_:retryOnInterrupt:)") {
    let fd = try FileDescriptor.open(rowFile("woff"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
    defer { try? fd.close() }
    let bytes = genBytes(16)
    let n = try bytes.withUnsafeBytes { try fd.write(toAbsoluteOffset: 8, $0) }
    return ["written \(n)"]
  }

  probe("FileDescriptor.pwrite(toAbsoluteOffset:into:retryOnInterrupt:)") {
    let fd = try FileDescriptor.open(rowFile("pwrite"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
    defer { try? fd.close() }
    let bytes = genBytes(16)
    // 1.8.1 marks pwrite unavailable, renamed to write: the row is probed through write(toAbsoluteOffset:_:).
    let n = try bytes.withUnsafeBytes { try fd.write(toAbsoluteOffset: 4, $0) }
    return ["alias of write(toAbsoluteOffset:_:)", "written \(n)"]
  }

  probe("FileDescriptor.writeAll(_:)") {
    let fd = try FileDescriptor.open(rowFile("writeall"), .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
    defer { try? fd.close() }
    let bytes = genBytes(77)
    try fd.writeAll(bytes)
    return ["writeAll ok \(bytes.count)"]
  }

  probe("FileDescriptor.writeAll(toAbsoluteOffset:_:)") {
    let fd = try FileDescriptor.open(rowFile("writeallat"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
    defer { try? fd.close() }
    let bytes = genBytes(19)
    try fd.writeAll(toAbsoluteOffset: 3, bytes)
    return ["writeAll at ok \(bytes.count)"]
  }

  probe("FileDescriptor.duplicate(as:retryOnInterrupt:)") {
    let fd = try FileDescriptor.open(rowFile("dup"), .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
    defer { try? fd.close() }
    let copy = try fd.duplicate(as: FileDescriptor(rawValue: 60))
    defer { try? copy.close() }
    return ["duplicate \(copy.rawValue)"]
  }

  probe("FileDescriptor.pipe()") {
    let (r, w) = try FileDescriptor.pipe()
    defer { try? r.close(); try? w.close() }
    let bytes = genBytes(40)
    _ = try bytes.withUnsafeBytes { try w.write($0) }
    try w.close()
    var back = [UInt8](repeating: 0, count: 64)
    let n = try back.withUnsafeMutableBytes { try r.read(into: $0) }
    return ["pipe read \(n)", "equal \(Array(back[0..<n]) == bytes)"]
  }

  probe("FileDescriptor.resize(to:retryOnInterrupt:)") {
    let fd = try FileDescriptor.open(rowFile("resize"), .readWrite, options: [.create, .truncate], permissions: .ownerReadWrite)
    defer { try? fd.close() }
    try fd.resize(to: 4096)
    return ["size \(try fd.seek(offset: 0, from: .end))"]
  }

  // FilePath: the initialisers, the members, and the component view, on generated paths.
  probe("FilePath.init()") { pathObs(FilePath()) }
  probe("FilePath.init(_:)") { (0..<40).flatMap { _ in pathObs(FilePath(rowPath())) } }
  probe("FilePath.init(cString:)") { (0..<20).flatMap { _ in pathObs(FilePath(cString: rowPath())) } }
  probe("FilePath.init(stringLiteral:)") { (0..<20).flatMap { _ in pathObs(FilePath(stringLiteral: rowPath())) } }
  probe("FilePath.init(platformString:)") { (0..<20).flatMap { _ in pathObs(FilePath(platformString: rowPath())) } }
  probe("FilePath.init(root:_:)") {
    (0..<10).flatMap { _ in pathObs(FilePath(root: FilePath.Root(stringLiteral: "/"), FilePath(rowPath()).components[...])) }
  }
  probe("FilePath.init(root:components:)") {
    let parts = FilePath("/a/bc/x.y").components
    return (0..<10).flatMap { _ in pathObs(FilePath(root: nil, components: parts.first!, parts.last!)) }
  }
  probe("FilePath.withCString(_:)") { (0..<20).map { _ in FilePath(rowPath()).withCString { String(cString: $0) } } }
  probe("FilePath.withPlatformString(_:)") { (0..<20).map { _ in FilePath(rowPath()).withPlatformString { String(cString: $0) } } }
  probe("FilePath.debugDescription") { (0..<20).map { _ in FilePath(rowPath()).debugDescription } }
  probe("FilePath.description") { (0..<20).map { _ in FilePath(rowPath()).description } }
  probe("FilePath.length") { (0..<20).map { _ in FilePath(rowPath()).length.description } }
  probe("FilePath.append(_:)") {
    (0..<20).map { _ in var p = FilePath(rowPath()); p.append(rowPath()); return p.description }
  }
  probe("FilePath.ends(with:)") { (0..<20).map { _ in FilePath(rowPath()).ends(with: FilePath(rowName())).description } }
  probe("FilePath.starts(with:)") { (0..<20).map { _ in FilePath(rowPath()).starts(with: FilePath(rowName())).description } }
  probe("FilePath.lexicallyNormalize()") { (0..<20).map { _ in var p = FilePath(rowPath()); p.lexicallyNormalize(); return p.description } }
  probe("FilePath.push(_:)") { (0..<20).map { _ in var p = FilePath(rowPath()); p.push(FilePath(rowPath())); return p.description } }
  probe("FilePath.removeAll(keepingCapacity:)") {
    (0..<10).map { _ in var p = FilePath(rowPath()); p.removeAll(keepingCapacity: true); return p.description }
  }
  probe("FilePath.removeLastComponent()") {
    (0..<20).map { _ in var p = FilePath(rowPath()); let r = p.removeLastComponent(); return "\(r) \(p.description)" }
  }
  probe("FilePath.removePrefix(_:)") {
    (0..<20).map { _ in var p = FilePath(rowPath()); p.removePrefix(FilePath(rowName())); return p.description }
  }
  probe("FilePath.reserveCapacity(_:)") { (0..<10).map { _ in var p = FilePath(rowPath()); p.reserveCapacity(128); return p.description } }
  // 1.8.1 marks basename and dirname unavailable, renamed to lastComponent and removingLastComponent().
  probe("FilePath.basename") { ["alias of lastComponent"] + (0..<20).map { _ in FilePath(rowPath()).lastComponent?.string ?? "nil" } }
  probe("FilePath.components") { (0..<20).map { _ in FilePath(rowPath()).components.map { $0.string }.joined(separator: "|") } }
  probe("FilePath.dirname") { ["alias of removingLastComponent()"] + (0..<20).map { _ in FilePath(rowPath()).removingLastComponent().description } }
  probe("FilePath.isAbsolute") { (0..<20).map { _ in FilePath(rowPath()).isAbsolute.description } }
  probe("FilePath.isEmpty") { (0..<20).map { _ in FilePath(rowPath()).isEmpty.description } }
  probe("FilePath.isLexicallyNormal") { (0..<20).map { _ in FilePath(rowPath()).isLexicallyNormal.description } }
  probe("FilePath.isRelative") { (0..<20).map { _ in FilePath(rowPath()).isRelative.description } }
  probe("FilePath.lastComponent") { (0..<20).map { _ in FilePath(rowPath()).lastComponent?.string ?? "nil" } }
  probe("FilePath.root") { (0..<20).map { _ in FilePath(rowPath()).root?.string ?? "nil" } }
  probe("FilePath.stem") { (0..<20).map { _ in FilePath(rowPath()).stem ?? "nil" } }
  probe("FilePath.string") { (0..<20).map { _ in FilePath(rowPath()).string } }

  // FilePath.Component, its kinds and the component view.
  probe("FilePath.Component.init(stringLiteral:)") { (0..<20).map { _ in describeBoth(FilePath.Component(stringLiteral: rowName())).joined(separator: " ") } }
  probe("FilePath.Component.withPlatformString(_:)") { (0..<20).map { _ in FilePath.Component(stringLiteral: rowName()).withPlatformString { String(cString: $0) } } }
  probe("FilePath.Component.debugDescription") { (0..<20).map { _ in FilePath.Component(stringLiteral: rowName()).debugDescription } }
  probe("FilePath.Component.description") { (0..<20).map { _ in FilePath.Component(stringLiteral: rowName()).description } }
  probe("FilePath.Component.kind") { (0..<20).map { _ in describeBoth(FilePath.Component(stringLiteral: rowName()).kind).joined(separator: " ") } }
  probe("FilePath.Component.stem") { (0..<20).map { _ in FilePath.Component(stringLiteral: rowName()).stem ?? "nil" } }
  probe("FilePath.Component.string") { (0..<20).map { _ in FilePath.Component(stringLiteral: rowName()).string } }
  probe("FilePath.ComponentView.index(after:)") {
    let cv = FilePath("/a/bc/x.y").components
    return [cv.startIndex, cv.index(after: cv.startIndex), cv.index(after: cv.index(after: cv.startIndex))].map { "\($0)" }
  }
  probe("FilePath.ComponentView.index(before:)") {
    let cv = FilePath("/a/bc/x.y").components
    return [cv.endIndex, cv.index(before: cv.endIndex), cv.index(before: cv.index(before: cv.endIndex))].map { "\($0)" }
  }
  probe("FilePath.ComponentView.init()") { describeBoth(FilePath.ComponentView()) + ["\(FilePath.ComponentView().isEmpty)"] }
  probe("FilePath.ComponentView.replaceSubrange(_:with:)") {
    var cv = FilePath("/a/bc/x.y").components
    cv.replaceSubrange(cv.startIndex..<cv.endIndex, with: [FilePath.Component(stringLiteral: "z")])
    return [cv.map { $0.string }.joined(separator: "|")]
  }
  probe("FilePath.ComponentView.startIndex") { [FilePath("/a/bc").components.startIndex].map { "\($0)" } }
  probe("FilePath.ComponentView.endIndex") { [FilePath("/a/bc").components.endIndex].map { "\($0)" } }
  probe("FilePath.Root.init(stringLiteral:)") { describeBoth(FilePath.Root(stringLiteral: "/")) }
  probe("FilePath.Root.withPlatformString(_:)") { [FilePath.Root(stringLiteral: "/").withPlatformString { String(cString: $0) }] }
  probe("FilePath.Root.debugDescription") { [FilePath.Root(stringLiteral: "/").debugDescription] }
  probe("FilePath.Root.description") { [FilePath.Root(stringLiteral: "/").description] }
  probe("FilePath.Root.string") { [FilePath.Root(stringLiteral: "/").string] }

  // String: the conversions from FilePath and from the platform string.
  probe("String.init(_:)") { (0..<20).map { _ in String(FilePath(rowPath())) } }
  probe("String.init(decoding:)") { (0..<20).map { _ in String(decoding: FilePath(rowPath())) } }
  probe("String.init(platformString:)") { (0..<20).map { _ in rowName().withCString { String(platformString: $0) } } }
  probe("String.withPlatformString(_:)") { (0..<20).map { _ in rowName().withPlatformString { String(cString: $0) } } }

  // Types: the layout of each type the rows name.
  shape("Errno", Errno.self)
  shape("FileDescriptor", FileDescriptor.self)
  shape("FileDescriptor.AccessMode", FileDescriptor.AccessMode.self)
  shape("FileDescriptor.OpenOptions", FileDescriptor.OpenOptions.self)
  shape("FileDescriptor.SeekOrigin", FileDescriptor.SeekOrigin.self)
  shape("FilePath", FilePath.self)
  shape("FilePath.Component", FilePath.Component.self)
  shape("FilePath.Component.Kind", FilePath.Component.Kind.self)
  shape("FilePath.ComponentView", FilePath.ComponentView.self)
  shape("FilePath.ComponentView.Index", FilePath.ComponentView.Index.self)
  shape("FilePath.ComponentView.Element", FilePath.ComponentView.Element.self)
  shape("FilePath.Root", FilePath.Root.self)
  shape("FilePermissions", FilePermissions.self)
  shape("CModeT", CModeT.self)
  shape("CInterop", CInterop.self)
  shape("CInterop.Char", CInterop.Char.self)
  shape("CInterop.Mode", CInterop.Mode.self)
  shape("CInterop.PlatformChar", CInterop.PlatformChar.self)
  shape("CInterop.PlatformUnicodeEncoding", CInterop.PlatformUnicodeEncoding.self)
  shape("Mach", Mach.self)
  shape("Mach.PortRightError", Mach.PortRightError.self)
  shape("Mach.ReceiveRight", Mach.ReceiveRight.self)
  shape("Mach.SendRight", Mach.SendRight.self)
  shape("Mach.SendOnceRight", Mach.SendOnceRight.self)
  shape("Mach.Port", Mach.Port<Mach.ReceiveRight>.self)
  // A marker protocol with no requirements and no value: the compiler checks the constraint Mach.Port<RightType: MachPortRight>.
  notExercised("MachPortRight", "marker protocol with no requirements and no value to probe; the Mach.Port constraint is checked by the compiler in both builds")

  // Mach ports: the receive and send rights on the host; the port guard paths are not run here.
  probe("Mach.Port.init()") {
    let port = Mach.Port<Mach.ReceiveRight>()
    return [port.withBorrowedName { "named \($0 != 0)" }]
  }
  probe("Mach.Port.makeSendRight()") {
    let port = Mach.Port<Mach.ReceiveRight>()
    let send = port.makeSendRight()
    return [send.withBorrowedName { "send named \($0 != 0)" }]
  }
  probe("Mach.Port.makeSendOnceRight()") {
    let port = Mach.Port<Mach.ReceiveRight>()
    let once = port.makeSendOnceRight()
    return [once.withBorrowedName { "once named \($0 != 0)" }]
  }
  probe("Mach.Port.makeSendCount") {
    let port = Mach.Port<Mach.ReceiveRight>()
    let send = port.makeSendRight()
    return ["count \(port.makeSendCount)", send.withBorrowedName { "send named \($0 != 0)" }]
  }
  probe("Mach.Port.copySendRight()") {
    let port = Mach.Port<Mach.ReceiveRight>()
    let send = port.makeSendRight()
    let copy = try send.copySendRight()
    return [copy.withBorrowedName { "copy named \($0 != 0)" }]
  }
  probe("Mach.Port.withBorrowedName(body:)") {
    let port = Mach.Port<Mach.ReceiveRight>()
    return [port.withBorrowedName { "borrowed \($0 != 0)" }]
  }
  notExercised("Mach.Port.init(name:)", "takes ownership of a name the harness must give up; the host run owns its ports, so this row is not run")
  notExercised("Mach.Port.init(name:context:)", "takes ownership of a name with a guard context; not run on the host (see Mach.Port.init(name:))")
  notExercised("Mach.Port.relinquish()", "gives the name away; the host run does not take the path that leaves a port with no owner")
  notExercised("Mach.Port.unguardAndRelinquish()", "needs the guard; a wrong guard kills the process (measured in revision 2), so the guard path is not run")
  notExercised("FilePath.init(from:)", "needs a Decoder; the harness has no Foundation (its JSONDecoder would re-export the module on macOS)")
  probe("Errno.rawValue") { [Errno.notPermitted, Errno.noSuchFileOrDirectory].map { $0.rawValue.description } }
  probe("Errno.description") { [Errno.notPermitted, Errno.noSuchFileOrDirectory].map { $0.description } }
  probe("Errno.debugDescription") { [Errno.notPermitted, Errno.noSuchFileOrDirectory].map { $0.debugDescription } }
  probe("Errno._code") { [Errno.notPermitted, Errno.noSuchFileOrDirectory].map { "\($0._code)" } }
  probe("Errno._domain") { [Errno.notPermitted, Errno.noSuchFileOrDirectory].map { $0._domain } }

  let detailFile = try! FileDescriptor.open("\(runDir)/rows-detail.txt", .writeOnly, options: [.create, .truncate], permissions: .ownerReadWrite)
  try! detailFile.writeAll(Array(rowDetail.utf8))
  try! detailFile.close()
}
