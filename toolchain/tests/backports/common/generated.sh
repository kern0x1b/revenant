ensure_generated() {
    . "$1/../../common/runs.sh" "$1"
    shift
    runs_harness generated "$@" || exit 1
}
