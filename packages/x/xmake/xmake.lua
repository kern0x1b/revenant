package("xmake")
    set_kind("binary")
    set_homepage("https://xmake.io")
    set_description("A cross-platform build utility based on Lua, with revenant's patches to its addon handling, a job count taken from a GNU make jobserver or XMAKE_MAX_JOBS, one build for two processes that reinstall the same package, package locks waited for without stopping the other jobs, and a package locked by its install directory, so two instances of one package never install into it at once")
    set_license("Apache-2.0")

    add_urls("https://github.com/xmake-io/xmake.git")
    add_versions("2026.10.17", "8158c5da2ec3d5e4bd6b8a83e376319e948120d0")

    for _, patch in ipairs({
        {"0001-Lock-the-installed-addon-version-a-project-declares.patch", "512127d7739dc1fcbb78513bb508e502edfdd9218ae32146d018ec9483064ce1"},
        {"0002-Keep-the-active-addon-version-when-a-project-install.patch", "1f0432e379084362d866aa7b7325d60d91fb5d87a8ad27fdc4a5ec24296edf31"},
        {"0003-Let-the-child-processes-of-an-addon-install-see-its-.patch", "3c0740516a62e1aa74fa8f381675818755e199377317c88db81915a84c8a26b7"},
        {"0004-Warn-when-the-inherited-addon-pins-cannot-be-read.patch", "bea4356d8812c2eb6f284720b4592b2ea6dee24d986fd4f45aabe9a183c998ac"},
        {"0005-Activate-an-addon-which-a-project-declares-without-a.patch", "23738f076d027100c61c0fa94ccc820f95e1e28de7280bab75d42e209961a93a"},
        {"0006-Keep-a-project-s-addon-pin-strict-fall-back-only-for.patch", "d084001099fd0d33040ffe20127d38ad4c0ba790a37cc7aa5fff0556bd4ba0ab"},
        {"0007-Use-an-addon-from-a-folder-of-the-project-without-in.patch", "cd99e18ad9599d0c793a437cd9a315f86f273ac08f738b1391a56e8818ae94a1"},
        {"0008-Take-the-job-count-from-a-jobserver-or-from-XMAKE_MA.patch", "bde5d35a476c49a7e3782485f4148a4ed86806a34bf2c4de95dd352658b0dc6d"},
        {"0009-Build-a-package-once-when-two-processes-reinstall-it.patch", "6672dfa17742337d83a5eb3a59018d4458a24d92bea6567568f58fecab2ae72f"},
        {"0010-Wait-for-a-package-lock-without-stopping-the-other-j.patch", "5add9a04d3290347faafc247532505e34b156145496ed0671bcc06b3d12c34f0"},
        {"0011-Name-the-read-only-variable-kind-VDKREG-in-the-Lua-p.patch", "083b6f89badad1771829937450f38a6a30ae3f6e1c2269a0d593212bdeda3f7a"},
        {"0012-Lock-a-package-by-its-install-directory.patch", "5331acb3411a8da76bd1d543ebc28206e01b03acadcc7566db46a9c52c0a125a"},
        {"0013-An-install-folder-without-manifest.txt-is-not-installed.patch", "37779e9abfcefb1592d79138ea64347695761fa1592cb04f4bfd5a3418801859"},
        {"0014-A-query-for-an-install-folder-creates-no-folder.patch", "c17c3b2c45dcbc834c8ebca4be6135b6d594b77728827fb8ffe02465c5b532da"}}) do
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
