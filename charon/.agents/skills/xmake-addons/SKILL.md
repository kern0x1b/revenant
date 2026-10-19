---
name: xmake-addons
description: Use when installing or using an Xmake addon — `xmake addon --install/--list/--remove/--upgrade/--search`, declaring `add_addons(...)` in a project, and referencing addon payloads with `@addon/<name>/<rule>`, `@addon.<name>.<module>` or `@self`. For writing and publishing one, see xmake-addon-development.
---

# Xmake Addons

An addon extends xmake itself: plugins (new commands), rules, toolchains, project
templates, lua modules and includes files. It is installed once per user, not per project.

::: warning
Addons need xmake from the dev branch (they are newer than v3.1.0). Before it, the same
role was played by `xmake plugin --install`, which only handles plugins.
:::

## Install and manage

```bash
xmake addon --install <name>                     # from the repository index
xmake addon --install github:user/repo           # from github, `#branch` is supported
xmake addon --install https://github.com/u/r.git # from any git url
xmake addon --install /path/to/my-addon          # from a local directory
xmake addon --install xmake-repo@serial-tools    # from a specific repository

xmake addon --list                               # installed + available addons
xmake addon --search serial                      # search the repositories
xmake addon --remove serial-tools
xmake addon --remove --all
xmake addon --upgrade                            # upgrade what the current project declares
```

`--force` removes an addon even if other addons depend on it, `-y` skips the confirmations.

## Use an addon in a project

Declare it in `xmake.lua`, xmake installs it automatically when the project is loaded and
records the resolved version in `xmake-addons.lock` next to it:

```lua
add_addons("esp32-devel")            -- any version
add_addons("esp32-devel 1.0.x")      -- a version range
```

Then reference its payloads. Addon payloads are namespaced, so two addons never clash:

```lua
includes("@addon/esp32-devel/board")            -- an includes file of the addon
target("blink")
    add_rules("@addon/esp32-devel/app")         -- a rule of the addon
    set_toolchains("@addon/esp32-devel/esp32")  -- a toolchain of the addon
```

```lua
import("@addon.serial-tools.serial")            -- a module of an addon (dots, not slashes)
```

| Reference | Points at |
| --- | --- |
| `@addon/<name>/<rule\|toolchain\|includes>` | a namespaced payload, used by the project apis |
| `@addon.<name>.<module>` | a lua module of an addon, used by `import()` |
| `@self.<module>` | a module of *the addon which owns the running script* |

Inside your own addon always use `@self`, never hardcode your own name:

```lua
import("@self.private.board")
```

## Where an addon lives

```
~/.xmake/addons/<name>/<version>/   # the installed payloads
~/.xmake/addons/addons.conf         # the registry xmake reads on startup
<project>/xmake-addons.lock         # the versions this project resolved
```

## Gotchas

- Plugins and templates are **not** namespaced — two addons providing `xmake hello` or the
  same template id conflict, and the second install is rejected.
- An installed addon is global. A project only pins the version it wants through
  `add_addons` + `xmake-addons.lock`.
- `xmake addon --upgrade` upgrades what the *current project* declares, not everything.
- Writing or publishing an addon? @see the `xmake-addon-development` skill.
