work_guard_base=$(runs_folder metal-census)

work_ok() {
    candidate=$1
    case "$candidate" in
        "") return 1 ;;
        /*) ;;
        *) return 1 ;;
    esac
    normalised=$(printf '%s' "$candidate" | sed -e 's|/\./|/|g' -e 's|/$||')
    case "/$normalised/" in */../*) return 1 ;; esac
    [ "$normalised" != "$work_guard_base" ] || return 1
    case "$normalised/" in
        "$work_guard_base"/*) ;;
        *) return 1 ;;
    esac
    return 0
}
