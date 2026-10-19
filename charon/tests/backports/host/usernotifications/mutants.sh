#!/bin/sh
# mutants.sh — each mutant of the hidden previews of a notification category has to be told apart by the differential of run.sh.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
uikit=${UIKIT:-$here/../../../../packages/a/apple-backports/UIKit}
build=${BUILD:-$(runs_fresh charon-usernotifications)}
survived=0
mutant() {
    rm -rf "$build/uikit"; mkdir -p "$build/uikit"
    cp "$uikit"/UN*.m "$uikit"/CharonUserNotifications.h "$build/uikit/"
    python3 - "$build/uikit/$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1:4]
text = open(path).read()
assert old in text, old
open(path, "w").write(text.replace(old, new, 1))
PY
    if UIKIT="$build/uikit" BUILD="$build/run" sh "$here/run.sh" > "$build/out.txt" 2>&1 && ! grep -q "^FAIL" "$build/out.txt" && grep -q " 0 failures" "$build/out.txt"; then
        echo "MUTANT SURVIVED: $2 -> $3"; survived=$((survived + 1))
    fi
}
mutant "UNNotificationCategory+HiddenPreviews.m" "return held == [NSNull null] ? nil : (held ?: @\"\");" "return held ?: @\"\";"
mutant "UNNotificationCategory+HiddenPreviews.m" "return held == [NSNull null] ? nil : (held ?: @\"\");" "return held == [NSNull null] ? nil : held;"
mutant "UNNotificationCategory+HiddenPreviews.m" "return charon_held(self, &charon_placeholder_key);" "return charon_held(self, &charon_summary_key);"
mutant "UNNotificationCategory+HiddenPreviews.m" "return charon_held(self, &charon_summary_key);" "return charon_held(self, &charon_placeholder_key);"
mutant "UNNotificationCategory+HiddenPreviews.m" "hiddenPreviewsBodyPlaceholder categorySummaryFormat:@\"\" options:options];" "hiddenPreviewsBodyPlaceholder categorySummaryFormat:@\"x\" options:options];"
mutant "UNNotificationCategory+HiddenPreviews.m" "objc_setAssociatedObject(category, &charon_placeholder_key, [hiddenPreviewsBodyPlaceholder copy] ?: [NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);" ""
mutant "UNNotificationCategory.m" "&& (self.hiddenPreviewsBodyPlaceholder == other.hiddenPreviewsBodyPlaceholder || [self.hiddenPreviewsBodyPlaceholder isEqualToString:other.hiddenPreviewsBodyPlaceholder])" ""
echo "mutants surviving: $survived"
[ "$survived" -eq 0 ]
