package("xmake")
    set_kind("binary")
    set_homepage("https://xmake.io")
    set_description("A cross-platform build utility based on Lua, with revenant's patches to its addon handling, a job count taken from a GNU make jobserver or XMAKE_MAX_JOBS, one build for two processes that reinstall the same package, package locks waited for without stopping the other jobs, and a package locked by its install directory, so two instances of one package never install into it at once")
    set_license("Apache-2.0")

    add_urls("https://github.com/xmake-io/xmake.git")
    add_versions("2026.10.17", "8158c5da2ec3d5e4bd6b8a83e376319e948120d0")

    for _, patch in ipairs({
        {"0001-Lock-the-installed-addon-version-a-project-declares.patch", "4e3e152f8c4a133045574d6f9c6b4508922add79e49d287d5079cd9604f8a59b"},
        {"0002-Keep-the-active-addon-version-when-a-project-install.patch", "9355121b7ec2a1d96776267f3e1fd7c0ff79ecbfd20d6c1467ca4ac8f2c686eb"},
        {"0003-Let-the-child-processes-of-an-addon-install-see-its-.patch", "f1f1fed3b4ecdb68d7adee637e2ce89359f33e46e44d4385cecda6f1f1c632c7"},
        {"0004-Warn-when-the-inherited-addon-pins-cannot-be-read.patch", "aedbf2690b256d857afd26c61b36054447c72ce1331f2f278934aae82cb10386"},
        {"0005-Activate-an-addon-which-a-project-declares-without-a.patch", "931296f53335bca0a8a2ef994156975efb6c6695d438902f512aae49ec4e9118"},
        {"0006-Keep-a-project-s-addon-pin-strict-fall-back-only-for.patch", "875706ee03c25af7cc40065681a965e3545489c6e3d6564ed36c09d882aef370"},
        {"0007-Use-an-addon-from-a-folder-of-the-project-without-in.patch", "6493a47acded154d230acba33a934c7ba32ed2face980fadff43a8f1053d35b8"},
        {"0008-Take-the-job-count-from-a-jobserver-or-from-XMAKE_MA.patch", "f0c3be884782d29bbbc8d2cff6a4041999dca6f778e6b516352f9a6e81b91ff9"},
        {"0009-Build-a-package-once-when-two-processes-reinstall-it.patch", "0fb6b1b9c22a112246baf6d943221eab1c20800682ad77f181f432893550f777"},
        {"0010-Wait-for-a-package-lock-without-stopping-the-other-j.patch", "bb13d7194abed2baedb2a36f71f0ee7366b9e4da5348fa9b8aca7804fbca8b69"},
        {"0011-Name-the-read-only-variable-kind-VDKREG-in-the-Lua-p.patch", "d1d57269e8362e7992347a9b4c5b114ce2d99a67d805d2fae8571854b686373f"},
        {"0012-Lock-a-package-by-its-install-directory.patch", "4a665ceff500cafcfc0e69e86757802462b778552af28846150dad8e930f3be0"},
        {"0013-An-install-folder-without-manifest.txt-is-not-installed.patch", "69fb887a95d4899b7ab97edd493a9de65178ea59cf15fe0363bf24364d6fba5b"},
        {"0014-A-query-for-an-install-folder-creates-no-folder.patch", "ebedfea351eeb54f513c1b675bf8026a9b6f228cd4357f5669fdea614dab1ebc"},
        {"0015-Publish-an-install-by-swapping-a-link-to-its-generation.patch", "f36d9a278faed220a3353acb029c32ecb0198ca9e522051c17fa0dda0151ccb1"},
        {"0016-Export-the-generation-a-published-install-links-to.patch", "b9073b12de1563b2a9b7a05d4fc0d943ae2ee93ab35138a881f7d1e1dbe2a170"},
        {"0017-Fetch-an-install-again-once-it-is-published-so-the-c.patch", "40f1377cd96f5fe66feb13390658f84e9127d1a4acf48643b10d54c343d3f4d6"},
        {"0018-Report-a-process-exit-to-the-wait-on-that-process.patch", "45efce0489dd57a4ac0c430cbf6333d7a029107633ff2f955caab682598d8a61"},
        {"0019-Read-the-inode-of-the-file-a-lock-holds.patch", "d3cd9eba5df146444db1a0f11ebf4d7592ae0ca562b1def31f779c51d1f11955"},
        {"0020-Fold-the-digest-of-the-xmake-patches-that-change-out.patch", "c3056f6b12d5197bb2d337948e7721ce88f679605b4d0480c6a706836408f4e2"}}) do
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
