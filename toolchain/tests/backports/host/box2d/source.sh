# source.sh — sourced, not run: fetches Box2D as charon@box2d does, from the recipe's pinned URL,
# checks the archive against the recipe's digest and unpacks it. The caller sets `box2d` (this
# directory) and `BUILD` (where the archive is kept and unpacked); this sets `version`, `digest`,
# `url`, `flags` (the recipe's compiler flags) and `source` (the unpacked tree, $BUILD/src/...).
recipe=$box2d/../../../../packages/b/box2d/xmake.lua
version=$(sed -n 's/.*add_versions("\([^"]*\)", "[0-9a-f]*").*/\1/p' "$recipe")
digest=$(sed -n 's/.*add_versions("[^"]*", "\([0-9a-f]*\)").*/\1/p' "$recipe")
url=$(sed -n 's/.*add_urls("\([^"]*\)").*/\1/p' "$recipe" | sed "s/\$(version)/$version/")
flags=$(sed -n 's/.*local FLAGS = {\(.*\)}.*/\1/p' "$recipe" | tr -d '",')
[ -n "$version" ] && [ -n "$digest" ] && [ -n "$url" ] && [ -n "$flags" ] || { echo "FAIL: the recipe names no version, digest, URL or flags"; exit 1; }
archive=$BUILD/Box2D_v$version.zip
[ -f "$archive" ] || curl -fsSL "$url" -o "$archive"
[ "$(shasum -a 256 "$archive" | cut -d' ' -f1)" = "$digest" ] || { echo "FAIL: $archive is not the recipe's archive"; exit 1; }
rm -rf "$BUILD/src"
mkdir -p "$BUILD/src"
unzip -q "$archive" -d "$BUILD/src"
source=$BUILD/src/Box2D_v$version
