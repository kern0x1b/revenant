#!/bin/bash
set -u
SRC="$1"; OUT="$2"; SEED="${3:-20261014}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT/run-apple" "$OUT/run-ours"
: "${APPLE_COMPAT:?set APPLE_COMPAT to packages/a/apple-compat}"
HOSTOBJ=()
for f in shims csystem_port; do xcrun clang -c "$SRC/Sources/CSystem/$f.c" -I "$SRC/Sources/CSystem/include" -I "$APPLE_COMPAT/include" -o "$OUT/$f-host.o" || exit 1; HOSTOBJ+=("$OUT/$f-host.o"); done
for f in openat unlinkat fdopendir fstatat; do xcrun clang -c "$APPLE_COMPAT/src/$f.c" -I "$APPLE_COMPAT/include" -o "$OUT/compat-$f-host.o" || exit 1; HOSTOBJ+=("$OUT/compat-$f-host.o"); done
SWIFTS=$(find "$SRC/Sources/System" -name "*.swift" -not -path "*/IORing/*" | sort)
AVAIL=(-enable-experimental-feature "AvailabilityMacro=System 0.0.1:macOS 10.10, iOS 6.1.3")
for v in 0.0.2 0.0.3 1.1.0 1.1.1 1.2.0 1.2.1 1.3.0 1.3.1 1.3.2 1.4.0 1.7.0 199; do
  AVAIL+=(-enable-experimental-feature "AvailabilityMacro=System $v:macOS 10.10, iOS 6.1.3")
done
xcrun swiftc -swift-version 5 -enable-experimental-feature Lifetimes -I "$SRC/Sources/CSystem/include" \
  -I "$APPLE_COMPAT/include" -D SYSTEM_PACKAGE_DARWIN -D SYSTEM_PACKAGE -module-name SystemUnderTest \
  -emit-library -emit-module -emit-module-path "$OUT/SystemUnderTest.swiftmodule" \
  -o "$OUT/libSystemUnderTest.dylib" "${HOSTOBJ[@]}" "${AVAIL[@]}" $SWIFTS || exit 1
ROWFILES="$HERE/main.swift $HERE/rows.swift $HERE/constants.swift"
xcrun swiftc -swift-version 5 $ROWFILES -o "$OUT/apple-prog" || exit 1
xcrun swiftc -swift-version 5 -D OURS -I "$OUT" -I "$SRC/Sources/CSystem/include" -L "$OUT" -lSystemUnderTest \
  -Xlinker -rpath -Xlinker "$OUT" $ROWFILES -o "$OUT/ours-prog" || exit 1
"$OUT/apple-prog" "$OUT/run-apple" "$SEED" > "$OUT/apple.txt" 2>&1; echo "apple rc=$?"
"$OUT/ours-prog" "$OUT/run-ours" "$SEED" > "$OUT/ours.txt" 2>&1; echo "ours rc=$?"
if diff "$OUT/apple.txt" "$OUT/ours.txt" > "$OUT/diff.txt"; then echo "DIFFERENTIAL: identical, $(wc -l < "$OUT/apple.txt") lines"; else echo "DIFFERENTIAL: DIFFERENT, $(wc -l < "$OUT/diff.txt") diff lines"; exit 1; fi
grep '^row ' "$OUT/apple.txt" > "$OUT/rows-apple.txt"; grep '^row ' "$OUT/ours.txt" > "$OUT/rows-ours.txt"
if awk '{print $2}' "$OUT/rows-apple.txt" | sort | diff - "$HERE/carried-rows.txt" > "$OUT/rows-names.diff"; then echo "ROW NAMES: the $(wc -l < "$OUT/rows-apple.txt" | tr -d ' ') rows are exactly carried-rows.txt"; else echo "ROW NAMES: DO NOT MATCH carried-rows.txt (see rows-names.diff)"; fi
paste -d'\t' "$OUT/rows-apple.txt" "$OUT/rows-ours.txt" | awk -F'\t' '/ not-exercised$/ { skip++; next } $1 == $2 { same++; next } { diff++ } END { printf "ROWS: %d identical, %d different, %d not exercised on the host (reasons in run-apple/rows-detail.txt)\n", same, diff, skip }'
[ "$(grep -c '^row ' "$OUT/ours.txt")" -gt 0 ] && cmp -s "$OUT/run-apple/rows-detail.txt" "$OUT/run-ours/rows-detail.txt" && echo "ROWS detail: identical observations" || echo "ROWS detail: observations differ (see run-*/rows-detail.txt)"
mkdir -p "$OUT/run-compat/sub"; echo hi > "$OUT/run-compat/a"; echo x > "$OUT/run-compat/sub/c"
for f in openat unlinkat fdopendir fstatat; do xcrun clang -c -I "$APPLE_COMPAT/include" "$APPLE_COMPAT/src/$f.c" -o "$OUT/compat-$f.o" || exit 1; done
xcrun clang -c -I "$APPLE_COMPAT/include" "$HERE/compat.c" -o "$OUT/compat-test.o" || exit 1
xcrun clang "$OUT"/compat-openat.o "$OUT"/compat-unlinkat.o "$OUT"/compat-fdopendir.o "$OUT"/compat-fstatat.o "$OUT/compat-test.o" -o "$OUT/compat-test" || exit 1
"$OUT/compat-test" "$(cd "$OUT/run-compat" && pwd)" "$SEED" > "$OUT/compat.txt" 2>&1; echo "compat rc=$?: $(grep -c ' same' "$OUT/compat.txt") fstatat same, $(grep -c DIFFERENT "$OUT/compat.txt") different, $(grep -c 'gone=1' "$OUT/compat.txt") unlinks gone"
