task("compile-commands")
    set_category("plugin")
    on_run("main")
    set_menu {
        usage = "xmake compile-commands [options] [targets]",
        description = "Write compile_commands.json for the named targets only, e.g. the iOS ones without the host tests.",
        options = {
            {"o", "output", "kv", "compile_commands.json", "The file to write."},
            {},
            {nil, "targets", "vs", nil, "The targets, all of them by default."}
        }
    }
