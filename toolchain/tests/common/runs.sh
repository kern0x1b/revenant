runs_checkout=$1
while [ ! -f "$runs_checkout/tests/light.lua" ]; do
    if [ "$runs_checkout" = / ]; then
        echo "runs.sh: no toolchain above $1" >&2
        exit 1
    fi
    runs_checkout=$(dirname "$runs_checkout")
done
runs_folder() {
    "$runs_checkout/../xmakew" l "$runs_checkout/modules/workspace.lua" run "$1"
}
