package("xmake")
    set_kind("binary")
    set_homepage("https://xmake.io")
    set_description("A cross-platform build utility based on Lua, with hades' patches to its addon handling")
    set_license("Apache-2.0")

    add_urls("https://github.com/xmake-io/xmake.git")
    add_versions("2026.10.17", "8158c5da2ec3d5e4bd6b8a83e376319e948120d0")

    for _, patch in ipairs({
        {"0001-Lock-the-installed-addon-version-a-project-declares.patch", "5e25a2030807b92717f794ef7a77d15d1d12eb1a9fd2da7989a9837f3fab9ae7"},
        {"0002-Keep-the-active-addon-version-when-a-project-install.patch", "1e717aa7720b34cc85dbfe8b2ec375e7f5451523b0da1713d48a0251ced6e3cd"},
        {"0003-Let-the-child-processes-of-an-addon-install-see-its-.patch", "22cee150af1ecf0ad657fca0fe5d874810f859eca530764b3e97629ac1f361e8"},
        {"0004-Warn-when-the-inherited-addon-pins-cannot-be-read.patch", "b6e1e98acf7d23cb47720e7173aa478b1a1d559a068db3fea795e084b744e341"},
        {"0005-Activate-an-addon-which-a-project-declares-without-a.patch", "4d38299407dc26a2f0efb25b020cf10b924380f51afe5a6201d2a394067d88d9"},
        {"0006-Keep-a-project-s-addon-pin-strict-fall-back-only-for.patch", "e020c07ef45d0b74f2697564fa50b94d4548e49ef263652bf4951d09eb492901"},
        {"0007-Use-an-addon-from-a-folder-of-the-project-without-in.patch", "06abf90250955694fc75937ca9e94245609d8e1877691a66cf3a994f5ce7238e"}}) do
        add_patches("2026.10.17", path.join(os.scriptdir(), "patches", patch[1]), patch[2])
    end

    on_install("macosx", "linux", function (package)
        os.vrunv("./configure", {"--prefix=" .. package:installdir()})
        os.vrunv("make", {"-j" .. os.default_njob()})
        os.vrunv("make", {"install"})
    end)

    on_test(function (package)
        os.vrunv(path.join(package:installdir("bin"), "xmake"), {"--version"})
    end)
