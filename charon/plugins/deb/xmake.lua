task("deb")
    set_category("plugin")
    on_run("main")
    set_menu {
        usage = "xmake deb [options] [target]",
        description = "Build, stage and write the Debian package of every target that names a control file.",
        options = {
            {"o", "outputdir", "kv", nil, "Where the packages are written, the build directory by default."},
            {},
            {nil, "target", "v", nil, "Only the package that carries this target."}
        }
    }
