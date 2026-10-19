# runs.sh: where a harness puts its build, work and scratch output. Under the checkout's
# .agent-work/runs, never in the system temporary directory (TMPDIR, /tmp, or mktemp with no
# directory): a folder there is wiped without warning, and two checkouts never share one.
#
# Source it from a harness after `here` is set, passing `here`:
#   here=$(cd "$(dirname "$0")" && pwd)
#   . "$here/../../common/runs.sh" "$here"
#   build=${ALERT_BUILD:-$(runs_folder revenant-alert-host)}
#
# runs_folder NAME   a folder NAME under the runs root, created, same folder on every call
# runs_fresh NAME    a new, empty folder NAME.XXXXXX under the runs root, for each call
#
# The checkout is the first directory at or above $1 that holds tests/backports.
runs_checkout=$1
while [ ! -d "$runs_checkout/tests/backports" ]; do
    if [ "$runs_checkout" = / ]; then
        echo "runs.sh: no checkout above $1" >&2
        exit 1
    fi
    runs_checkout=$(dirname "$runs_checkout")
done
runs_root=$runs_checkout/.agent-work/runs
runs_folder() {
    mkdir -p "$runs_root/$1" && printf '%s\n' "$runs_root/$1"
}
runs_fresh() {
    mkdir -p "$runs_root" && mktemp -d "$runs_root/$1.XXXXXX"
}
