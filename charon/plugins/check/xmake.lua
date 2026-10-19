task("check")
    set_category("plugin")
    on_run("main")
    set_menu {
        usage = "xmake check [options] [names]",
        description = "Run the checks the project declares with the check rule, all of them or those whose files changed.",
        options = {
            {nil, "staged", "k", nil, "Only the checks whose files are staged, given those files; what a pre-commit hook runs."},
            {nil, "changed", "k", nil, "Only the checks whose files differ from HEAD."},
            {nil, "install-hook", "k", nil, "Make .git/hooks/pre-commit run xmake check --staged."},
            {},
            {nil, "names", "vs", nil, "Only the named checks."}
        }
    }
