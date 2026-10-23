# Proving code unused

Deleting a file or a function is safe when nothing in the repository reaches it. A grep for its literal name does
not show every way in. This repository builds paths at run time, loads modules by a variable, and finds files with
globs. The swift-runtime recipe reads its `patches/simd` folder through a path built from the SDK's release, so a
search for the patch files found no use, and the removal broke the swift-runtime prebuild. Check each way in below,
and say in the commit message what was searched.

## The ways in

- **The name.** `git grep -n -w '<name>'` over the whole tree, not only `*.lua`: the xmake files, the shell and CI
  scripts, the docs and the test data.
- **A built path.** `path.join(os.scriptdir(), "patches", "simd", release, "*.patch")` names `patches/simd` with no
  literal path in it. Search for each segment as a string (`"simd"`, `"patches"`) and for the folder the file sat in.
- **A glob.** `os.files`, `os.dirs` and `os.filedirs` match a removed file without naming it. List every glob whose
  base folder contains the file, and check whether its pattern reaches it: `**`, `*` and `*.patch` all do.
- **An import by variable.** `import(name, ...)` loads whatever `name` holds. List the calls whose argument is not a
  string literal, `git grep -n -E 'import\(\s*[^"]'`, and the calls that build a literal with `..`,
  `git grep -n -E 'import\("[^"]*"\s*\.\.'`. Then find where the variable comes from.
- **A call by name.** A function read from a table by a string, as in `module[name]`, and `_G[name]`, `rawget` and
  `getfenv`, reach a function by its name. Search for them in the module's folder and in its callers.
- **A list of names.** A table of suites, packages or targets that a loop walks. Check that every name in it still
  resolves.

## Checking a removal

1. Confirm the file or the function is on the base the removal is made from: `git cat-file -e origin/main:<path>`. A
   path that is not on the base is not removed by the change.
2. Search the tree after the removal with each form above.
3. Run the tests of the area: `./xmakew test -P . 'repository/*'`, and the suite of the area. A package that only a
   prebuilt job builds is not proved by a local test, so check that job's inputs as well.
4. If the file is an input to a package's digest, run `./xmakew l tools/keys.lua <package>` before and after the
   change, to see what the change rebuilds. The digest configs are in [the machine guide](machine.md#build-each-package-once).
5. Put the search in the commit message in one sentence: which forms were searched, and where.
