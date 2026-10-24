#!/bin/sh
set -eu

dir=$1
commit=$2
patches=$3

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$@"
    else
        shasum -a 256 "$@"
    fi
}

marked=""
while read -r name checksum; do
    [ -n "$name" ] || continue
    declared=$(awk '/^---$/{exit} /^Changes-build-output: (yes|no)$/{print $2}' "$dir/$name" | head -n 1)
    if [ "$declared" = yes ]; then
        marked="$marked$name $checksum
"
    elif [ "$declared" != no ]; then
        echo "xmake-patchset: $name does not declare Changes-build-output: yes or no" >&2
        exit 1
    fi
done <<EOF
$patches
EOF

if [ -n "$marked" ]; then
    printf '%s\n%s' "$commit" "$marked" | sha256 | cut -d' ' -f1
fi
