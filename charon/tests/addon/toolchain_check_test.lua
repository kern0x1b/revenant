import("fixtures")

-- Whether toolchain("apple-ios")'s on_check answers honestly about a package graph that names the SDK
-- but has not installed it yet (package.lua's own _check_package_toolchains runs before packages
-- install - its own comment, xmake PR #5466). Entirely local and network-free: three tiny fake
-- packages stand in for iphoneos-sdk/ld64/llvm (aliased to those exact names, which is all parts()
-- reads), each writing only the one file on_check/on_load look for, and the toolchain itself is
-- read directly from the checkout by path - no addon install, no real SDK/llvm/ld64, no network, an
-- empty XMAKE_GLOBALDIR each run so every package is genuinely "never installed" without forcing a
-- digest change or hard-linking anything.
--
-- Both resolves read a real toolchains/apple-ios/xmake.lua, never a copy of its on_check maintained
-- here: the "new" one is the file this checkout actually ships, unmodified, by path; the "old" one is
-- what git itself says that file held one commit before whichever commit last touched it - read with
-- `git show`, not retyped, so a real regression in the shipped file is what turns this test red, not
-- a second, separately-maintained idea of what it should say.

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

-- The commit right before the fix (14ff46c3, "toolchain(apple-ios): don't require the SDK already
-- installed to pass on_check") - pinned by hash, not derived, after two derivations each failed a
-- reproduced case: "the file's last touch" (round 2) breaks on any later, unrelated commit to this
-- file; a pickaxe on the string "SDKSettings.json" (round 3) breaks the same way the moment a later
-- commit touches *that particular string* anywhere else in the file (on_load's own occurrence, most
-- plausibly) without touching the fix itself - reviewed and reproduced both times,
-- coordination/reviews/2026-09-27-charon-7f181ae3.md and -a475687c.md. A hash cannot be fooled by a
-- later commit's content the way a derivation can, at the one cost a derivation does not have: if
-- 14ff46c3 is ever rebased (a different band's merge, a history rewrite), this hash must be updated
-- to whatever it becomes, by hand - the assert below fails loudly, naming that requirement, rather
-- than silently reading the wrong commit's file if the update is missed.
local FIX_COMMIT = "14ff46c3"
local BEFORE_FIX_COMMIT = "2a8af359963d9eb62daa52ca750833dfc2ed64ea"

local function older_toolchain_file(folder, checkout)
    local ok = try {function ()
        os.iorunv("git", {"cat-file", "-e", BEFORE_FIX_COMMIT .. "^{commit}"}, {curdir = checkout})
        return true
    end}
    assert(ok, "this checkout's history has no commit " .. BEFORE_FIX_COMMIT ..
           " (named here as the parent of " .. FIX_COMMIT .. ", the toolchain(apple-ios) on_check fix) - " ..
           "if that commit was rebased, update BEFORE_FIX_COMMIT in this test to its new parent's hash")
    local text = os.iorunv("git", {"show", BEFORE_FIX_COMMIT .. ":toolchains/apple-ios/xmake.lua"}, {curdir = checkout})
    local file = path.join(folder, "apple-ios-before.lua")
    io.writefile(file, text)
    return file, BEFORE_FIX_COMMIT
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

-- xmake f -c -y in a fresh, isolated, empty store: whether it resolved clean, and whether it named
-- the toolchain not found along the way (a run can fail for an unrelated reason too, so both are told).
local function resolve(label, folder, repo, toolchain_lua)
    local run = path.join(folder, label)
    local project, store = path.join(run, "project"), path.join(run, "store")
    os.mkdir(project)
    os.mkdir(store)
    project_file(project, repo, toolchain_lua)
    local envs = {XMAKE_GLOBALDIR = store}
    local log = path.join(run, "resolve.log")
    -- A wedged resolve (this whole test exists because one already did, for an unrelated reason) must
    -- not hang the suite: a hard wall-clock timeout, not xmake's own (os.execv has none).
    local ok, code = try {function ()
        return true, os.execv("timeout", {"60", "xmake", "f", "-c", "-y"}, {curdir = project, envs = envs, stdout = log, stderr = log})
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

    local older_file, older_commit = older_toolchain_file(folder, checkout)
    local ok_old, not_found_old = resolve("old", folder, repo, older_file)
    if ok_old then
        table.insert(found, "toolchains/apple-ios/xmake.lua as of " .. older_commit:sub(1, 10) .. " (pinned as the fix's own parent - see older_toolchain_file) was expected to fail the same fresh install the checkout's current one now passes - it did not, so this test's negative control does not reproduce the bug it exists to catch")
    end
    if not ok_old and not not_found_old then
        table.insert(found, "toolchains/apple-ios/xmake.lua as of " .. older_commit:sub(1, 10) .. " failed for a different reason than the one this test exists to name")
    end

    os.tryrm(folder)
    return found
end
