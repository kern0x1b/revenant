---
name: xmake-addon-development
description: Use when writing an Xmake addon — the `addon.lua` manifest, the payload layout (plugins/rules/toolchains/modules/includes/templates), `@self` references, shipping package definitions with an addon, `add_globalmodules`, testing it locally, and publishing it to xmake-repo as an `addon` kind package.
---

# Writing an Xmake Addon

An addon packages xmake extensions — commands, rules, toolchains, templates, modules — so
that a user installs them with one command instead of copying files into `~/.xmake`.
For *using* one, see the `xmake-addons` skill.

## Layout

```
my-addon/
├── addon.lua              # the manifest, the only required file
├── README.md
├── tests/test.lua         # not installed
└── src/                   # the payload root, @see set_sourcedir
    ├── plugins/hello/     # xmake hello           (a new command)
    ├── rules/app/         # add_rules("@addon/my-addon/app")
    ├── toolchains/mycc/   # set_toolchains("@addon/my-addon/mycc")
    ├── modules/           # import("@addon.my-addon.foo") / @self
    ├── includes/board/    # includes("@addon/my-addon/board")
    └── templates/c/foo/   # xmake create -t foo
```

Only the payload directories are installed, so tests, CI files and the README never land in
the user's `~/.xmake/addons/<name>/<version>/`. Ship only what you actually provide.

## The manifest

```lua
-- addon.lua
addon("my-addon")
    set_homepage("https://github.com/me/my-addon")
    set_description("What this addon provides, one line.")
    set_license("Apache-2.0")
    set_sourcedir("src")            -- omit if the payloads sit at the repo root
    add_deps("serial-tools")        -- other addons this one needs
```

The addon names *itself* here, so its name never depends on the repository or the package
that distributes it.

## Reference your own payloads with `@self`

An addon must never hardcode its own name — it can always ask for itself:

```lua
-- in a rule, a toolchain or a plugin of this addon
import("@self.private.board")
```

```lua
-- when you need the name (e.g. to bind your own toolchain to a target)
import("core.package.addon")
local addonname = assert(addon.owner(), "not in an addon!")
target:set("toolchains", "@addon/" .. addonname .. "/mycc")
```

## Ship package definitions

A toolchain addon usually needs binaries. Carry the package recipes and let the project
consume them through an includes file:

```lua
-- src/includes/packages/xmake.lua
package("my-toolchain")
    set_kind("toolchain")
    add_urls("https://.../$(version).tar.gz")
    add_versions("1.0.0", "<sha256>")
    on_install(function (package)
        os.cp("*", package:installdir())
    end)
package_end()
```

```lua
-- src/includes/board/xmake.lua
includes("../packages")
option("board", {default = "uno", description = "Set the target board."})
set_defaultplat("cross")
add_requires("my-toolchain")
```

The project then only writes `includes("@addon/my-addon/board")`.

## Global modules

`add_globalmodules(...)` exposes a module under its plain name. Use it **only** for the
lookups xmake performs by a computed name:

```lua
addon("avr-devel")
    add_globalmodules("detect.tools.find_avrdude",  -- find_tool("avrdude")
                      "core.tools.avr_gcc")         -- the tool module of a compiler
```

```lua
-- src/modules/core/tools/avr_gcc.lua
inherit("core.tools.gcc")   -- avr-gcc is a gcc cross compiler
```

A global module that collides with a module of xmake or of another addon is rejected at
install time. Everything else stays namespaced (`@addon.<name>.<module>`).

::: tip
A finder also *names* the tool: shipping `detect.tools.find_avr_gcc` makes `find_toolname()`
resolve `avr-gcc` to `avr_gcc`, so the matching `core.tools.avr_gcc` module must exist too.
:::

## Test it locally

```bash
xmake addon --install .            # install from the working copy
xmake addon --list
xmake hello                        # exercise the payloads
xmake addon --remove my-addon
```

A `tests/test.lua` which installs, exercises and removes the addon is the standard shape —
it is exactly what a user does, and it runs unchanged in CI.

## Publish to xmake-repo

Addons live in `addons/<first-letter>/<name>/xmake.lua`, beside the C/C++ packages:

```lua
package("my-addon")
    set_kind("addon")
    set_homepage("https://github.com/me/my-addon")
    set_description("What this addon provides, one line.")
    set_license("Apache-2.0")

    add_urls("https://github.com/me/my-addon/archive/refs/tags/$(version).tar.gz",
             "https://github.com/me/my-addon.git")
    add_versions("v1.0.0", "<sha256>")

    add_deps("serial-tools", {kind = "addon"})

    on_test(function (package)
        assert(package:has_addon({rules = "app", toolchains = "mycc",
                                  plugins = "hello", templates = "c/foo"}))
    end)
```

Steps:

1. Tag a release in your addon repository.
2. Compute the sha256 of the tag archive: `xmake l hash.sha256 <file>` (or `shasum -a 256`).
3. Add the recipe, then test it the way the repo CI does:

```bash
xmake l scripts/test_addons.lua --addon my-addon
```

That installs it from your local xmake-repo checkout, runs `on_test`, and removes it again.

4. Send the pull request to [xmake-repo](https://github.com/xmake-io/xmake-repo).

`add_deps` is declared in both files on purpose: the recipe is what xmake reads *before*
downloading the sources, the manifest is what a local directory install reads. The repo test
script checks that the two agree.

## Gotchas

- Plugin task names and template ids are global — pick something unlikely to collide.
- Bump the version in the tag, not in `addon.lua`: the version comes from the package recipe.
- `set_sourcedir` is what keeps `tests/` out of the install; without it everything at the
  repo root that matches a payload name is installed.
