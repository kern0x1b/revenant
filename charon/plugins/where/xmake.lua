task("where")
    set_category("plugin")
    on_run("main")
    set_menu {
        usage = "xmake where PACKAGE",
        description = "Print where a package the project requires is installed, for scripts that read its files.",
        options = {
            {nil, "package", "v", nil, "The name or alias the project requires it by."}
        }
    }
