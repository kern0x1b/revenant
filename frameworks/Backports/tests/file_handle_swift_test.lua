local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local source = path.absolute(path.join(backports, "..", "..", "toolchain", "src", "swift-runtime", "overlay", "Foundation", "FileHandle.swift"))
local fixture = path.join(backports, "tests", "Foundation", "file_handle", "main.swift")

local SHIM = [[
import Foundation

public func revenant_file_handle_read(_ handle: FileHandle, _ length: UInt, _ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Data? {
    do {
        return try handle.__readDataUp(toLength: Int(length))
    } catch let failure {
        error?.pointee = failure as NSError
        return nil
    }
}

public func revenant_file_handle_write(_ handle: FileHandle, _ data: Data, _ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
    do {
        try handle.write(contentsOf: data)
        return true
    } catch let failure {
        error?.pointee = failure as NSError
        return false
    }
}

public func revenant_file_handle_get_offset(_ handle: FileHandle, _ offset: UnsafeMutablePointer<UInt64>, _ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
    do {
        var position: UInt64 = 0
        try handle.__getOffset(&position)
        offset.pointee = position
        return true
    } catch let failure {
        error?.pointee = failure as NSError
        return false
    }
}

public func revenant_file_handle_seek_to_end(_ handle: FileHandle, _ offset: UnsafeMutablePointer<UInt64>, _ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
    do {
        var position: UInt64 = 0
        try handle.__seek(toEndReturningOffset: &position)
        offset.pointee = position
        return true
    } catch let failure {
        error?.pointee = failure as NSError
        return false
    }
}

public func revenant_file_handle_seek(_ handle: FileHandle, _ offset: UInt64, _ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
    do {
        try handle.seek(toOffset: offset)
        return true
    } catch let failure {
        error?.pointee = failure as NSError
        return false
    }
}

public func revenant_file_handle_truncate(_ handle: FileHandle, _ offset: UInt64, _ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
    do {
        try handle.truncate(atOffset: offset)
        return true
    } catch let failure {
        error?.pointee = failure as NSError
        return false
    }
}

public func revenant_file_handle_synchronize(_ handle: FileHandle, _ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
    do {
        try handle.synchronize()
        return true
    } catch let failure {
        error?.pointee = failure as NSError
        return false
    }
}

public func revenant_file_handle_close(_ handle: FileHandle, _ error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
    do {
        try handle.close()
        return true
    } catch let failure {
        error?.pointee = failure as NSError
        return false
    }
}
]]

local EXPECTED = [[
negative count returns nil: ok
empty write on an open handle: ok
empty write after close throws: error
read after close throws: error
]]

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc"}, args))
end

function main()
    local out = workspace.run("backports-tests", "FileHandleSwift")
    local shim = path.join(out, "shim.swift")
    local module = path.join(out, "modules")
    os.mkdir(module)
    io.writefile(shim, SHIM)
    local object = path.join(out, "shim.o")
    swiftc({"-parse-as-library", "-emit-module", "-module-name", "_SwiftRevenantFoundationOverlayShims",
            "-emit-module-path", path.join(module, "_SwiftRevenantFoundationOverlayShims.swiftmodule"),
            "-emit-object", "-o", object, shim})
    local probe = path.join(out, "probe")
    swiftc({"-I", module, source, fixture, object, "-o", probe})
    local file = path.join(out, "data.bin")
    os.rm(file)
    local log = path.join(out, "probe.log")
    local status = os.execv(probe, {file}, {try = true, stdout = log, stderr = log})
    assert(status == 0, "the FileHandle probe did not run: " .. io.readfile(log))
    local got = io.readfile(log)
    assert(got == EXPECTED, "the FileHandle Swift overlay differs from the expected behaviour in " .. out .. ":\n" .. got)
    os.rm(file)
end
