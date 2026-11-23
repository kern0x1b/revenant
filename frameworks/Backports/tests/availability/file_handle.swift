import Foundation

enum FileHandleUse {
    static func roundTrip(_ handle: FileHandle, _ data: Data) throws -> Data? {
        try handle.write(contentsOf: data)
        try handle.write(contentsOf: [UInt8](repeating: 0, count: 1))
        try handle.synchronize()
        let end = try handle.seekToEnd()
        let here = try handle.offset()
        try handle.seek(toOffset: min(here, end))
        let prefix = try handle.read(upToCount: data.count)
        let remainder = try handle.readToEnd()
        try handle.truncate(atOffset: end)
        try handle.close()
        try? handle.synchronize()
        return prefix ?? remainder
    }
}
