import("fixtures")

local DEMO = "space.kern0x1b.swiftui"
local PLATFORM = "org.revenant.backports"
local VERSION = "0.8.18+2396e86d"
local FFMPEG_PACKAGE = "org.revenant.ffmpeg-hevc-510a18e9"
local FFMPEG_VERSION = "0.8.18+510a18e9"
local FOLDER = "usr/lib/revenant/" .. PLATFORM .. "/"
local FFMPEG_FOLDER = "usr/lib/revenant/" .. FFMPEG_PACKAGE .. "/"
local FFMPEG_DEPENDS = FFMPEG_PACKAGE .. " (= " .. FFMPEG_VERSION .. ")"
local DOCS = "usr/share/doc/" .. PLATFORM .. "/licenses/"
local APPLICATION = {"Applications/SwiftUIDemo.app/SwiftUIDemo", "Applications/SwiftUIDemo.app/Info.plist"}

local runs = 0

local function write_package(tools, folder, name, version, depends, files)
    local root = path.join(folder, name .. "-root")
    os.tryrm(root)
    for _, relative in ipairs(files) do
        local file = path.join(root, relative)
        os.mkdir(path.directory(file))
        io.writefile(file, relative)
    end
    local control = path.join(folder, name .. ".control")
    io.writefile(control, "Package: " .. name .. "\nArchitecture: iphoneos-arm\nDescription: a test package\n")
    return tools.debian.write({control = control, version = version, root = root, depends = depends, outputdir = path.join(folder, "build")})
end

local function composition(extra)
    local files = {FOLDER .. "libUIKitBackports.dylib", FOLDER .. "libCoreDataBackports.dylib", FOLDER .. "libFoundationBackports.dylib",
                   FOLDER .. "libc++.1.dylib", FOLDER .. "libc++abi.1.dylib",
                   "var/lib/revenant/tessdata/best/eng.traineddata", "var/lib/revenant/tessdata/best/chi_sim.traineddata",
                   "var/lib/revenant/tessdata/fast/eng.traineddata",
                   DOCS .. "tessdata/LICENSE", DOCS .. "ffmpeg-hevc/LICENSE.md"}
    for _, file in ipairs(extra or {}) do
        table.insert(files, file)
    end
    return files
end

local function ffmpeg(without)
    local files = {FFMPEG_FOLDER .. "libavcodec.62.dylib", FFMPEG_FOLDER .. "libavutil.60.dylib"}
    local kept = {}
    for _, file in ipairs(files) do
        if file ~= without then
            table.insert(kept, file)
        end
    end
    return kept
end

local function check(tools, folder, platform_files, ffmpeg_files, depends)
    runs = runs + 1
    local run = path.join(folder, "run-" .. runs)
    local build = path.join(run, "build")
    os.mkdir(build)
    write_package(tools, run, FFMPEG_PACKAGE, FFMPEG_VERSION, nil, ffmpeg_files or ffmpeg())
    write_package(tools, run, PLATFORM, VERSION, depends or {FFMPEG_DEPENDS}, platform_files)
    write_package(tools, run, DEMO, "1.0.0", {PLATFORM .. " (= " .. VERSION .. ")"}, APPLICATION)
    return fixtures.refusal(function () tools.deb_check.main(build, DEMO, PLATFORM) end)
end

function failures(opt)
    local tools = {
        debian = import("debian", {rootdir = opt.modules, anonymous = true}),
        deb_check = import("deb_check", {rootdir = path.join(path.directory(opt.modules), "tools"), anonymous = true}),
    }
    local found = {}
    local folder = fixtures.scratch()

    local errors = check(tools, folder, composition())
    if errors then
        table.insert(found, "the package carries the Backports libraries, the C++ runtime, the Vision text models of vision_text.lua and their licences, and depends on the FFmpeg package: " .. errors)
    end

    for _, case in ipairs({
        {"a Vision text model that vision_text.lua does not list", "var/lib/revenant/tessdata/best/xyz.traineddata"},
        {"a Vision text model at a level that does not exist", "var/lib/revenant/tessdata/bestest/eng.traineddata"},
        {"a model outside the Vision text folder", "var/lib/revenant/tessdata/eng.traineddata"},
        {"an FFmpeg library in the Backports folder", FOLDER .. "libavcodec.62.dylib"},
        {"an FFmpeg library other than avcodec and avutil", FOLDER .. "libavformat.61.dylib"},
        {"a library that is not a Backports library", FOLDER .. "libSomething.dylib"},
        {"a file beside the Backports libraries", FOLDER .. "README"},
        {"a licence outside the two the package carries", DOCS .. "other/LICENSE"},
        {"a file under /usr that is not in the package's list", "usr/bin/tool"},
    }) do
        errors = check(tools, folder, composition({case[2]}))
        if not errors or not errors:find("carries ./" .. case[2] .. ",", 1, true) then
            table.insert(found, "refused: " .. case[1] .. " (" .. case[2] .. "): " .. tostring(errors))
        end
    end

    errors = check(tools, folder, composition(), ffmpeg(), {})
    if not errors or not errors:find("depends on no org.revenant.ffmpeg-hevc-", 1, true) then
        table.insert(found, "a Backports package that depends on no FFmpeg package is refused: " .. tostring(errors))
    end

    errors = check(tools, folder, composition(), ffmpeg(FFMPEG_FOLDER .. "libavutil.60.dylib"))
    if not errors or not errors:find("carries no libavutil.60.dylib", 1, true) then
        table.insert(found, "an FFmpeg package without the libavutil decoder the Backports libraries link is refused: " .. tostring(errors))
    end

    os.tryrm(folder)
    return found
end
