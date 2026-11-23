import Foundation
import _SwiftRevenantFoundationOverlayShims

private func revenant_file_error(_ error: NSError?, _ code: CocoaError.Code) -> NSError {
    return error ?? NSError(domain: NSCocoaErrorDomain, code: code.rawValue, userInfo: nil)
}

extension FileHandle {
    @nonobjc public func readToEnd() throws -> Data? {
        return try read(upToCount: Int.max)
    }

    @nonobjc public func read(upToCount count: Int) throws -> Data? {
        guard self !== FileHandle.nullDevice, count > 0 else {
            return nil
        }
        var error: NSError?
        let data = revenant_file_handle_read(self, count, &error)
        if let failure = error {
            throw failure
        }
        guard let data = data, !data.isEmpty else {
            return nil
        }
        return data
    }

    @nonobjc public func write<T: DataProtocol>(contentsOf data: T) throws {
        guard self !== FileHandle.nullDevice else {
            return
        }
        var checkError: NSError?
        var position: UInt64 = 0
        if !revenant_file_handle_get_offset(self, &position, &checkError) {
            throw revenant_file_error(checkError, .fileWriteUnknown)
        }
        for region in data.regions {
            try region.withUnsafeBytes { bytes in
                guard let base = bytes.baseAddress, !bytes.isEmpty else {
                    return
                }
                let buffer = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: base), count: bytes.count, deallocator: .none)
                var error: NSError?
                if !revenant_file_handle_write(self, buffer, &error) {
                    throw revenant_file_error(error, .fileWriteUnknown)
                }
            }
        }
    }

    @nonobjc public func offset() throws -> UInt64 {
        guard self !== FileHandle.nullDevice else {
            return 0
        }
        var position: UInt64 = 0
        var error: NSError?
        if !revenant_file_handle_get_offset(self, &position, &error) {
            throw revenant_file_error(error, .fileReadUnknown)
        }
        return position
    }

    @nonobjc @discardableResult public func seekToEnd() throws -> UInt64 {
        guard self !== FileHandle.nullDevice else {
            return 0
        }
        var position: UInt64 = 0
        var error: NSError?
        if !revenant_file_handle_seek_to_end(self, &position, &error) {
            throw revenant_file_error(error, .fileReadUnknown)
        }
        return position
    }

    @nonobjc public func seek(toOffset offset: UInt64) throws {
        guard self !== FileHandle.nullDevice else {
            return
        }
        var error: NSError?
        if !revenant_file_handle_seek(self, offset, &error) {
            throw revenant_file_error(error, .fileReadUnknown)
        }
    }

    @nonobjc public func truncate(atOffset offset: UInt64) throws {
        guard self !== FileHandle.nullDevice else {
            return
        }
        var error: NSError?
        if !revenant_file_handle_truncate(self, offset, &error) {
            throw revenant_file_error(error, .fileWriteUnknown)
        }
    }

    @nonobjc public func synchronize() throws {
        guard self !== FileHandle.nullDevice else {
            return
        }
        var error: NSError?
        if !revenant_file_handle_synchronize(self, &error) {
            throw revenant_file_error(error, .fileWriteUnknown)
        }
    }

    @nonobjc public func close() throws {
        guard self !== FileHandle.nullDevice else {
            return
        }
        var error: NSError?
        if !revenant_file_handle_close(self, &error) {
            throw revenant_file_error(error, .fileWriteUnknown)
        }
    }
}
