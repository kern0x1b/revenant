function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("blockid", out)
    local here = os.scriptdir()
    corpus.ios(e, {"-O2", "-fobjc-arc", "-w", "-framework", "Foundation",
                   path.join(here, "blockid.m"), "-o", path.join(out, "BlockID-arm64")})
    return path.join(out, "BlockID-arm64")
end
