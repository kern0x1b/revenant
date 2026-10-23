package("webkit")
    set_kind("library", {headeronly = true})
    set_homepage("https://webkit.org")
    set_description("WebKit for armv7 and iOS 6, its sources only: upstream WebKit at a commit of main with the port as an ordered series of patches, laid out for frameworks/WebKit to configure and build with CMake")
    set_license("LGPL-2.1-or-later AND BSD-2-Clause")

    local commit = "c70a794b03410d0a7e8e134d35441139dfc5d502"
    local tree = {"Source/JavaScriptCore", "Source/WTF", "Source/WebCore", "Source/WebKit", "Source/WebKitLegacy",
                  "Source/bmalloc", "Source/cmake", "Source/ThirdParty/ANGLE", "Source/ThirdParty/capstone",
                  "Source/ThirdParty/unifdef", "Source/ThirdParty/libwebrtc/Source/third_party/libwebm",
                  "Tools/Scripts", "Tools/TestWebKitAPI/Tests/WebKit/WKWebView",
                  "WebKitLibraries", "LayoutTests/ipc", "LayoutTests/media/media-source"}
    add_urls("https://github.com/WebKit/WebKit.git", {includes = tree, submodules = false})
    add_versions("2026.09.14", commit)

    local patches = {
        {"0001-Configure-the-Cocoa-port-for-armv7-and-iOS-6-with-CM.patch", "d1a8fb7ae03e45cca7781693dfb18cf7a0b2b76398bc635feeb5aa6daf5bae4a"},
        {"0002-bmalloc-carry-the-allocator-variant-a-512-MB-armv7-d.patch", "cbb3607ae8aa81afdd4ea3af3f0602752823baef42608eee23211f2886742153"},
        {"0003-WTF-run-on-the-libSystem-of-iOS-6-and-on-armv7.patch", "99fcc11e03a939cfb0af9c882ecde7fa77018a313f0da68aa1443559037ecc92"},
        {"0004-JavaScriptCore-restore-the-ARMv7-LLInt-and-offlineas.patch", "d314cc1a8dc5aa66ff048c591d21110d62e0813a8d2be644b04de5edfd03bb34"},
        {"0005-JavaScriptCore-carry-the-32-bit-JSValue-and-this-dev.patch", "ac1b890fd38538dec977ac2ea858a07bc8bf75f8e2d9732309f648f5fdb9ef66"},
        {"0006-JavaScriptCore-restore-the-ARMv7-assembler-and-basel.patch", "5c3f5c8f3e7787a9be077b7d06e085ea61a6ece50d5cf3aa9844e542f9730572"},
        {"0007-JavaScriptCore-restore-the-32-bit-DFG.patch", "2bd972bef71dd783e49ee32de894c5f188a5833c07740e02cedd8ea13cf9f451"},
        {"0008-JavaScriptCore-keep-B3-Air-FTL-and-WebAssembly-build.patch", "2787f7b6bbd11111600c6135602533689e3df980593814ce497bf28e8c5c381e"},
        {"0009-JavaScriptCore-put-ARMv7-back-into-the-Yarr-JIT.patch", "cf2bbb2894295cda505e715061eb605dda227ba73c7b3ab58326a5f1a8292322"},
        {"0010-WebCore-platform-draw-lay-out-text-and-load-on-a-201.patch", "9d889d9e75c53649ae83aa508698762ed6567e87606a603a90180fd177602661"},
        {"0011-WebCore-adapt-the-engine-above-the-platform-layer-to.patch", "882e14bdfefa105031ed8a4e0209f6b5b39964f2141566d6ffb92cb126d90be0"},
        {"0012-Paint-colour-correctly-on-a-CoreGraphics-without-lin.patch", "2fb008c29f47c2e286351d9ff48629484af383895e938d13a725e6ffbf422723"},
        {"0013-Load-web-fonts-and-shape-text-on-the-CoreText-of-iOS.patch", "66785822fb4b8e4998fdec1259b4d8caf71b3c8914181207ffc6960a0d86f314"},
        {"0014-Decode-the-image-formats-the-web-serves-within-this-.patch", "e7fd31c1814cbdfd4fbe472f195020d48df861caeaeaaf9e8a207bc0e6f4771b"},
        {"0015-Play-media-and-capture-camera-and-microphone-on-AVFo.patch", "2d0ef0f71f34e54e273a20293cf8c20433b038bea47991a5c3008e37461196a8"},
        {"0016-Fit-the-engine-to-a-phone-with-512-MB-that-jetsams-a.patch", "d1ebacc2ae44f9261b0c3b72ab4c2bdc415f7e9717caff9f35841c554665ae9f"},
        {"0017-Network-and-storage-the-way-iOS-6-can.patch", "fe38ad55cb9f4358758c43245deaaae80480c207bf8c1cc75716f2cc6d8b1763"},
        {"0018-Perform-Web-Crypto-through-WebKit-s-OpenSSL-backend.patch", "b632b37b977efe2aba667f92c63b06468fb1e5677ac700932d26a728d15fcef1"},
        {"0019-WebGL-through-an-ANGLE-backend-on-EAGL.patch", "c23a5995736dd4e9cbab53eabd9f43ea6007e06f728dd86b8450aa3c9a90d3fa"},
        {"0020-Scroll-and-tap-the-way-iOS-6-delivers-touches.patch", "efd504e94e060810daa71de3054bfdd2b5e283d2e29c81693112c03c4b506c29"},
        {"0021-Serve-Mobile-Safari-as-its-embedder-on-iOS-6.patch", "877677f67d7c849d4586e158fe71169c18b64289554caf8466c9f2d67ba44fb7"},
        {"0022-WebKitLegacy-reinstate-the-WebKit1-API-iOS-links.patch", "05141e4951725ca50bf5d89954d6e1aac9dd7c006c1e42605be5230037254361"},
        {"0023-Describe-the-iOS-6-port-in-one-page.patch", "07240ceb7b8206cba93b0e972282534e7706686c6ea1d2d93fc011059a519961"},
        {"0024-Keep-the-webkitglib-2.54-state-these-files-had-in-th.patch", "8061a88fd3852a8693aec123336b2fb8895984aad4ffba334aed517d624e864d"},
        {"0025-Keep-the-compiler-the-build-was-configured-with.patch", "8d51fc600b929ccf8fd1d8870b6f3205151d0d027989218a337d7275acc30e27"}}

    local digests = {table.concat(tree, ",")}
    for _, patch in ipairs(patches) do
        add_patches("2026.09.14", path.join(os.scriptdir(), "patches", patch[1]), patch[2])
        table.insert(digests, patch[1] .. "=" .. patch[2])
    end
    add_configs("recipe", {description = "The digest of the folders this recipe checks out and the patches it applies, so a changed patch is a different source tree.", default = hash.strhash128(table.concat(digests, ";")), type = "string", readonly = true})

    on_install(function (package)
        local src = package:installdir("src")
        for _, entry in ipairs(os.filedirs("*")) do
            os.mv(entry, path.join(src, path.filename(entry)))
        end
        os.cp(path.join(src, "Source", "WebCore", "LICENSE-LGPL-2.1"), package:installdir("licenses") .. "/")
        os.cp(path.join(src, "Source", "WebCore", "LICENSE-APPLE"), package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        local src = package:installdir("src")
        for _, file in ipairs({"CMakeLists.txt", "PORTING-IOS6.md", "Source/cmake/OptionsIOS6.cmake",
                               "Source/cmake/WebKitUnifiedSources.cmake", "Source/JavaScriptCore/llint/LowLevelInterpreter32_64.asm"}) do
            assert(os.isfile(path.join(src, file)), file .. " is not in the patched tree")
        end
    end)
