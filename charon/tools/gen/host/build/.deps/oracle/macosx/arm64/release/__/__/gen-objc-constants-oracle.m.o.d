{
    files = {
        "../../gen-objc-constants-oracle.m"
    },
    depfiles_format = "gcc",
    values = {
        "/Library/Developer/CommandLineTools/usr/bin/clang",
        {
            "-pipe",
            "-DIBOutlet=__attribute__((iboutlet))",
            "-DIBOutletCollection(ClassName)=__attribute__((iboutletcollection(ClassName)))",
            "-DIBAction=void)__attribute__((ibaction)",
            "-Qunused-arguments",
            "-target",
            "arm64-apple-macos",
            "-isysroot",
            "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk",
            "-O0",
            "-framework",
            "Foundation",
            "-framework",
            "CoreFoundation",
            "-fobjc-arc"
        }
    },
    depfiles = "build/.objs/oracle/macosx/arm64/release/__/__/__cpp_gen-objc-constants-oracle.m.m:   /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/SDKSettings.json   ../../gen-objc-constants-oracle.m\
"
}