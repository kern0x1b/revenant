# work-guard.sh - ONE definition of what a scratch path may be, for every script that removes one.
#
#     . work-guard.sh && work_ok "$SOME_PATH" || refuse
#
# `rm -rf` takes its argument from a variable that a caller can set, so the rule is: a path is usable
# only if it is non-empty, absolute, carries no `..` once normalised, and lies STRICTLY under this
# worktree's own .agent-work. `rm -rf ""` is harmless, `rm -rf /` is not, and a path like
# $root/.agent-work/../packages is a perfectly good way to remove the source tree. Both scripts had
# their own copy of this and each was wrong about something, so there is one now.
#
# The base is the worktree that CONTAINS this file, so the guard cannot be satisfied by pointing it
# somewhere else.
work_guard_base=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../../.." && pwd)/.agent-work

work_ok() {
    candidate=$1
    case "$candidate" in
        "") return 1 ;;                      # empty: rm -rf "" is harmless but the CALLER has no scratch
        /*) ;;                               # absolute, or refused
        *) return 1 ;;
    esac
    # no `..` component once normalised: a path that walks out is not a path under the worktree
    normalised=$(printf '%s' "$candidate" | sed -e 's|/\./|/|g' -e 's|/$||')
    case "/$normalised/" in */../*) return 1 ;; esac
    # and it must be STRICTLY under the worktree's .agent-work, not that directory itself
    [ "$normalised" != "$work_guard_base" ] || return 1
    case "$normalised/" in
        "$work_guard_base"/*) ;;
        *) return 1 ;;
    esac
    return 0
}
