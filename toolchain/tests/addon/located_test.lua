local function raises(action)
    local message
    try {
        action,
        catch {
            function (raised)
                message = tostring(raised)
            end
        }
    }
    return message
end

local function empty(map)
    for _ in pairs(map) do
        return false
    end
    return true
end

local function configured(values)
    return {config = function (_, name)
        return values[name]
    end}
end

local function installed(folder)
    return {installdir = function ()
        return folder
    end}
end

function failures(opt)
    local found = {}
    local function check(condition, message)
        if not condition then
            table.insert(found, message)
        end
    end
    local located = import("@addon.revenant.apple.located", {anonymous = true})
    local toolchain = configured({ld64 = "956.6", llvm = "23.1.3"})

    local tools, absent = located.tools(toolchain, {ld64 = installed("/store/ld64"), llvm = installed("/store/llvm")}, true)
    check(tools.ld64 == path.join("/store/ld64", "bin", "ld"), "an installed ld64 does not give its bin/ld: " .. tostring(tools.ld64))
    check(tools.llvm == path.join("/store/llvm", "bin", "clang"), "an installed llvm does not give its bin/clang: " .. tostring(tools.llvm))
    check(empty(absent), "installed packages are reported absent")

    local message = raises(function ()
        located.tools(toolchain, {ld64 = installed(nil), llvm = installed("/store/llvm")}, true)
    end)
    check(message ~= nil and message:find("ld64", 1, true) and message:find("956.6", 1, true) and message:find("no install folder", 1, true),
          "an ld64 without an install folder does not fail naming the package and its version: " .. tostring(message))
    check(message == nil or message:find("-fuse-ld=", 1, true), "the failure does not say which flag the missing path would have gone into: " .. tostring(message))

    message = raises(function ()
        located.tools(toolchain, {ld64 = installed("/store/ld64"), llvm = installed(nil)}, true)
    end)
    check(message ~= nil and message:find("llvm", 1, true) and message:find("23.1.3", 1, true),
          "an llvm without an install folder does not fail naming the package and its version: " .. tostring(message))

    local lenient
    tools, lenient = located.tools(toolchain, {ld64 = installed(nil), llvm = installed(nil)}, false)
    check(tools.ld64 == nil and tools.llvm == nil, "a package without an install folder gets a tool path: " .. tostring(tools.ld64) .. " " .. tostring(tools.llvm))
    check(lenient.ld64 == "956.6" and lenient.llvm == "23.1.3", "the check pass does not report the packages that have no install folder")

    tools, absent = located.tools(toolchain, {}, true)
    check(empty(tools) and empty(absent), "a package nobody required is reported")
    tools, absent = located.tools(configured({}), {ld64 = installed(nil), llvm = installed(nil)}, true)
    check(empty(tools) and empty(absent), "a package the toolchain was not configured with is reported")

    local source = io.readfile(path.join(opt.modules, "..", "toolchains", "apple-ios", "xmake.lua"))
    check(source:find("apple.located", 1, true) ~= nil, "toolchains/apple-ios/xmake.lua does not take the ld64 and llvm paths from apple.located")
    check(source:find(":installdir(), \"bin\"", 1, true) == nil, "toolchains/apple-ios/xmake.lua builds a tool path from a package's installdir itself, which is nil when the package is not installed")
    return found
end
