function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("cxxinit", out)
    local here = os.scriptdir()
    corpus.ios(e, {"-O2", "-fobjc-arc", "-w", "-x", "objective-c++", "-std=c++14", "-framework", "UIKit", "-framework", "Foundation",
                   "-framework", "CoreGraphics", "-lc++", path.join(here, "main.mm"), "-o", path.join(out, "CxxInit-arm64")})
    os.cp(path.join(e.recompiler, "include", "uikit-includes.h"), path.join(out, "includes.h"))
    return corpus.app(out, "CxxInit", path.join(here, "Info.plist"))
end
