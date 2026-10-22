# 0005: Lua only, no Python

Status: accepted; for an upstream's own build, its tooling is governed by [0013](0013-upstream-builds-keep-their-python.md), which supersedes this rule there

## Context

The repository's tools used to mix Lua, Python and shell. Each language needed its own interpreter on the
machine, its own version, and its own way to find the repository, and a Python script could not see the
xmake modules that the rest of the build used.

## Decision

Build logic, tests and tools are Lua, run by xmake (`./xmakew l`, `./xmakew test`). There is no Python, and no
shell script beside `./xmakew` (see 0003). A script that needs a system tool calls it with `os.iorunv` or
`os.execv` from Lua.

## Consequences

- A tool gets the xmake modules (`core.base.json`, `lib.detect.find_tool`, `async.runjobs`) without a second
  language's parser.
- A tool that was Python is rewritten in Lua. Documents describe the Lua tool and its `--help`, not the old script.
- Workflow files (`.github/workflows/*.yml`) keep their shell `run:` steps; they are CI configuration, not tools.

## Enforced by

`repository/layout`: a tracked file ending in `.py` fails. Shell scripts fail under 0003.

## Not enforced

Python inside a fetched upstream (a package's sources are not tracked, so the check does not see them).
Python named in a command line of a document is not checked.
