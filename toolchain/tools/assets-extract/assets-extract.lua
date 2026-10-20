function tool()
    local source = path.join(os.scriptdir(), "..", "..", "src", "assets-extract", "assets-extract.m")
    local workspace = import("workspace", {rootdir = path.join(os.scriptdir(), "..", "..", "modules"), anonymous = true})
    local cache = os.getenv("REVENANT_ASSETS_EXTRACT_CACHE")
    if not cache or cache == "" then
        cache = workspace.run("assets-extract")
    end
    local built = path.join(cache, "assets-extract")
    if not os.isfile(built) or os.mtime(source) > os.mtime(built) then
        os.mkdir(cache)
        local sdk = os.iorunv("xcrun", {"--show-sdk-path"}):trim()
        os.execv("xcrun", {"clang", "-isysroot", sdk, "-fobjc-arc", "-Wall", "-Wno-deprecated-declarations", source,
                           "-framework", "Foundation", "-framework", "CoreGraphics", "-framework", "ImageIO",
                           "-framework", "UniformTypeIdentifiers", "-o", built})
    end
    return built
end

function main(...)
    os.exit(os.execv(tool(), {...}, {try = true}))
end
