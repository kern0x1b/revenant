runs_checkout=$1
while [ ! -d "$runs_checkout/tests/backports" ]; do
    if [ "$runs_checkout" = / ]; then
        echo "runs.sh: no checkout above $1" >&2
        exit 1
    fi
    runs_checkout=$(dirname "$runs_checkout")
done
runs_xmake() {
    "$runs_checkout/../xmakew" "$@"
}
runs_harness() {
    runs_xmake l "$runs_checkout/tests/backports/common/harness.lua" "$@"
}
runs_folder() {
    runs_harness folder "$1"
}
runs_fresh() {
    runs_harness fresh "$1"
}
runs_sdk() {
    runs_harness sdk
}
runs_corpus() {
    runs_harness corpus "$@"
}
