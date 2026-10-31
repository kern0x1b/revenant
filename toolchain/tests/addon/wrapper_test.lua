import("fixtures")

function failures(opt)
    local wrapper = import("apple.wrapper", {rootdir = opt.modules, anonymous = true})
    local found = {}
    local folder = fixtures.scratch()
    local lib = path.join(folder, "lib")
    os.mkdir(path.join(lib, "swift"))
    local listed = {"libswiftCryptoKit.dylib", "libswiftCryptoKit.a", "libswiftCore.dylib", "libc++.1.dylib"}
    for _, name in ipairs(listed) do
        io.writefile(path.join(lib, name), "")
    end
    wrapper.keep_own_libraries(lib, {"swiftCryptoKit"})
    for _, name in ipairs({"libswiftCryptoKit.dylib", "libswiftCryptoKit.a"}) do
        if not os.isfile(path.join(lib, name)) then
            table.insert(found, "a wrapper keeps the library its own target builds: " .. name .. " is gone")
        end
    end
    for _, name in ipairs({"libswiftCore.dylib", "libc++.1.dylib"}) do
        if os.isfile(path.join(lib, name)) then
            table.insert(found, "a wrapper installs no copy of the library of a package it depends on: " .. name .. " is still in lib/")
        end
    end
    if not os.isdir(path.join(lib, "swift")) then
        table.insert(found, "a wrapper keeps the swift folder of its modules")
    end
    os.tryrm(folder)
    return found
end
