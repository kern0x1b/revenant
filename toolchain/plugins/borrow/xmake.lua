task("borrow")
    set_category("plugin")
    on_run("main")
    set_menu {
        usage = "xmake borrow [options] PACKAGE ...",
        description = "Take the installs of a package this store lacks from another store, cloned rather than built again.",
        options = {
            {"f", "from", "kv", nil, "The store to take them from (default: the one beside $HOME)."},
            {},
            {nil, "packages", "vs", nil, "The packages to take, e.g. xmake borrow llvm swift."}
        }
    }
