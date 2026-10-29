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
        {"0001-Configure-the-Cocoa-port-for-armv7-and-iOS-6-with-CM.patch", "fc85e9efb45de28f82651b460092b1ef1e133879b13d988bd8b96e9da74df4f3"},
        {"0002-bmalloc-carry-the-allocator-variant-a-512-MB-armv7-d.patch", "cbb3607ae8aa81afdd4ea3af3f0602752823baef42608eee23211f2886742153"},
        {"0003-WTF-run-on-the-libSystem-of-iOS-6-and-on-armv7.patch", "99fcc11e03a939cfb0af9c882ecde7fa77018a313f0da68aa1443559037ecc92"},
        {"0004-JavaScriptCore-restore-the-ARMv7-LLInt-and-offlineas.patch", "8f68efe4acfd929cc97eafa3cd89c3b22f62dcbf0891d36c7d1e7864f5c316ba"},
        {"0005-JavaScriptCore-carry-the-32-bit-JSValue-and-this-dev.patch", "58a828f755695e819d6b09896880170ce2f8d3e46171148bb3963777de45deb1"},
        {"0006-JavaScriptCore-restore-the-ARMv7-assembler-and-basel.patch", "fa0b32f0add2fe54789564fd69b6fb0d536e2e9244845db9df6e453737f254e3"},
        {"0007-JavaScriptCore-restore-the-32-bit-DFG.patch", "e31f611d761e688f537852b9ae948b2b929d3d4fafc656cfdac339dbf76d2aec"},
        {"0008-JavaScriptCore-keep-B3-Air-FTL-and-WebAssembly-build.patch", "1d30f6685f1d510d9f1d7d3fa08b8cd186f9fa00fb7ad2b80144383e5123b071"},
        {"0009-JavaScriptCore-put-ARMv7-back-into-the-Yarr-JIT.patch", "91fe6172c7f3e57dd065d89f8d38dc1ef78446d8f1d838a4efc496154da80548"},
        {"0010-WebCore-platform-draw-lay-out-text-and-load-on-a-201.patch", "e9b717f75658e9fb3e022b2ca8258927f4cdf7964ebdb4a19476d82ae0e0fb8e"},
        {"0011-WebCore-adapt-the-engine-above-the-platform-layer-to.patch", "c26be393fdac2d0dcd9c44f3948f2d09c07a81b498db65ba7105deadc119a343"},
        {"0012-Paint-colour-correctly-on-a-CoreGraphics-without-lin.patch", "2fb008c29f47c2e286351d9ff48629484af383895e938d13a725e6ffbf422723"},
        {"0013-Load-web-fonts-and-shape-text-on-the-CoreText-of-iOS.patch", "66785822fb4b8e4998fdec1259b4d8caf71b3c8914181207ffc6960a0d86f314"},
        {"0014-Decode-the-image-formats-the-web-serves-within-this-.patch", "a148981715dadfebf1305c519cadf5af1922d26aa687eb1f4195a6c6bb73a60b"},
        {"0015-Play-media-and-capture-camera-and-microphone-on-AVFo.patch", "2d0ef0f71f34e54e273a20293cf8c20433b038bea47991a5c3008e37461196a8"},
        {"0016-Fit-the-engine-to-a-phone-with-512-MB-that-jetsams-a.patch", "865fa4fdc9b853168133f40898c7cdd103a8661915d933f893784a62843e6bda"},
        {"0017-Network-and-storage-the-way-iOS-6-can.patch", "fe38ad55cb9f4358758c43245deaaae80480c207bf8c1cc75716f2cc6d8b1763"},
        {"0018-Perform-Web-Crypto-through-WebKit-s-OpenSSL-backend.patch", "b632b37b977efe2aba667f92c63b06468fb1e5677ac700932d26a728d15fcef1"},
        {"0019-WebGL-through-an-ANGLE-backend-on-EAGL.patch", "c23a5995736dd4e9cbab53eabd9f43ea6007e06f728dd86b8450aa3c9a90d3fa"},
        {"0020-Scroll-and-tap-the-way-iOS-6-delivers-touches.patch", "a1c1d100ccf2e5a4d5f1eb0dbad16dd55d64768652840661faf0b7ee4e6d5bc6"},
        {"0021-Serve-Mobile-Safari-as-its-embedder-on-iOS-6.patch", "f8f8c819e1699b81b1cf737751cd7069621624ab7b77f3d408c60ea77de52761"},
        {"0022-WebKitLegacy-reinstate-the-WebKit1-API-iOS-links.patch", "5218580156f076c57a54fa7db2593de84345cc116dae13b9779261be468f08e7"},
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
                               "Source/WTF/Scripts/generate-unified-source-bundles.py",
                               "Source/JavaScriptCore/llint/LowLevelInterpreter32_64.asm"}) do
            assert(os.isfile(path.join(src, file)), file .. " is not in the patched tree")
        end
    end)
