if get_config("component") ~= "" or not is_plat("iphoneos") then
    return
end

local SRC = os.scriptdir()

target("apple-compat")
    set_kind("static")
    set_default(false)
    add_rules("@addon/revenant/apple-ios")
    add_cflags("-Os", "-fno-builtin", "-fvisibility=hidden")
    on_load(function (target)
        local compat = import("@addon.revenant.apple.compat", {anonymous = true})
        local platform = import("@addon.revenant.apple.platform", {anonymous = true})
        local symbols, sharing = compat.needed(platform.deployment(target))
        for _, symbol in ipairs(symbols) do
            target:add("files", path.join(SRC, "src", symbol .. ".c"))
            local header = path.join(SRC, "include", "revenant", symbol .. ".h")
            if os.isfile(header) then
                target:add("headerfiles", header, {prefixdir = "revenant"})
            end
        end
        target:data_set("apple-compat.symbols", symbols)
        target:data_set("apple-compat.sharing", sharing)
    end)
    after_install(function (target)
        local installdir = target:installdir()
        local include = path.join(installdir, "include")
        local module = path.join(include, "RevenantCompat")
        os.mkdir(module)
        local lines = {"// Written by revenant@apple-compat: the shims this release needs, as one module a Swift file can import."}
        for _, symbol in ipairs(target:data("apple-compat.symbols") or {}) do
            if os.isfile(path.join(SRC, "include", "revenant", symbol .. ".h")) then
                table.insert(lines, "#include <toolchain/" .. symbol .. ".h>")
            end
        end
        io.writefile(path.join(module, "shims.h"), table.concat(lines, "\n") .. "\n")
        io.writefile(path.join(module, "module.modulemap"), "module RevenantCompat {\n    header \"shims.h\"\n    export *\n}\n")
        local sharing = target:data("apple-compat.sharing") or {}
        if #sharing > 0 then
            local folder = path.join(installdir, "share", "apple-compat", "process-wide")
            os.mkdir(folder)
            os.vcp(path.join(SRC, "src", "*.h"), folder .. "/")
            for _, symbol in ipairs(sharing) do
                os.vcp(path.join(SRC, "src", symbol .. ".c"), folder .. "/")
            end
        end
    end)
    add_tests("os_unfair_lock")
    on_test(function (target, opt)
        local ok = os.execv(os.programfile(), {"l", "-P", path.join(SRC, "..", "..", ".."), path.join(SRC, "tests", "os_unfair_lock", "os_unfair_lock_test.lua")}, {try = true, curdir = path.join(SRC, "..", "..", "..")})
        if ok ~= 0 then
            opt.errors = "os_unfair_lock failed"
        end
        return ok == 0
    end)
