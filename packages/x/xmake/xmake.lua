package("xmake")
    set_kind("binary")
    set_homepage("https://xmake.io")
    set_description("A cross-platform build utility based on Lua, with revenant's patches to its addon handling, a job count taken from a GNU make jobserver or XMAKE_MAX_JOBS, one build for two processes that reinstall the same package, package locks waited for without stopping the other jobs, and a package locked by its install directory, so two instances of one package never install into it at once")
    set_license("Apache-2.0")

    add_urls("https://github.com/xmake-io/xmake.git")
    add_versions("2026.10.17", "8158c5da2ec3d5e4bd6b8a83e376319e948120d0")

    for _, patch in ipairs({
        {"0001-Lock-the-installed-addon-version-a-project-declares.patch", "b4f8eb1e4e0ca57b5578a9878f1b2133a4380d43ab97454aacd293afcdbc40ad"},
        {"0002-Keep-the-active-addon-version-when-a-project-install.patch", "6d15aa35375e2396a33c39c3d6a7ca9f0c0642f56853db9eb2bc73df57a961ff"},
        {"0003-Let-the-child-processes-of-an-addon-install-see-its-.patch", "7544b7105f7929944586a37cce09687b7ca8daefa37627ea4a11555517e1d9c3"},
        {"0004-Warn-when-the-inherited-addon-pins-cannot-be-read.patch", "aedbf2690b256d857afd26c61b36054447c72ce1331f2f278934aae82cb10386"},
        {"0005-Activate-an-addon-which-a-project-declares-without-a.patch", "ec9969032ef7def64ef4c0ad0cce36046664eba0532fa3bad85f573e9019da54"},
        {"0006-Keep-a-project-s-addon-pin-strict-fall-back-only-for.patch", "85ec3f5423254a435a8ac2be37181fe845cfa1aa1bc06c3dd7377429c5f44ff3"},
        {"0007-Use-an-addon-from-a-folder-of-the-project-without-in.patch", "cd9ecb8cbd5247e8fac8c2765527c9f291f2dc3ba9f1c83bd4b8772e8120e335"},
        {"0008-Take-the-job-count-from-a-jobserver-or-from-XMAKE_MA.patch", "f0c3be884782d29bbbc8d2cff6a4041999dca6f778e6b516352f9a6e81b91ff9"},
        {"0009-Build-a-package-once-when-two-processes-reinstall-it.patch", "0fb6b1b9c22a112246baf6d943221eab1c20800682ad77f181f432893550f777"},
        {"0010-Wait-for-a-package-lock-without-stopping-the-other-j.patch", "bb13d7194abed2baedb2a36f71f0ee7366b9e4da5348fa9b8aca7804fbca8b69"},
        {"0011-Name-the-read-only-variable-kind-VDKREG-in-the-Lua-p.patch", "d1d57269e8362e7992347a9b4c5b114ce2d99a67d805d2fae8571854b686373f"},
        {"0012-Lock-a-package-by-its-install-directory.patch", "4a665ceff500cafcfc0e69e86757802462b778552af28846150dad8e930f3be0"},
        {"0013-An-install-folder-without-manifest.txt-is-not-installed.patch", "69fb887a95d4899b7ab97edd493a9de65178ea59cf15fe0363bf24364d6fba5b"},
        {"0014-A-query-for-an-install-folder-creates-no-folder.patch", "ebedfea351eeb54f513c1b675bf8026a9b6f228cd4357f5669fdea614dab1ebc"},
        {"0015-Publish-an-install-by-swapping-a-link-to-its-generation.patch", "bf44ce37c8ea68285094fac95c7a8b56e2d8830d4d080efa07ff19f80e47d8b5"},
        {"0016-Export-the-generation-a-published-install-links-to.patch", "b9073b12de1563b2a9b7a05d4fc0d943ae2ee93ab35138a881f7d1e1dbe2a170"},
        {"0017-Fetch-an-install-again-once-it-is-published-so-the-c.patch", "40f1377cd96f5fe66feb13390658f84e9127d1a4acf48643b10d54c343d3f4d6"},
        {"0018-Report-a-process-exit-to-the-wait-on-that-process.patch", "45efce0489dd57a4ac0c430cbf6333d7a029107633ff2f955caab682598d8a61"},
        {"0019-Read-the-inode-of-the-file-a-lock-holds.patch", "d3cd9eba5df146444db1a0f11ebf4d7592ae0ca562b1def31f779c51d1f11955"},
        {"0020-Fold-the-digest-of-the-xmake-patches-that-change-out.patch", "c3056f6b12d5197bb2d337948e7721ce88f679605b4d0480c6a706836408f4e2"},
        {"0021-Put-each-package-s-applied-patch-sha256-list-into-it.patch", "f7a636db5a95804ddf50dc56fd126142c4957b22e2942d7ebddd6e096aa50b07"},
        {"0022-Put-the-addons-a-project-pins-into-a-package-s-hash.patch", "4fb047a4f1c30ed0911657e020bf3583cbc4aea6161daf4a2e7e5275830058f8"}}) do
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
