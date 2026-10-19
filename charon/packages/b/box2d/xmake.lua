package("box2d")
    set_homepage("https://box2d.org")
    set_description("Box2D 2.2.1, the rigid body engine iOS 7 runs UIKit Dynamics on (PhysicsKit carries this release of it), unmodified, as a static library whose every symbol is hidden, for the image that links it in")
    set_license("zlib")
    set_policy("package.strict_compatibility", true)

    add_urls("https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/box2d/Box2D_v$(version).zip")
    add_versions("2.2.1", "63184a8ad317e19cd0c3408e14cd808816628b5c8686741dc32664c6f4db3a95")
    add_links("Box2D")

    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different library.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    -- Hidden, so the engine is never API of the image it is linked into: libUIKitBackports.dylib exports
    -- what UIKit does, and nothing a second copy of Box2D in the process could bind to. No exceptions and
    -- no RTTI: the engine uses neither, and without them it needs of the C++ runtime only operator delete
    -- and __cxa_pure_virtual, which every release from 5.0 exports. NDEBUG stays undefined: PhysicsKit
    -- keeps its b2Assert checks (the 7.0 cache holds their expressions and source paths), and a broken
    -- invariant stops the process there as it does here.
    local FLAGS = {"-Os", "-fvisibility=hidden", "-fvisibility-inlines-hidden", "-fno-exceptions", "-fno-rtti"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "box2d is built with the apple-ios toolchain")[1]
        toolchain:load()
        local target = {"-target", package:arch() .. "-apple-ios", "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir"), "-I" .. os.curdir()}
        local objects = {}
        for _, source in ipairs(os.files(path.join("Box2D", "**.cpp"))) do
            local object = path.absolute(path.join("objects", (path.relative(source, "Box2D"):gsub("[/\\]", "_")) .. ".o"))
            os.mkdir(path.directory(object))
            os.vrunv(toolchain:tool("cxx"), table.join(target, FLAGS, {"-c", source, "-o", object}))
            table.insert(objects, object)
        end
        table.sort(objects)
        os.vrunv("xcrun", table.join({"libtool", "-static", "-o", path.join(package:installdir("lib"), "libBox2D.a")}, objects))
        for _, header in ipairs(os.files(path.join("Box2D", "**.h"))) do
            os.vcp(header, path.join(package:installdir("include"), path.directory(header)) .. "/")
        end
        os.vcp("License.txt", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libBox2D.a")))
        assert(os.isfile(path.join(package:installdir("include"), "Box2D", "Box2D.h")))
    end)
