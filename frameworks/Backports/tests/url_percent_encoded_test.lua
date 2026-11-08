local workspace = import("@addon.revenant.workspace", {anonymous = true})
local backports = path.absolute(path.join(os.scriptdir(), ".."))
local source = path.absolute(path.join(backports, "..", "..", "toolchain", "src", "swift-runtime", "overlay", "Foundation", "URLPercentEncoded.swift"))
local directories_source = path.absolute(path.join(backports, "..", "..", "toolchain", "src", "swift-runtime", "overlay", "Foundation", "URLDirectories.swift"))
local fixture = path.join(backports, "tests", "Foundation", "url_percent_encoded", "main.swift")
local corpus = path.join(backports, "tests", "url_components", "corpus.txt")

local ACCESSORS = {"host", "user", "password", "path", "query", "fragment"}

local function renamed(text)
    local masked = text
    for _, name in ipairs(ACCESSORS) do
        local revised = "rev" .. name:sub(1, 1):upper() .. name:sub(2)
        masked = masked:gsub("%f[%w_]" .. name .. "%(percentEncoded", revised .. "(percentEncoded")
    end
    masked = masked:gsub("%.host%(%)", ".revHost()")
    masked = masked:gsub("%.query%(%)", ".revQuery()")
    masked = masked:gsub("%f[%w_]DirectoryHint%f[^%w_]", "RevDirectoryHint")
    masked = masked:gsub("init%(filePath", "init(revFilePath")
    masked = masked:gsub("URL%(filePath", "URL(revFilePath")
    masked = masked:gsub("URL%.(%l%w*Directory)%f[^%w_]", function (name)
        return "URL.rev" .. name:sub(1, 1):upper() .. name:sub(2)
    end)
    masked = masked:gsub("static var (%l%w*Directory)%f[^%w_]", function (name)
        return "static var rev" .. name:sub(1, 1):upper() .. name:sub(2)
    end)
    masked = masked:gsub("static func (%l%w*Directory)%f[^%w_]", function (name)
        return "static func rev" .. name:sub(1, 1):upper() .. name:sub(2)
    end)
    return masked
end

local function swiftc(args)
    os.vrunv("xcrun", table.join({"swiftc", "-O"}, args))
end

function main()
    local out = workspace.run("backports-tests", "URLPercentEncoded")
    local host = path.join(out, "host")
    local backport = path.join(out, "backport")
    local overlay = path.join(out, "RevURLPercentEncoded.swift")
    local backport_dir = path.join(out, "backport-src")
    os.mkdir(backport_dir)
    local backport_fixture = path.join(backport_dir, "main.swift")
    local directories = path.join(out, "RevURLDirectories.swift")
    io.writefile(overlay, renamed(io.readfile(source)))
    io.writefile(directories, renamed(io.readfile(directories_source)))
    io.writefile(backport_fixture, renamed(io.readfile(fixture)))
    swiftc({fixture, "-o", host})
    swiftc({"-module-name", "backport", overlay, directories, backport_fixture, "-o", backport})
    os.execv(host, {corpus}, {stdout = host .. ".out"})
    os.execv(backport, {corpus}, {stdout = backport .. ".out"})
    local expected = io.readfile(host .. ".out")
    local got = io.readfile(backport .. ".out")
    assert(#expected > 0, "the host URL program printed nothing")
    if got ~= expected then
        local want, have = {}, {}
        for line in expected:gmatch("[^\n]+") do table.insert(want, line) end
        for line in got:gmatch("[^\n]+") do table.insert(have, line) end
        local shown = {}
        for index = 1, math.max(#want, #have) do
            if want[index] ~= have[index] and #shown < 12 then
                table.insert(shown, string.format("host:     %s\nbackport: %s", want[index] or "-", have[index] or "-"))
            end
        end
        raise("the URL percent-encoded accessors and filePath initialiser differ from the host's in %s:\n%s", out, table.concat(shown, "\n"))
    end
end
