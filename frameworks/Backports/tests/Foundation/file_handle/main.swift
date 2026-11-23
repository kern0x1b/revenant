import Foundation

func outcome(_ body: () throws -> Void) -> String {
    do {
        try body()
        return "ok"
    } catch {
        return "error"
    }
}

let path = CommandLine.arguments[1]
FileManager.default.createFile(atPath: path, contents: Data([1, 2, 3]), attributes: nil)
let handle = FileHandle(forUpdatingAtPath: path)!

let negative = outcome {
    if try handle.read(upToCount: -1) != nil {
        throw NSError(domain: "probe", code: 1, userInfo: nil)
    }
}
print("negative count returns nil: \(negative)")

let emptyOnOpen = outcome {
    try handle.write(contentsOf: Data())
}
print("empty write on an open handle: \(emptyOnOpen)")

try handle.close()
let emptyAfterClose = outcome {
    try handle.write(contentsOf: Data())
}
print("empty write after close throws: \(emptyAfterClose)")

let readAfterClose = outcome {
    _ = try handle.read(upToCount: 1)
}
print("read after close throws: \(readAfterClose)")
