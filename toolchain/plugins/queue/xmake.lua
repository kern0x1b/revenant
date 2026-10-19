task("queue")
    set_category("plugin")
    on_run("main")
    set_menu {
        usage = "xmake queue [options] -- COMMAND [arguments]",
        description = "Run a build of this machine in one of its build slots, so several sessions building at once do not each take the whole machine.",
        options = {
            {"c", "count", "kv", nil, "How many builds this machine runs at once (default: a quarter of its cores, at least two)."},
            {},
            {nil, "command", "vs", nil, "The command to run, after --, e.g. xmake queue -- xmake build."}
        }
    }
