function main(out)
    local scripts = path.join(os.scriptdir(), "..", "..", "tools")
    local corpus = import("corpus", {rootdir = scripts, anonymous = true})
    local e
    e, out = corpus.setup("refrepro", out)
    local here = os.scriptdir()
    corpus.ios(e, {"-O2", "-fobjc-arc", "-w", "-framework", "UIKit", "-framework", "Foundation", "-framework", "CoreGraphics", "-framework", "QuartzCore",
                   path.join(here, "main.m"), "-o", path.join(out, "RefRepro-arm64")})
    io.writefile(path.join(out, "includes.h"), io.readfile(path.join(e.recompiler, "include", "uikit-includes.h")) .. "#import <objc/runtime.h>\n")
    return corpus.app(out, "RefRepro", path.join(here, "Info.plist"))
end
