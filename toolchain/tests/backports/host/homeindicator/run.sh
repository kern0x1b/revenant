#!/bin/sh
# run.sh — records what the system's UIKit answers for every case of device/homeindicator-cases.m in a Mac Catalyst binary, writes the
# answers where the device test reads them, then compiles the port's own categories over the system's classes (a category replaces the
# method it names) and holds them to the same records, with mutants of the port that each have to be told apart.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
device=${DEVICE:-$here/../../device}
uikit=${UIKIT:-$here/../../../../packages/frameworks/apple-backports/UIKit}
build=${BUILD:-$(runs_fresh revenant-homeindicator)}
sdk=$(xcrun --show-sdk-path)
compile() {
    output=$1; shift
    xcrun clang -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" -fobjc-arc -w -I"$device" \
        "$here/record.m" "$device/homeindicator-cases.m" "$@" -framework UIKit -framework Foundation -framework CoreGraphics -o "$output"
}
sources() { echo "$uikit/UIViewController+HomeIndicator.m" "$uikit/UINavigationBar+LargeTitles.m"; }
compile "$build/system"
HOMEINDICATOR_RECORDS="$build/system.json" "$build/system"
xmake l "$here/../../common/embed.lua" "$build/system.json" "$device/homeindicator-expectations.h" homeindicator_expectations
echo "records: $(jq length "$build/system.json")"

mkdir -p "$build/port"
for file in UIViewController+HomeIndicator UINavigationBar+LargeTitles; do cp "$uikit/$file.m" "$build/port/$file.m"; done
compile "$build/port/run" "$build/port/UIViewController+HomeIndicator.m" "$build/port/UINavigationBar+LargeTitles.m"
HOMEINDICATOR_RECORDS="$build/port.json" "$build/port/run"
if cmp -s "$build/system.json" "$build/port.json"; then echo "port: same as the system"; else diff "$build/system.json" "$build/port.json" || true; echo "port: DIFFERS"; exit 1; fi

mutant() {
    file=$1; from=$2; to=$3
    rm -rf "$build/mutant"; mkdir -p "$build/mutant"
    cp "$uikit/UIViewController+HomeIndicator.m" "$uikit/UINavigationBar+LargeTitles.m" "$build/mutant/"
    xmake lua "$here/replace.lua" "$build/mutant/$file" "$from" "$to"
    compile "$build/mutant/run" "$build/mutant/UIViewController+HomeIndicator.m" "$build/mutant/UINavigationBar+LargeTitles.m"
    rm -f "$build/mutant.json"
    HOMEINDICATOR_RECORDS="$build/mutant.json" "$build/mutant/run" || true
    if cmp -s "$build/system.json" "$build/mutant.json"; then echo "MUTANT SURVIVED: $file $from -> $to"; survived=$((survived + 1)); fi
}
survived=0
mutant UIViewController+HomeIndicator.m "prefersHomeIndicatorAutoHidden
{
    return NO;" "prefersHomeIndicatorAutoHidden
{
    return YES;"
mutant UIViewController+HomeIndicator.m "return UIRectEdgeNone;" "return UIRectEdgeAll;"
mutant UIViewController+HomeIndicator.m "UIViewController *parent = self.parentViewController ?: self.presentingViewController;
    [parent setNeedsUpdateOfHomeIndicatorAutoHidden];" "UIViewController *parent = nil;
    [parent setNeedsUpdateOfHomeIndicatorAutoHidden];"
mutant UIViewController+HomeIndicator.m "[parent setNeedsUpdateOfScreenEdgesDeferringSystemGestures];" "[parent setNeedsUpdateOfHomeIndicatorAutoHidden];"
mutant UIViewController+HomeIndicator.m "childViewControllerForHomeIndicatorAutoHidden
{
    return self.topViewController;" "childViewControllerForHomeIndicatorAutoHidden
{
    return nil;"
mutant UIViewController+HomeIndicator.m "childViewControllerForHomeIndicatorAutoHidden
{
    return self.selectedViewController;" "childViewControllerForHomeIndicatorAutoHidden
{
    return self.viewControllers.firstObject;"
mutant UINavigationBar+LargeTitles.m "[attributes copy]" "attributes"
mutant UINavigationBar+LargeTitles.m "return [objc_getAssociatedObject(self, RevenantPrefersLargeTitlesKey) boolValue];" "return YES;"
mutant UINavigationBar+LargeTitles.m "static const void *RevenantLargeTitleAttributesKey = &RevenantLargeTitleAttributesKey;" "static const void *RevenantLargeTitleAttributesKey = &RevenantPrefersLargeTitlesKey;"
mutant UINavigationBar+LargeTitles.m "return (UINavigationItemLargeTitleDisplayMode)[objc_getAssociatedObject(self, RevenantLargeTitleModeKey) integerValue];" "return UINavigationItemLargeTitleDisplayModeAutomatic;"
echo "mutants surviving: $survived"
[ "$survived" -eq 0 ]
