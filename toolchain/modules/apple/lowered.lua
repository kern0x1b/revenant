local LOCK_MACRO = "#define OS_UNFAIR_LOCK_AVAILABILITY \\\n\t\t__API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(3.0))"
local LOCK_EMPTY = "#define OS_UNFAIR_LOCK_AVAILABILITY"

local function lowered_lock(sdk)
    local text = io.readfile(path.join(sdk, "usr", "include", "os", "lock.h"))
    local start, stop = text:find(LOCK_MACRO, 1, true)
    if not start then
        raise("the iPhoneOS SDK at %s declares os/lock.h without the OS_UNFAIR_LOCK_AVAILABILITY macro the backports lower", sdk)
    end
    return text:sub(1, start - 1) .. LOCK_EMPTY .. text:sub(stop + 1)
end

function overlay(sdk, out)
    local directory = path.join(sdk, "usr", "include", "os")
    local copy = path.join(out, "os", "lock.h")
    local vfs = path.join(out, "vfs.yaml")
    if os.isfile(vfs) and os.isfile(copy) and io.readfile(copy) == lowered_lock(sdk) then
        return vfs
    end
    os.mkdir(path.join(out, "os"))
    io.writefile(copy, lowered_lock(sdk))
    io.writefile(vfs, string.format([[
{
  "version": 0,
  "case-sensitive": false,
  "roots": [
    {
      "name": "%s",
      "type": "directory",
      "contents": [
        {"name": "lock.h", "type": "file", "external-contents": "%s"}
      ]
    }
  ]
}
]], directory, copy))
    return vfs
end
