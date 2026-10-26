import("fixtures")

local FAKE_SDK = [[
package("fakesdk")
    set_kind("toolchain")
    on_install("@macosx", function (package)
        local sdk = path.join(package:installdir(), "Developer.app", "Contents", "Developer", "Platforms",
                              "iPhoneOS.platform", "Developer", "SDKs", "iPhoneOS16.4.sdk")
        os.mkdir(sdk)
        io.writefile(path.join(sdk, "SDKSettings.json"), "{}")
    end)
]]

local FAKE_LD64 = [[
package("fakeld64")
    set_kind("toolchain")
    on_install("@macosx", function (package)
        os.mkdir(package:installdir("bin"))
        io.writefile(path.join(package:installdir("bin"), "ld"), "#!/bin/sh\n")
    end)
]]

local FAKE_LLVM = [[
package("fakellvm")
    set_kind("toolchain")
    on_install("@macosx", function (package)
        os.mkdir(package:installdir("bin"))
        io.writefile(path.join(package:installdir("bin"), "clang"), "#!/bin/sh\n")
    end)
]]

local function fake_repo(folder)
    local repo = path.join(folder, "repo")
    for name, text in pairs({fakesdk = FAKE_SDK, fakeld64 = FAKE_LD64, fakellvm = FAKE_LLVM}) do
        local dir = path.join(repo, "packages", name:sub(1, 1), name)
        os.mkdir(dir)
        io.writefile(path.join(dir, "xmake.lua"), text)
    end
    return repo
end

local BEFORE_ON_CHECK = path.join(os.scriptdir(), "toolchain_check", "apple-ios-before-on-check.lua")

local function older_toolchain_file(folder)
    local file = path.join(folder, "apple-ios-before.lua")
    os.cp(BEFORE_ON_CHECK, file)
    return file
end

local function project_file(project, repo, toolchain_lua)
    io.writefile(path.join(project, "xmake.lua"), table.concat({
        "add_repositories(\"fake " .. repo .. "\")",
        "includes(\"" .. toolchain_lua .. "\")",
        "set_config(\"apple_minimum\", \"6.1.3\")",
        "add_requires(\"fake@fakesdk\", {alias = \"iphoneos-sdk\"})",
        "add_requires(\"fake@fakeld64\", {alias = \"ld64\"})",
        "add_requires(\"fake@fakellvm\", {alias = \"llvm\"})",
        "add_requireconfs(\"*|iphoneos-sdk|ld64|llvm\", {configs = {toolchains =",
        "    \"apple-ios[minimum=6.1.3,sdk=16.4,ld64=1.0,llvm=1.0,optimize=packages,flags=test]\"}})",
        "target(\"nop\")",
        "    set_kind(\"phony\")",
        "    add_packages(\"iphoneos-sdk\", \"ld64\", \"llvm\")",
        ""
    }, "\n"))
end

local function resolve(label, folder, repo, toolchain_lua)
    local run = path.join(folder, label)
    local project, store = path.join(run, "project"), path.join(run, "store")
    os.mkdir(project)
    os.mkdir(store)
    project_file(project, repo, toolchain_lua)
    local envs = {XMAKE_GLOBALDIR = store, XMAKE_MAIN_REPO = fixtures.empty_repository(folder)}
    local log = path.join(run, "resolve.log")
    local ok, code = try {function ()
        return true, os.execv(os.programfile(), {"f", "-P", project, "-c", "-y"}, {curdir = project, envs = envs, stdout = log, stderr = log, timeout = 60000, try = true})
    end}
    local told = io.readfile(log) or ""
    return ok and code == 0, told:find("toolchain(\"apple-ios\"): not found", 1, true) ~= nil, told
end

function failures(opt)
    local found = {}
    local checkout = path.absolute(path.join(opt.modules, ".."))
    local folder = fixtures.scratch()
    local repo = fake_repo(folder)

    local ok_new, not_found_new, told_new = resolve("new", folder, repo, path.join(checkout, "toolchains", "apple-ios", "xmake.lua"))
    if not ok_new then
        table.insert(found, "the checkout's own toolchains/apple-ios/xmake.lua should let a fresh, never-installed SDK resolve, and did not: " .. told_new:gsub("\n", " | "):sub(1, 500))
    end
    if not_found_new then
        table.insert(found, "the checkout's own toolchains/apple-ios/xmake.lua still answers toolchain(\"apple-ios\"): not found on a fresh install")
    end

    local older_file = older_toolchain_file(folder)
    local ok_old, not_found_old = resolve("old", folder, repo, older_file)
    if ok_old then
        table.insert(found, "toolchain_check/apple-ios-before-on-check.lua (the apple-ios toolchain before its on_check fix) was expected to fail the same fresh install the checkout's current one now passes - it did not, so this test's negative control does not reproduce the bug it exists to catch")
    end
    if not ok_old and not not_found_old then
        table.insert(found, "toolchain_check/apple-ios-before-on-check.lua failed for a different reason than the one this test exists to name")
    end

    os.tryrm(folder)
    return found
end
