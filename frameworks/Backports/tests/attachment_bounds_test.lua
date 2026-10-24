local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local folder = path.join(backports, "tests", "UIKit", "attachment_bounds")
local fixture = path.join(folder, "main.m")
local shim = path.join(folder, "shim")
local category = path.join(backports, "src", "UIKit", "NSTextAttachment+Text7.m")

local function clang(args)
    os.vrunv("xcrun", table.join({"clang", "-framework", "AppKit", "-framework", "Foundation"}, args))
end

local function mutant_of(file, folder_out)
    local text = io.readfile(file)
    local start, stop = text:find("        return bounds;", 1, true)
    assert(start, "the attachment bounds default is not where the negative control expects it")
    os.mkdir(folder_out)
    local target = path.join(folder_out, path.filename(file))
    io.writefile(target, text:sub(1, start - 1) .. "        return CGRectZero;" .. text:sub(stop + 1))
    return target
end

function main()
    local out = workspace.run("backports-tests", "AttachmentBounds")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    local broken = path.join(out, "broken")
    clang({"-o", host, fixture})
    clang({"-I", shim, "-o", backport, fixture, category})
    clang({"-I", shim, "-o", broken, fixture, mutant_of(category, path.join(out, "mutant"))})
    os.execv(host, {}, {stdout = host .. ".out"})
    os.execv(backport, {}, {stdout = backport .. ".out"})
    os.execv(broken, {}, {stdout = broken .. ".out"})
    local expected, got = io.readfile(host .. ".out"), io.readfile(backport .. ".out")
    assert(#expected > 0, "the host attachment program printed nothing")
    assert(expected == got, "the backport attachment bounds differ from the host in " .. out)
    assert(io.readfile(broken .. ".out") ~= expected, "the negative control with an empty default matched the host in " .. out)
end
