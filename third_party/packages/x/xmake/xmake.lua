-- xmake itself: the release plus our patches to its addon handling (version locks and pins). The patches are
-- ours until upstream carries the same behaviour; each one is a git format-patch file in patches/.
package("xmake")
    set_kind("binary")
    set_homepage("https://xmake.io")
    set_description("A cross-platform build utility based on Lua, with hades' patches to its addon handling")
    set_license("Apache-2.0")

    add_urls("https://github.com/xmake-io/xmake.git")
    add_versions("v3.1.1", "3ba37a0d4f6c7584fc662780f27ab29d50f95899")

    -- in order: each patch applies on top of the ones before it
    for _, patch in ipairs({
        {"0001-Lock-the-installed-addon-version-a-project-declares.patch", "3470649e6c468dc462e2dce37dcffe75856d62a6f62bc2818916a312b964119f"},
        {"0002-Keep-the-active-addon-version-when-a-project-install.patch", "617c1322f7fbc0a8737c73a764611faa0a118a9864f561495ff954569a29db67"},
        {"0003-Let-the-child-processes-of-an-addon-install-see-its-.patch", "b686f14114cc1124024fe4b034dfb2e78e7350464a37b3631179d39acfaf5ac3"},
        {"0005-Warn-when-the-inherited-addon-pins-cannot-be-read.patch", "709d2371359cf7fe523a93a027c17c5f25f2afe1ef3e4b03a464a5ff740d53aa"},
        {"0007-Activate-an-addon-which-a-project-declares-without-a.patch", "dd165793182e90ffc67ef05720a52bae94122ace80b65a643a5cdc97dc007089"},
        {"0008-Say-why-the-inherited-addon-pins-do-no-harm.patch", "0e0a64d1127a14ada4baf5f97833c0e09207bfaf32486a850e627d2eaa3d7cc7"},
        {"0009-Keep-a-project-s-addon-pin-strict-fall-back-only-for.patch", "7549f0cd0d20b7bc56058987cffa9cd1783a42cb21b7d4de5c534d05bffe7f44"},
        {"0010-Pin-a-project-s-addons-before-loading-the-plugins.patch", "952b2da6995db46c7848e864182b20620d3b94e56d5049c544f583c41551d550"}}) do
        add_patches("v3.1.1", path.join(os.scriptdir(), "patches", patch[1]), patch[2])
    end

    on_install("macosx", "linux", function (package)
        os.vrunv("./configure", {"--prefix=" .. package:installdir()})
        os.vrunv("make", {"-j" .. os.default_njob()})
        os.vrunv("make", {"install"})
    end)

    on_test(function (package)
        os.vrunv(path.join(package:installdir("bin"), "xmake"), {"--version"})
    end)
