---
name: xmake-rules
description: Use when applying built-in rules (e.g. `mode.debug`, `mode.release`, `qt.widgetapp`, `c++.unity_build`) or writing a custom rule to handle a new file extension or codegen step.
---

# Xmake Rules

Rules are reusable bundles of build logic. You apply them with `add_rules(...)` at project or target scope, or define your own with `rule(...)`.

## Common built-in rules

Build modes (at project scope):

```lua
add_rules("mode.debug", "mode.release", "mode.releasedbg", "mode.minsizerel")
```

This enables `xmake f -m debug|release|...` and sets the corresponding flags.

Target-level built-ins:

```lua
target("app")
    add_rules("c++.unity_build", {batchsize = 8})   -- unity builds
    add_rules("c.unity_build")
    add_rules("win.sdk.application")                -- Windows GUI entry
    add_rules("qt.widgetapp")                       -- Qt widgets app
    add_rules("xcode.application")                  -- iOS/macOS app bundle
    add_rules("plugin.compile_commands.autoupdate", {outputdir = "."})
```

`plugin.compile_commands.autoupdate` automatically regenerates `compile_commands.json` on every build — great for clangd/LSP.

## File-transform rules

These attach to individual files through `add_files(..., {rules = ...})`:

```lua
-- embed a binary file as a c array (foo.bin -> foo.bin.h)
add_files("res/foo.bin", {rules = "utils.bin2c"})

-- embed it as an object file instead, no header generated
add_files("res/foo.bin", {rules = "utils.bin2obj"})

-- patch a source file while building, without touching the file on disk
add_files("src/foo.c", {rules = "utils.replace",
                        replaces = {{"RDKCONST%);", "VDKREG);"}}})
add_files("src/foo.c", {rules = "utils.replace",
                        replaces = {{"RDKCONST);", "VDKREG);"}}, replace_plain = true})
add_files("src/foo.c", {rules = "utils.replace", replaces = function (content)
    return (content:gsub("old", "new"))
end})
```

The generated header holds only the byte list, and the rule adds its directory to the
target's includedirs itself, so the consumer is:

```c
static const unsigned char g_foo[] = {
#include "foo.bin.h"
};
```

`utils.replace` (v3.0.9+) is the clean way to carry a small vendor patch: the transform runs
in the build directory, the repository stays unmodified. `utils.bin2c` / `utils.bin2obj`
(v3.1.0 gained lua-file transforms and ppc/mips support) embed resources without a
generator step.

## Writing a custom rule

Use a rule to teach Xmake how to handle a new file extension.

```lua
rule("protobuf")
    set_extensions(".proto")
    on_load(function (target)
        target:add("includedirs", "$(buildir)/proto")
    end)
    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        local outputdir = path.join(target:autogendir(), "proto")
        local sourcefile_cx = path.join(outputdir, path.basename(sourcefile) .. ".pb.cc")
        batchcmds:mkdir(outputdir)
        batchcmds:vrunv("protoc", {"--cpp_out=" .. outputdir, sourcefile})
        target:add("files", sourcefile_cx)
        batchcmds:add_depfiles(sourcefile)
        batchcmds:set_depmtime(os.mtime(sourcefile_cx))
        batchcmds:set_depcache(target:dependfile(sourcefile_cx))
    end)
rule_end()

target("app")
    add_rules("protobuf")
    add_files("proto/*.proto", "src/*.cpp")
```

## Rule lifecycle hooks

`on_load`, `on_config`, `before_build`, `on_build_file`, `on_buildcmd_file`, `before_link`, `after_build`, `on_clean`, etc. Use the `*cmd*` variants when you want to emit commands into the batch runner (with dependency tracking); use plain hooks for arbitrary Lua logic.

## Applying rules globally vs per target

```lua
add_rules("mode.debug", "mode.release")   -- global: applies to all targets

target("app")
    add_rules("c++.unity_build")          -- only to this target
```

## When to branch out

- File globbing and per-target config → `xmake-targets`
- Cross-compilation tool invocation → `xmake-toolchains`
