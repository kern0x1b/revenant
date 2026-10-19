-- The host programs of the generator's differential and probe (design-spec-driven.md D5). The generator (tools/gen/host.lua)
-- configures this project for one framework (--framework, --sources) and builds the targets; xmake rebuilds only what changed.
-- The build directory is the one xmake reports (build/ under this folder when the working directory is this folder).

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

-- The probe: tools/gen-objc-constants-oracle.m, a fixed source. Reads the value of each named constant of a library.
target("oracle")
    set_kind("binary")
    add_files("../../../tools/gen-objc-constants-oracle.m")
    add_frameworks("Foundation")
    add_mflags("-fobjc-arc")
    set_optimize("none")
    set_symbols("none")

-- The constants dylib: the framework's generated constants objects, as the oracle loads them on the host.
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

-- The reference: the macOS value of each name, read through the framework's own symbols. The generator writes reference.m
-- into the build directory for the framework's names before each build.
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

-- The channel layout probe: tools/gen-avchannellayout-probe.m, a fixed source that calls -[AVAudioChannelLayout initWithLayout:]
-- of the host's AVFAudio with one input per run (null, tag0, unknown, stereo). Not part of the generator's configuration.
target("channellayout")
    set_kind("binary")
    add_files("../../../tools/gen-avchannellayout-probe.m")
    add_frameworks("Foundation", "AVFAudio")
    add_mflags("-fobjc-arc")
    set_optimize("none")
    set_symbols("none")
