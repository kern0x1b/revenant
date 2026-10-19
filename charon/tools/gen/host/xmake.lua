set_project("apple-backports-host")
set_xmakever("3.0.0")

option("framework")
    set_showmenu(true)
    set_default("")
    set_description("The macOS framework the reference and the constants dylib are built for")
option("sources")
    set_showmenu(true)
    set_default("")
    set_description("The directory of the framework's constants objects (<F>Constants*.m) the dylib is built from")

target("oracle")
    set_kind("binary")
    add_files("../../../tools/gen-objc-constants-oracle.m")
    add_frameworks("Foundation")
    add_mflags("-fobjc-arc")
    set_optimize("none")
    set_symbols("none")

target("constants")
    set_kind("shared")
    add_frameworks("Foundation")
    add_mflags("-fobjc-arc")
    set_optimize("none")
    set_symbols("none")
    on_config(function (target)
        local framework, sources = get_config("framework"), get_config("sources")
        if framework ~= "" and sources ~= "" then
            for _, file in ipairs(os.files(path.join(sources, framework .. "Constants*.m"))) do
                target:add("files", file)
            end
        end
    end)

target("reference")
    set_kind("binary")
    add_files("$(builddir)/gen/reference.m", {always_added = true})
    add_frameworks("Foundation")
    add_mflags("-fobjc-arc")
    set_optimize("none")
    set_symbols("none")
    on_config(function (target)
        local framework = get_config("framework")
        if framework ~= "" then
            target:add("frameworks", framework)
        end
    end)

target("channellayout")
    set_kind("binary")
    add_files("../../../tools/gen-avchannellayout-probe.m")
    add_frameworks("Foundation", "AVFAudio")
    add_mflags("-fobjc-arc")
    set_optimize("none")
    set_symbols("none")
