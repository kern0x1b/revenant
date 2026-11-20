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

local function count(text, needle)
    local total, from = 0, 1
    while true do
        local at = text:find(needle, from, true)
        if not at then
            return total
        end
        total = total + 1
        from = at + #needle
    end
end

local function callback(source, opener, closer)
    local start = source:find(opener, 1, true)
    if not start then
        return ""
    end
    local stop = closer and source:find(closer, start + #opener, 1, true) or #source
    return source:sub(start, stop)
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

    local tools, absent = located.load_tools(toolchain, {ld64 = installed("/store/ld64"), llvm = installed("/store/llvm")})
    check(tools.ld64 == path.join("/store/ld64", "bin", "ld"), "an installed ld64 does not give its bin/ld: " .. tostring(tools.ld64))
    check(tools.llvm == path.join("/store/llvm", "bin", "clang"), "an installed llvm does not give its bin/clang: " .. tostring(tools.llvm))
    check(empty(absent), "installed packages are reported absent")

    local message = raises(function ()
        located.load_tools(toolchain, {ld64 = installed(nil), llvm = installed("/store/llvm")})
    end)
    check(message ~= nil and message:find("ld64", 1, true) and message:find("956.6", 1, true) and message:find("no install folder", 1, true),
          "an ld64 without an install folder does not fail the load naming the package and its version: " .. tostring(message))
    check(message == nil or message:find("-fuse-ld=", 1, true), "the failure does not say which flag the missing path would have gone into: " .. tostring(message))

    message = raises(function ()
        located.load_tools(toolchain, {ld64 = installed("/store/ld64"), llvm = installed(nil)})
    end)
    check(message ~= nil and message:find("llvm", 1, true) and message:find("23.1.3", 1, true),
          "an llvm without an install folder does not fail the load naming the package and its version: " .. tostring(message))

    local lenient
    message = raises(function ()
        tools, lenient = located.check_tools(toolchain, {ld64 = installed(nil), llvm = installed(nil)})
    end)
    check(message == nil, "the check pass fails for a package without an install folder, which a configure that has not installed it yet must be allowed: " .. tostring(message))
    check(tools.ld64 == nil and tools.llvm == nil, "a package without an install folder gets a tool path: " .. tostring(tools.ld64) .. " " .. tostring(tools.llvm))
    check(lenient.ld64 == "956.6" and lenient.llvm == "23.1.3", "the check pass does not report the packages that have no install folder")

    tools, absent = located.load_tools(toolchain, {})
    check(empty(tools) and empty(absent), "a package nobody required is reported")
    tools, absent = located.load_tools(configured({}), {ld64 = installed(nil), llvm = installed(nil)})
    check(empty(tools) and empty(absent), "a package the toolchain was not configured with is reported")

    local source = io.readfile(path.join(opt.modules, "..", "toolchains", "apple-ios", "xmake.lua"))
    local on_check = callback(source, "on_check(function", "on_load(function")
    local on_load = callback(source, "on_load(function")
    check(on_check:find("apple.located\").check_tools", 1, true) ~= nil and on_check:find("load_tools", 1, true) == nil,
          "on_check of toolchains/apple-ios/xmake.lua does not take its tool paths from located.check_tools alone: the configure that has not installed ld64 yet would stop in the check")
    check(on_load:find("apple.located\").load_tools", 1, true) ~= nil and on_load:find("check_tools", 1, true) == nil,
          "on_load of toolchains/apple-ios/xmake.lua does not take its tool paths from located.load_tools alone: a missing ld64 or llvm would be pasted into a flag as nil/...")
    check(count(source, "installdir(") == 1 and source:find("sdk:installdir()", 1, true) ~= nil,
          "toolchains/apple-ios/xmake.lua calls installdir() itself on something other than the SDK package: a package that is not installed gives nil there")
    return found
end
