#!/bin/sh
# run.sh — differential host tests for the second UIKit batch: the backported sources are compiled for
# Mac Catalyst with their classes, selectors and constants renamed, so each test can put the backport and
# the system implementation side by side in one process. The spring curve is checked against a real
# CASpringAnimation, which needs AppKit, so that part runs as a plain macOS tool.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/../../common/runs.sh" "$here"
sources=${UIKIT2_SOURCES:-$here/../../../../packages/a/apple-backports/UIKit}
harness=${UIKIT2_HARNESS:-$here/../../device}
build=${UIKIT2_BUILD:-$(runs_folder charon-uikit2-host)}
sdk=$(xcrun --show-sdk-path)
target="-target arm64-apple-ios15.0-macabi -isysroot $sdk -iframework $sdk/System/iOSSupport/System/Library/Frameworks"
frameworks="-framework LocalAuthentication -framework MobileCoreServices -framework SafariServices -framework UIKit -framework QuartzCore -framework CoreGraphics -framework Foundation"
flags="-DCHARON_HOST_DIFFERENTIAL=1 -fobjc-arc -fvisibility=hidden -Wall -Wno-deprecated-declarations -Wno-unguarded-availability-new -Wno-objc-protocol-method-implementation -Wno-incomplete-implementation -Wno-objc-property-implementation"
rm -rf "$build"
mkdir -p "$build/plain"
export CHARON_DATA_ASSETS="$here/../../device/data-assets/Assets.car"
if [ -n "${CHARON_DATA_ASSET_CATALOG:-}" ] && [ -f "$CHARON_DATA_ASSET_CATALOG" ]; then
    assetutil --info "$CHARON_DATA_ASSET_CATALOG" > "$build/charon-dataassets.json"
fi

# UIKIT2_ONLY narrows the run to the named groups, space-separated.  Empty - the default - runs all of
# them, so an ordinary invocation is unaffected.  It is for the per-group controls: the suite is over ten
# minutes, and a control that waits for every other group before it reaches its own never runs at all.
only=${UIKIT2_ONLY:-}

. "$here/renames.sh"
prefixer="$here/../prefix_selectors.lua"

defines_what_it_calls() {
    # $1: the test's binary, $2: the test's source, rest: the port's objects. A prefixed selector the test names
    # and no object defines is a link-time no-op and an unrecognized selector when the test reaches it, which
    # nothing in the gate sees; check-private-selectors.lua is the check, and it runs over what this group just
    # built. The source goes with it so the check can tell a whole selector from a piece of one: a test that
    # spells the name it sends at run time holds that name's pieces as literals, and
    # [@"charonHostSet" stringByAppendingString:...] is not a selector anything has to define.
    binary=$1
    source=$2
    shift 2
    if ! xmake l "$here/../check-private-selectors.lua" --source "$source" "$binary" "$@"; then
        status=1
    fi
}

carried() {
    # $1: every object of the group. The selectors the port's Charon categories carry, in the whole group and
    # not per file: a file that sends one of them without defining it needs the prefix as much as the file
    # that defines it, and a send left unprefixed is an unrecognized selector at run time.
    nm $1 | sed -n 's/.*[-+]\[[A-Za-z_]*(\(Charon[A-Za-z0-9_]*\)) \([A-Za-z_][A-Za-z0-9_:]*\)\]$/\2/p' | sort -u > "$build/$name.carried"
}

prefixed_build() {
    # $1: group name, $2: sources. A group whose port sources add categories to classes the system owns cannot
    # use the plain path: renames() renames whole identifiers, and a selector is not one (setObject:forTrait: is
    # three), so the port's method would take the name the system's already has and the two sides would be one.
    # Each file is compiled once plain, to learn the classes, the C symbols and the selectors its Charon
    # categories carry, then rewritten by prefix_selectors.lua, which prefixes those selectors whole, then
    # compiled again with the class renames and the declarations of the prefixed selectors. Every group of this
    # file that adds no category to a system class stays on the plain path.
    # It leaves the objects in $built and returns 0, or prints what failed, sets status and returns 1; each
    # caller answers that with `|| return 0`, which reports the group and lets the run continue.
    name=$1
    files=$2
    objects=""
    built=""
    rm -f "$build/$name.declarations.h"
    for file in $files; do
        if ! xcrun clang $target $flags -w -c "$sources/$file" -o "$build/plain/$name-$(basename "$file").o" \
            2> "$build/plain/$name-$(basename "$file").o.diagnostic"; then
            printf 'FAIL %s: %s does not compile\n' "$name" "$file"
            grep -m1 'error:' "$build/plain/$name-$(basename "$file").o.diagnostic" | sed 's|^|  |'
            status=1
            return 1
        fi
        objects="$objects $build/plain/$name-$(basename "$file").o"
    done
    renames "$objects" > "$build/$name.flags"
    carried "$objects" || : > "$build/$name.carried"
    [ -s "$build/$name.carried" ] || printf 'note %s carries no selector a category adds\n' "$name"
    mkdir -p "$build/rewritten/$name" "$build/$name"
    printf '#import <UIKit/UIKit.h>\n' > "$build/$name.declarations.h"
    for file in $files; do
        base=$(basename "$file")
        source=$build/rewritten/$name/$base
        case "$file" in
            *.m | *.mm) objective_c=1 ;;
            *) objective_c= ;;
        esac
        if [ -n "$objective_c" ] && [ -s "$build/$name.carried" ]; then
            # The group's own -D renames go to the rewriter as well as to the compile below, because they are
            # what its AST filter needs to see the port's classes: they are named in the source exactly as the
            # SDK names them, so `-ast-dump-filter=haron` drops their bodies whole, and a send of a carried
            # selector from inside one was left unrenamed. prefix_selectors.lua's group_renames() reads them back
            # and maps every name it meets to the spelling the source uses, so nothing else changes.
            if ! xmake l "$prefixer" "$sources/$file" "$source" charonHost \
                --declarations="$build/$name.declarations.h" \
                --sources="$(for f in $files; do printf '%s,' "$sources/$f"; done | sed 's/,$//')" \
                $(cat "$build/$name.flags") $flags -I"$sources" \
                -I"$(dirname "$sources/$file")" \
                -target arm64-apple-ios15.0-macabi -isysroot "$sdk" -iframework "$sdk/System/iOSSupport/System/Library/Frameworks" \
                -- $objects; then
                printf 'FAIL %s: %s cannot be rewritten\n' "$name" "$file"
                status=1
                return 1
            fi
        else
            cp "$sources/$file" "$source"
        fi
    done
    built=""
    for file in $files; do
        base=$(basename "$file").o
        source=$build/rewritten/$name/${base%.o}
        # A file that is not Objective-C is compiled WITHOUT the declarations header, which force-includes
        # <UIKit/UIKit.h>: a C file cannot parse it, and Foundation's NSObjCRuntime.h then fails at its
        # first Objective-C declaration with "error: expected identifier or '('". There are no selectors in
        # a C file to prefix either, so the rewriter above skips it for the same reason. The renames still
        # apply - they come from the flags, which every file of the group gets - so a C symbol this group
        # defines is still prefixed, which is the whole of what foundation14networkaccess needs of its .c.
        # Both words of the option go, not the flag alone: leaving the header path behind made it a second
        # input file and clang answered "cannot specify -o when generating multiple output files".
        case "$file" in
            *.m | *.mm) header="-include" ;;
            *) header="forced-header off" ;;
        esac
        if [ "$header" = "-include" ]; then
            set -- -include "$build/$name.declarations.h"
        else
            set --
        fi
        if ! xcrun clang $target $flags -I"$sources" -I"$(dirname "$sources/$file")" \
            "$@" $(cat "$build/$name.flags") -c "$source" -o "$build/$name/$base" \
            2> "$build/$name/$base.diagnostic"; then
            printf 'FAIL %s: the rewritten %s does not compile\n' "$name" "$file"
            grep -m1 'error:' "$build/$name/$base.diagnostic" | sed "s|$source|$file|; s|^|  |"
            status=1
            return 1
        fi
        built="$built $build/$name/$base"
    done
}

prefixed_group() {
    # $1: group name, $2: sources, $3: test source
    name=$1
    if [ -n "$only" ]; then
        case " $only " in *" $name "*) : ;; *) return 0 ;; esac
    fi
    prefixed_build "$name" "$2" || return 0
    test=$3
    xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/$test" "$harness/check.m" $built $frameworks -o "$build/$name-test"
    defines_what_it_calls "$build/$name-test" "$here/$test" $built
    if "$build/$name-test" > "$build/$name.log" 2>&1; then result=0; else result=$?; fi
    grep -v '^ok ' "$build/$name.log" || true
    echo "$name: exit=$result log=$build/$name.log"
    [ "$result" = 0 ] || status=1
}

prefixed_windowed() {
    # $1: group name, $2: sources, $3: test source; as windowed, over the prefixed build.
    # The UIKIT2_ONLY gate is here and was not: group() and windowed() both skip a group that is not in
    # scope, and this one built and ran every prefixed group whatever was asked for, so a per-group control
    # that meant to run one group waited for all of them - and the whole prefixed table, which is most of
    # the file, before it reached its own. Measured on /bin/sh here, the same gate the other two helpers
    # read, so there is one rule and not two.
    name=$1
    if [ -n "$only" ]; then
        case " $only " in *" $name "*) : ;; *) return 0 ;; esac
    fi
    prefixed_build "$name" "$2" || return 0
    test=$3
    bundle="$build/$name.app"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents/MacOS"
    xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/windowed.m" "$here/$test" "$harness/check.m" $built $frameworks -o "$bundle/Contents/MacOS/app"
    cp "$here/windowed.plist" "$bundle/Contents/Info.plist"
    codesign -s - --force "$bundle" > /dev/null 2>&1
    defines_what_it_calls "$bundle/Contents/MacOS/app" "$here/$test" $built
    if "$bundle/Contents/MacOS/app" > "$build/$name.log" 2>&1; then result=0; else result=$?; fi
    grep -v '^ok ' "$build/$name.log" | grep -a 'FAIL\|checks=\|info' || true
    echo "$name: exit=$result log=$build/$name.log"
    [ "$result" = 0 ] || status=1
}

group() {
    # $1: group name, $2: sources, $3: test source. The keep list is gone with the renamer that read it:
    # prefix_selectors.lua derives the carried selectors from the objects, so nothing is lost by not passing one,
    # and every group line in this file - main's own included - passes three arguments.
    name=$1
    if [ -n "$only" ]; then
        case " $only " in *" $name "*) : ;; *) return 0 ;; esac
    fi
    files=$2
    test=$3
    objects=""
    for file in $files; do
        xcrun clang $target $flags -w -c "$sources/$file" -o "$build/plain/$name-$(basename "$file").o"
        objects="$objects $build/plain/$name-$(basename "$file").o"
    done
    renames "$objects" > "$build/$name.flags"
    mkdir -p "$build/$name"
    built=""
    for file in $files; do
        xcrun clang $target $flags $(cat "$build/$name.flags") -c "$sources/$file" -o "$build/$name/$(basename "$file").o"
        built="$built $build/$name/$(basename "$file").o"
    done
    xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/$test" "$harness/check.m" $built $frameworks -o "$build/$name-test"
    if "$build/$name-test" > "$build/$name.log" 2>&1; then result=0; else result=$?; fi
    grep -v '^ok ' "$build/$name.log" || true
    echo "$name: exit=$result log=$build/$name.log"
    [ "$result" = 0 ] || status=1
}

windowed() {
    # $1: group name, $2: sources, $3: test source; the test runs in an application with a window, against the system
    name=$1
    if [ -n "$only" ]; then
        case " $only " in *" $name "*) : ;; *) return 0 ;; esac
    fi
    files=$2
    test=$3
    objects=""
    for file in $files; do
        xcrun clang $target $flags -w -c "$sources/$file" -o "$build/plain/$name-$(basename "$file").o"
        objects="$objects $build/plain/$name-$(basename "$file").o"
    done
    renames "$objects" > "$build/$name.flags"
    mkdir -p "$build/$name"
    built=""
    for file in $files; do
        xcrun clang $target $flags $(cat "$build/$name.flags") -c "$sources/$file" -o "$build/$name/$(basename "$file").o"
        built="$built $build/$name/$(basename "$file").o"
    done
    bundle="$build/$name.app"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents/MacOS"
    xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/windowed.m" "$here/$test" "$harness/check.m" $built $frameworks -o "$bundle/Contents/MacOS/app"
    cp "$here/windowed.plist" "$bundle/Contents/Info.plist"
    codesign -s - --force "$bundle" > /dev/null 2>&1
    if "$bundle/Contents/MacOS/app" > "$build/$name.log" 2>&1; then result=0; else result=$?; fi
    grep -v '^ok ' "$build/$name.log" | grep -a 'FAIL\|checks=\|info' || true
    echo "$name: exit=$result log=$build/$name.log"
    [ "$result" = 0 ] || status=1
}

windowed_expected() {
    # $1: group name, $2: sources, $3: test source run against the port, $4: the source that records what the system answers
    name=$1
    files=$2
    test=$3
    recorder=$4
    bundle="$build/$name-system.app"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents/MacOS"
    xcrun clang $target -fobjc-arc -Wall -w -I"$harness" "$here/windowed.m" "$here/$recorder" "$harness/check.m" $frameworks -o "$bundle/Contents/MacOS/app"
    cp "$here/windowed.plist" "$bundle/Contents/Info.plist"
    codesign -s - --force "$bundle" > /dev/null 2>&1
    expected="$build/$name.expected"
    if CHARON_EXPECTED="$expected" "$bundle/Contents/MacOS/app" > "$build/$name-system.log" 2>&1; then result=0; else result=$?; fi
    echo "$name-system: exit=$result log=$build/$name-system.log"
    [ "$result" = 0 ] || status=1
    CHARON_EXPECTED="$expected"
    export CHARON_EXPECTED
    windowed "$name" "$files" "$test"
}

prefixed_windowed_expected() {
    # $1: group name, $2: sources, $3: test source run against the port, $4: the source that records what the
    # system answers. windowed_expected with the port side on the prefixed path, which a group whose sources
    # add a category to a class the system owns needs for the reason prefixed_build names: the recording side
    # links no port object at all, so only the half that carries the port has to be rewritten. It did not
    # exist, so a windowed_expected group whose sources hold such a category had nowhere to go but the plain
    # path - colors13, which is why that group aborted on an unrecognized selector instead of comparing.
    name=$1
    files=$2
    test=$3
    recorder=$4
    if [ -n "$only" ]; then
        case " $only " in *" $name "*) : ;; *) return 0 ;; esac
    fi
    bundle="$build/$name-system.app"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents/MacOS"
    xcrun clang $target -fobjc-arc -Wall -w -I"$harness" "$here/windowed.m" "$here/$recorder" "$harness/check.m" $frameworks -o "$bundle/Contents/MacOS/app"
    cp "$here/windowed.plist" "$bundle/Contents/Info.plist"
    codesign -s - --force "$bundle" > /dev/null 2>&1
    expected="$build/$name.expected"
    if CHARON_EXPECTED="$expected" "$bundle/Contents/MacOS/app" > "$build/$name-system.log" 2>&1; then result=0; else result=$?; fi
    echo "$name-system: exit=$result log=$build/$name-system.log"
    [ "$result" = 0 ] || status=1
    CHARON_EXPECTED="$expected"
    export CHARON_EXPECTED
    prefixed_windowed "$name" "$files" "$test"
}

renamed_keep() {
    # $1: object files, $2: the selectors that are renamed; every other selector the objects define keeps its name
    printf '%s\n' $2 > "$build/rename.list"
    nm $1 | sed -n 's/.*[-+]\[[A-Za-z_]*(*[A-Za-z]*)* \([A-Za-z_][A-Za-z0-9_]*\).*\]$/\1/p' | grep -v '^charon_' | sort -u | grep -v -x -f "$build/rename.list" | tr '\n' ' '
}

windowed_renamed() {
    # $1: group name, $2: sources, $3: selectors that get renamed, $4: test source; as windowed, but only the classes and the named selectors are renamed
    name=$1
    files=$2
    renamed=$3
    test=$3
    objects=""
    for file in $files; do
        xcrun clang $target $flags -w -c "$sources/$file" -o "$build/plain/$name-$(basename "$file").o"
        objects="$objects $build/plain/$name-$(basename "$file").o"
    done
    renames "$objects" "$(renamed_keep "$objects" "$renamed")" > "$build/$name.flags"
    mkdir -p "$build/$name"
    built=""
    for file in $files; do
        xcrun clang $target $flags $(cat "$build/$name.flags") -c "$sources/$file" -o "$build/$name/$(basename "$file").o"
        built="$built $build/$name/$(basename "$file").o"
    done
    bundle="$build/$name.app"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents/MacOS"
    xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/windowed.m" "$here/$test" "$harness/check.m" $built $frameworks -o "$bundle/Contents/MacOS/app"
    cp "$here/windowed.plist" "$bundle/Contents/Info.plist"
    codesign -s - --force "$bundle" > /dev/null 2>&1
    if "$bundle/Contents/MacOS/app" > "$build/$name.log" 2>&1; then result=0; else result=$?; fi
    grep -v '^ok ' "$build/$name.log" | grep -a 'FAIL\|checks=\|info' || true
    echo "$name: exit=$result log=$build/$name.log"
    [ "$result" = 0 ] || status=1
}

renamed() {
    # $1: group name, $2: sources, $3: selectors that get renamed, $4: test source; as group, but only the classes and the named selectors are renamed
    name=$1
    files=$2
    renamed=$3
    test=$3
    objects=""
    for file in $files; do
        xcrun clang $target $flags -w -c "$sources/$file" -o "$build/plain/$name-$(basename "$file").o"
        objects="$objects $build/plain/$name-$(basename "$file").o"
    done
    renames "$objects" "$(renamed_keep "$objects" "$renamed")" > "$build/$name.flags"
    mkdir -p "$build/$name"
    built=""
    for file in $files; do
        xcrun clang $target $flags $(cat "$build/$name.flags") -c "$sources/$file" -o "$build/$name/$(basename "$file").o"
        built="$built $build/$name/$(basename "$file").o"
    done
    xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/$test" "$harness/check.m" $built $frameworks -o "$build/$name-test"
    if "$build/$name-test" > "$build/$name.log" 2>&1; then result=0; else result=$?; fi
    grep -v '^ok ' "$build/$name.log" || true
    echo "$name: exit=$result log=$build/$name.log"
    [ "$result" = 0 ] || status=1
}

windowed_renamed_expected() {
    # $1: group name, $2: sources, $3: selectors that get renamed, $4: test source run against the port, $5: source that records what the system answers, in a process with none of the port's code
    name=$1
    files=$2
    renamed=$3
    test=$3
    recorder=$5
    bundle="$build/$name-system.app"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents/MacOS"
    xcrun clang $target -fobjc-arc -Wall -w -I"$harness" "$here/windowed.m" "$here/$recorder" "$harness/check.m" $frameworks -o "$bundle/Contents/MacOS/app"
    cp "$here/windowed.plist" "$bundle/Contents/Info.plist"
    codesign -s - --force "$bundle" > /dev/null 2>&1
    expected="$build/$name.expected"
    if CHARON_EXPECTED="$expected" "$bundle/Contents/MacOS/app" > "$build/$name-system.log" 2>&1; then result=0; else result=$?; fi
    echo "$name-system: exit=$result log=$build/$name-system.log"
    [ "$result" = 0 ] || status=1
    CHARON_EXPECTED="$expected"
    export CHARON_EXPECTED
    windowed_renamed "$name" "$files" "$renamed" "$test"
}

status=0
prefixed_group traits "UITraitCollection.m CharonTraitObservers.m UITraitCollection+UserInterfaceStyle.m UITraitCollection+Appearance13.m UITraitCollection+Appearance14.m UIImageConfiguration.m UIImageSymbolConfiguration.m UIImageSymbolWeight.m UIImageSymbolGlyphs.m UIImage+Baseline13.m UIImage+iOS13.m UIImage+Symbols.m UIImageView+SymbolConfiguration.m UITraitCollection+ForceTouch.m UITraitCollection+TraitStore.m" traits_test.m

group notifications "UIUserNotificationSettings.m" notifications_test.m

prefixed_group misc "UIScreen+NativeBounds.m UIFont+TextStyles.m UIFont+Weights.m UIFontWidths.m UIFontWidths8.m UIColor+SystemColors.m UIColor+SystemPurpleColor.m UIColorDynamic.m UIImage+RenderingMode.m UITextField+DefaultTextAttributes.m UIViewController+ExtendedLayout.m" misc_test.m

prefixed_group motion "UIMotionEffect.m UIView+MotionEffects.m" motion_test.m

group sizes "UIContentSizeCategory.m UIContentSizeCategory+Unspecified.m" sizes_test.m

prefixed_group tint "UIView+TintColor.m" tint_test.m

prefixed_group bars "UINavigationBar+BarAppearance.m UISearchBar+BarStyle.m UIToolbar+BarTintColor.m UITabBar+BarTintColor.m" bars_test.m

prefixed_group viewmisc "UIView+MaskView.m UIView+PerformWithoutAnimation.m UIView+SemanticContentAttribute.m UIViewController+ViewLoading.m UIViewController+PreferredContentSize.m UIViewController+StatusBarAppearance.m" viewmisc_test.m

prefixed_group attributestransform "UICollectionViewLayoutAttributes+Transform7.m" attributestransform_test.m

group rowaction "UITableViewRowAction.m" rowaction_test.m

group visualeffect "UIVisualEffect.m UIVisualEffectView.m CharonBlur.m CharonBackdrop.m" visualeffect_test.m

group useractivity "../Foundation/NSUserActivity.m" useractivity_test.m

group localauth "../LocalAuthentication/LAContext.m ../LocalAuthentication/LAErrorDomain.m ../LocalAuthentication/LATouchIDAuthenticationMaximumAllowableReuseDuration.m" localauth_test.m

group documentpicker "UIDocumentPickerViewController.m CharonDocumentBrowser.m" documentpicker_test.m

group datecomponentsformatter "../Foundation/NSDateComponentsFormatter.m" datecomponentsformatter_test.m

group runloopobserver "../Foundation/CFRunLoopObserverHandler.m" runloopobserver_test.m

group tabledimension "UITableViewAutomaticDimension.m" tabledimension_test.m

group scenes "UISceneValues.m UISceneConstants.m UISceneConstants16.m" scenes_test.m

prefixed_group cornercurve "CALayer+CornerCurve.m" cornercurve_test.m

group relativedatetimeformatter "../Foundation/NSRelativeDateTimeFormatter.m" relativedatetimeformatter_test.m

group itemprovider "../Foundation/NSItemProvider.m" itemprovider_test.m

prefixed_group itemproviderbuiltins "../Foundation/NSString+ItemProvider.m ../Foundation/NSURL+ItemProvider.m" itemproviderbuiltins_test.m

group nsdataasset "NSDataAsset.m" nsdataasset_test.m

group safariviewcontroller "../SafariServices/CharonSafariPage.m ../SafariServices/SFSafariViewController.m ../SafariServices/SFSafariViewControllerConfiguration.m ../SafariServices/SFSafariViewControllerActivityButton.m ../SafariServices/SFSafariViewControllerPrewarmingToken.m ../SafariServices/SFAuthenticationSession.m ../SafariServices/SFAuthenticationErrorDomain.m" safariviewcontroller_test.m

export APPEARANCES_EXPECTATIONS="$harness/appearances-expectations.h"
prefixed_group appearances "CharonBarAppearance.m CharonBarAppearanceApply.m CharonBarAppearanceTracking.m UIBarAppearance.m UINavigationBarAppearance.m UIToolbarAppearance.m UITabBarAppearance.m UIBarButtonItemAppearance.m UITabBarItemAppearance.m UINavigationBarAppearance+Prominent.m UINavigationBar+Appearances.m UIToolbar+Appearances.m UITabBar+Appearances.m UINavigationItem+Appearances.m UITabBarItem+Appearances.m UIBar+ScrollEdgeAppearances.m" appearances_test.m

prefixed_group orderedcollections "../Foundation/NSOrderedCollectionChange.m ../Foundation/NSOrderedCollectionDifference.m ../Foundation/NSArray+Difference.m ../Foundation/NSOrderedSet+Difference.m" orderedcollections_test.m

group diffable "NSDiffableDataSourceSnapshot.m" diffable_test.m

group diffablesection "NSDiffableDataSourceSectionSnapshot.m" diffablesection_test.m

windowed diffabledatasource "NSDiffableDataSourceSnapshot.m CharonDiffable.m UICollectionViewDiffableDataSource.m UITableViewDiffableDataSource.m" diffabledatasource_test.m

windowed diffablesectiondatasource "NSDiffableDataSourceSnapshot.m NSDiffableDataSourceSectionSnapshot.m CharonDiffable.m UICollectionViewDiffableDataSource.m UITableViewDiffableDataSource.m UICollectionViewDiffableDataSource+iOS14.m UICollectionViewDiffableDataSourceHandlers.m" diffablesectiondatasource_test.m

prefixed_windowed snapshots "UIView+Snapshots.m" snapshots_test.m

prefixed_windowed menucontroller "UIMenuController+iOS13.m" menucontroller_test.m

prefixed_group symbols "UIImageConfiguration.m UIImageSymbolConfiguration.m UIImageSymbolWeight.m UIImageSymbolGlyphs.m UIImage+Baseline13.m UIImage+iOS13.m UIImage+Symbols.m UIImageView+SymbolConfiguration.m" symbols_test.m

windowed menus "UIMenuElement.m UIAction.m UIAction+iOS14.m UIMenu.m UIMenu+iOS14.m UIDeferredMenuElement.m UIMenuIdentifiers.m UIMenuIdentifiers14.m UIMenuSystem.m UIContextMenuConfiguration.m UIContextMenuInteraction.m UIContextMenuInteraction+iOS14.m UIPreviewParameters.m UIPreviewParameters+iOS14.m UIPreviewTarget.m UITargetedPreview.m" menus_test.m

# UIHoverGestureRecognizer+Hover16.m is here and was not, and the check below is why: zOffset of 16.1 and
# altitudeAngle of 16.4 are a CATEGORY on UIHoverGestureRecognizer, so they reach this group only from that
# file. Without it the class this group renames is CharonHostUIHoverGestureRecognizer with three methods,
# the check that reads them fails, and the same four members pass in the hover16 group that does carry the
# file - one harness list short of a file, not a port defect.
windowed pointer "UIPointerRegion.m UIPointerStyle.m UIPointerInteraction.m UIHoverGestureRecognizer.m UIHoverGestureRecognizer+Hover16.m UIKey.m UIKeyInputKeys.m" pointer_test.m

prefixed_windowed pointercategories "UIEvent+Pointer.m UIGestureRecognizer+Pointer.m UIButton+Pointer.m" pointercategories_test.m

# The names of iOS 16.1 and 16.4 this band carries: the four members UIHoverGestureRecognizer gained,
# and UITextInputContext with the three flags it declares. UIHoverGestureRecognizer.m is main's 13.0
# object and is here because the four members belong to the class it defines; the two files beside it
# are this band's own. UISearchBar's enabled of 16.4 is in this group too, measured here and left to
# the release's own UIView accessors - see facts/UIKit/HoverAndTextInput16.md.
windowed_expected hover16 "UIHoverGestureRecognizer.m UIHoverGestureRecognizer+Hover16.m UITextInputContext16.m" hover16_test.m hover16_system.m

windowed search "UISearchToken.m UISearchTextField.m" search_test.m

prefixed_windowed searchcategories "UISearchBar+SearchTextField.m UISearchController+ScopeBar.m" searchcategories_test.m

windowed colors "UIColorWell.m UIColorPickerViewController.m" colors_test.m

group commands "UIMenuElement.m UICommand.m UIKeyCommand.m UIKeyCommand+Priority.m" commands_test.m

group activityitems "UIActivityItemsConfiguration.m" activityitems_test.m
group customaction "UIAccessibilityCustomAction.m UIAccessibilityCustomAction+Handler13.m UIAccessibilityCustomAction+Image14.m UIAccessibilityCustomAction+AttributedName11.m UIAccessibilityCustomAction+AttributedNameImage14.m" customaction_test.m

windowed fontpicker "UIFontPickerViewController.m" fontpicker_test.m

prefixed_windowed inert "UILargeContentViewer.m UIScreenshotService.m UITextFormattingCoordinator.m UITextPlaceholder.m UIScribbleInteraction.m UIPointerLockState.m" inert_test.m

# This group is on the plain path and its test is not green: UITraitCollection.m sends
# traitCollectionDidChange: to a receiver prefix_selectors.lua cannot place, and the rewriter refuses
# rather than renaming half of it ("a carried selector the rewrite cannot rename:
# traitCollectionDidChange:, which the host's UITraitEnvironment declares"), so the prefixed path
# stops the group at the rewrite. On the plain path the run aborts instead, on
# -[CharonHostUITraitCollection _hasSpecifiedEssentialTraits]: unrecognized selector. Both are that
# one send in that file, which is main's and not this branch's; the group goes on prefixed_windowed
# when the send can be placed.
prefixed_windowed traits13 "UITraitCollection.m CharonTraitObservers.m UITraitCollection+UserInterfaceStyle.m UITraitCollection+Appearance13.m UITraitCollection+Appearance14.m UIScreen+TraitEnvironment.m UIImageConfiguration.m UIImageSymbolConfiguration.m UIImageSymbolWeight.m UIImageSymbolGlyphs.m UIImage+Baseline13.m UIImage+iOS13.m UIImage+Symbols.m UIImageView+SymbolConfiguration.m UITraitCollection+ForceTouch.m UITraitCollection+TraitStore.m" traits13_test.m

prefixed_windowed_expected controlactions "UIMenuElement.m UIAction.m UIAction+iOS14.m UIMenu.m UIMenu+iOS14.m UIDeferredMenuElement.m UIMenuIdentifiers.m UIMenuIdentifiers14.m UIMenuSystem.m UIContextMenuConfiguration.m UIContextMenuInteraction.m UIContextMenuInteraction+iOS14.m UIPreviewParameters.m UIPreviewParameters+iOS14.m UIPreviewTarget.m UITargetedPreview.m UICommand.m UIControl+Actions14.m UIControl+Menus14.m UIButton+Actions14.m" controlactions_test.m controlactions_system.m

prefixed_windowed_expected controlmenus "UIMenuElement.m UIAction.m UIAction+iOS14.m UIMenu.m UIMenu+iOS14.m UIDeferredMenuElement.m UIMenuIdentifiers.m UIMenuIdentifiers14.m UIMenuSystem.m UIContextMenuConfiguration.m UIContextMenuInteraction.m UIContextMenuInteraction+iOS14.m UIPreviewParameters.m UIPreviewParameters+iOS14.m UIPreviewTarget.m UITargetedPreview.m UICommand.m UIControl+Actions14.m UIControl+Menus14.m UIButton+Actions14.m UIButton+iOS13.m UIBarButtonItem+Actions14.m UISegmentedControl+Actions14.m" controlmenus_test.m controlmenus_system.m

prefixed_windowed_expected views13 "UIView+iOS13.m UIViewController+iOS13.m UIDatePicker+Style134.m UIPanGestureRecognizer+ScrollTypes134.m UISwitch+Style14.m UIPageControl+Indicators14.m UILabel+LineBreakStrategy14.m UIView+FocusGroup14.m UIScrollView+IndicatorInsets13.m UISegmentedControl+SelectedTint13.m UISplitViewController+Background13.m UITextView+TextScaling13.m UISearchBar+ScopeBar13.m UIScreen+Latency13.m UIAccessibility13.m UIAccessibility14.m UIAccessibilityCustomAction+Handler13.m UIAccessibilityCustomAction+Image14.m NSLayoutManager+Text13.m UIResponder+ItemsConfiguration.m UIVibrancyEffect+Style13.m UIFontSystemDesign.m UIViewController+Appearing13.m UIViewController+Unwind13.m NSAttributedString+Constants13.m NSAttributedString+Tracking14.m UIPasteboard+Detection14.m UINavigationItem+BackDisplayMode14.m UITextInput+AttributedReplace13.m UICommand.m UIMenuElement.m" views13_test.m views13_system.m
prefixed_windowed_expected darkstyle "UIView+iOS13.m UIViewController+iOS13.m UIViewController+TraitEnvironment.m UIView+TraitEnvironment.m UIScreen+TraitEnvironment.m UITraitCollection.m CharonTraitObservers.m UITraitCollection+UserInterfaceStyle.m UITraitCollection+Appearance13.m UITraitCollection+Appearance14.m UITraitCollection+ForceTouch.m UITraitCollection+TraitStore.m UIImageConfiguration.m UIImageSymbolConfiguration.m UIImageSymbolWeight.m UIImageSymbolGlyphs.m UIImage+Baseline13.m UIImage+iOS13.m UIImage+Symbols.m UIImageView+SymbolConfiguration.m" darkstyle_test.m darkstyle_system.m
windowed pagecontrol "UIPageControl+Indicators14.m" pagecontrol_test.m
prefixed_windowed_expected focus "UICollectionView+SelectionFocus14.m UITableView+SelectionFocus14.m" focus_test.m focus_system.m

prefixed_windowed_expected images13 "UIImage+iOS13.m UIImage+Baseline13.m UIImageConfiguration.m UIImageSymbolConfiguration.m UIImageSymbolWeight.m UIImageSymbolGlyphs.m UIImage+Symbols.m UIImageView+SymbolConfiguration.m" images13_test.m images13_system.m

prefixed_windowed_expected colors13 "UIColorDynamic.m" colors13_test.m colors13_system.m

prefixed_windowed listmenus "UIMenuElement.m UIAction.m UIAction+iOS14.m UIMenu.m UIMenu+iOS14.m UIDeferredMenuElement.m UIMenuIdentifiers.m UIMenuIdentifiers14.m UIMenuSystem.m UIContextMenuConfiguration.m UIContextMenuInteraction.m UIContextMenuInteraction+iOS14.m UIPreviewParameters.m UIPreviewParameters+iOS14.m UIPreviewTarget.m UITargetedPreview.m UICommand.m CharonListMenu.m UITableView+ContextMenu14.m UICollectionView+ContextMenu132.m" listmenus_test.m

prefixed_windowed appearing "UIViewController+Appearing13.m" appearing_test.m

windowed textinteraction "UITextInteraction.m" textinteraction_test.m

prefixed_group layoutvalues "NSCollectionLayoutValues.m NSCollectionLayoutItems.m UICollectionViewCompositionalLayout.m CharonOrthogonalScroll.m CharonSelfSizing.m NSCollectionLayoutSection+iOS14.m UICollectionViewCompositionalLayoutConfiguration+iOS14.m" layoutvalues_test.m

export CHARON_ORTHOGONAL_EXPECTATIONS="$here/../../device/compositional-orthogonal-expectations.h"
export CHARON_SIZED_EXPECTATIONS="$here/../../device/compositional-sized-expectations.h"
export CHARON_COMPOSITIONAL_EXPECTATIONS="$here/../../device/compositional-expectations.h"
prefixed_windowed compositionallayout "NSCollectionLayoutValues.m NSCollectionLayoutItems.m UICollectionViewCompositionalLayout.m CharonOrthogonalScroll.m CharonSelfSizing.m NSCollectionLayoutSection+iOS14.m UICollectionViewCompositionalLayoutConfiguration+iOS14.m CharonLists.m UICollectionViewCompositionalLayout+ListConfiguration.m" compositionallayout_test.m

prefixed_windowed orthogonal "NSCollectionLayoutValues.m NSCollectionLayoutItems.m UICollectionViewCompositionalLayout.m CharonOrthogonalScroll.m CharonSelfSizing.m NSCollectionLayoutSection+iOS14.m UICollectionViewCompositionalLayoutConfiguration+iOS14.m CharonLists.m UICollectionViewCompositionalLayout+ListConfiguration.m" orthogonal_test.m

prefixed_windowed sizedlayout "NSCollectionLayoutValues.m NSCollectionLayoutItems.m UICollectionViewCompositionalLayout.m CharonOrthogonalScroll.m CharonSelfSizing.m NSCollectionLayoutSection+iOS14.m UICollectionViewCompositionalLayoutConfiguration+iOS14.m CharonLists.m UICollectionViewCompositionalLayout+ListConfiguration.m" sizedlayout_test.m

prefixed_group listvalues "CharonLists.m UICellAccessory.m UIViewConfigurationState.m UIListContentProperties.m UIListContentConfiguration.m UIBackgroundConfiguration.m UIListContentView.m" listvalues_test.m

export CHARON_LISTS_EXPECTATIONS="$here/../../device/lists-expectations.h"
group listseparator "UIListSeparatorConfiguration145.m UIListSeparatorConfiguration+VisualEffect15.m" listseparator_test.m

prefixed_windowed listcell "CharonLists.m CharonConfigurationHost.m UICellAccessory.m UIViewConfigurationState.m UIListContentProperties.m UIListContentConfiguration.m UIBackgroundConfiguration.m UIListContentView.m UICollectionViewCell+Configuration.m UITableViewCell+Configuration.m UITableViewHeaderFooterView+Configuration.m UICollectionViewListCell.m UICollectionView+Editing.m UICollectionViewRegistration.m UICollectionLayoutListConfiguration.m UICollectionViewCompositionalLayout+ListConfiguration.m NSCollectionLayoutValues.m NSCollectionLayoutItems.m UICollectionViewCompositionalLayout.m CharonOrthogonalScroll.m CharonSelfSizing.m NSCollectionLayoutSection+iOS14.m UICollectionViewCompositionalLayoutConfiguration+iOS14.m NSDiffableDataSourceSnapshot.m CharonDiffable.m UICollectionViewDiffableDataSource.m CharonSwipeViews.m UICollectionView+SwipeActions.m UIContextualAction.m UISwipeActionsConfiguration.m" listcell_test.m

prefixed_windowed listactions "CharonLists.m CharonConfigurationHost.m UICellAccessory.m UIViewConfigurationState.m UIListContentProperties.m UIListContentConfiguration.m UIBackgroundConfiguration.m UIListContentView.m UICollectionViewCell+Configuration.m UITableViewCell+Configuration.m UITableViewHeaderFooterView+Configuration.m UICollectionViewListCell.m UICollectionView+Editing.m UICollectionViewRegistration.m UICollectionLayoutListConfiguration.m UICollectionViewCompositionalLayout+ListConfiguration.m NSCollectionLayoutValues.m NSCollectionLayoutItems.m UICollectionViewCompositionalLayout.m CharonOrthogonalScroll.m CharonSelfSizing.m NSCollectionLayoutSection+iOS14.m UICollectionViewCompositionalLayoutConfiguration+iOS14.m NSDiffableDataSourceSnapshot.m CharonDiffable.m UICollectionViewDiffableDataSource.m NSDiffableDataSourceSectionSnapshot.m UICollectionViewDiffableDataSource+iOS14.m UICollectionViewDiffableDataSourceHandlers.m NSDiffableDataSourceTransaction.m UICollectionView+InteractiveMovement.m CharonSwipeViews.m UICollectionView+SwipeActions.m UIContextualAction.m UISwipeActionsConfiguration.m" listactions_test.m


windowed_expected transformers "UIConfigurationColorTransformers14.m" transformers_test.m transformers_system.m

prefixed_group foundation14filehandle "../Foundation/NSFileHandle+Errors13.m" foundation14_filehandle_test.m

prefixed_group foundation14compression "../Foundation/NSData+Compression13.m ../Foundation/CharonLZMA.m" foundation14_compression_test.m

group foundation14listformatter "../Foundation/NSListFormatter.m" foundation14_listformatter_test.m

group foundation14units "../Foundation/NSDimension.m ../Foundation/NSUnit.m ../Foundation/NSUnitConverter.m ../Foundation/NSUnitConverterLinear.m ../Foundation/NSUnitConverterReciprocal.m ../Foundation/NSMeasurement.m ../Foundation/NSUnitInformationStorage.m" foundation14_units_test.m

prefixed_group foundation14bytecount "../Foundation/NSDimension.m ../Foundation/NSUnit.m ../Foundation/NSUnitConverter.m ../Foundation/NSUnitConverterLinear.m ../Foundation/NSUnitConverterReciprocal.m ../Foundation/NSMeasurement.m ../Foundation/NSUnitInformationStorage.m ../Foundation/NSUnitLength.m ../Foundation/NSByteCountFormatter+Measurement13.m" foundation14_bytecount_test.m

prefixed_group foundation14httpresponse "../Foundation/NSHTTPURLResponse+HeaderField13.m" foundation14_httpresponse_test.m

prefixed_group foundation14collections "../Foundation/NSCoder+Collections14.m ../Foundation/NSKeyedUnarchiver+Collections14.m" foundation14_collections_test.m

prefixed_group foundation14queue "../Foundation/NSOperationQueue+Barrier13.m" foundation14_queue_test.m

prefixed_group foundation14websocket "../Foundation/NSURLSessionWebSocket13.m" foundation14_websocket_test.m

prefixed_group foundation14directoryenumerator "../Foundation/NSDirectoryEnumerator+PostOrder13.m" foundation14_directoryenumerator_test.m

prefixed_group foundation14cookie "../Foundation/NSHTTPCookie+SameSite13.m" foundation14_cookie_test.m

# CharonNetworkAccess.c is here and was not, and the link was why: it is the file that DEFINES
# charon_network_cellular and its test seam charon_network_cellular_override, and renames() learns a C symbol
# to rename from the objects that define it. Listed nowhere, both stayed unprefixed in the two .m files that
# call them while the test declared the prefixed names, so the group died at link with
#   Undefined symbols for architecture arm64: "_charon_network_cellular", referenced from
#   +[CharonHostCharonNetworkGate canInitWithRequest:]
# and set -e took the rest of the run with it, which is why nine groups after this line never reported at all.
# The file is plain C and compiles with this harness's flags unchanged (measured: clang -target
# arm64-apple-ios15.0-macabi -fobjc-arc on the file alone, no diagnostic).
prefixed_group foundation14networkaccess "../Foundation/CharonNetworkAccess.c ../Foundation/NSURLRequest+NetworkAccess13.m ../Foundation/NSURLSessionConfiguration+NetworkAccess13.m" foundation14_networkaccess_test.m

group foundation14resourcekeys "../Foundation/NSURLResourceKeys14.m" foundation14_resourcekeys_test.m

group foundation14useractivity "../Foundation/NSUserActivity.m ../Foundation/NSUserActivity+TargetContent13.m" foundation14_useractivity_test.m

prefixed_group foundation14urlcache "../Foundation/NSURLCache+DirectoryURL13.m" foundation14_urlcache_test.m
prefixed_group traits17 "UITraitCollection.m CharonTraitObservers.m UITraitCollection+UserInterfaceStyle.m UITraitCollection+Appearance13.m UITraitCollection+Appearance14.m UITraitCollection+Traits10.m UITraitCollection+ForceTouch.m UITrait17.m UITraitList18.m UITrait26.m UITraitCollection+TraitStore.m UITraitCollection+Traits17.m UITraitOverrides17.m" traits17_test.m
group textkit2 "NSTextRange15.m NSTextSelection15.m NSTextElement15.m NSTextElement16.m NSTextSelectionNavigation15.m" textkit2_test.m
group content15 "NSTextContentManager15.m NSTextContentStorage15.m NSTextListElement16.m NSTextElement15.m NSTextElement16.m CharonTextLocation.m" content15_test.m
group buttonconfig "UIButtonConfiguration.m" buttonconfig_test.m

# The red control, IN the harness: a wrong default in the port has to make this comparison go RED and name the
# key, and a control that plants nothing has to fail rather than report a clean run. The shape is the one
# pdfkit-str2 (c62714b7b) and modelio-34 use. The six keys are the defaults this case exists for -- every one
# of them a nil or a zero the port once got wrong -- and the last two are the refusals, which must exit 2
# rather than exit 0: a mutation that plants nothing has not proven anything, and passing it quietly is the
# failure this whole block is here to prevent.
control() {  # $1: what to plant, $2: the exit status that must come back
    # the status is read through an if, not by running the command and then reading $?: this script runs under
    # `set -e`, and a planted run is SUPPOSED to exit non-zero, so a bare invocation would abort the harness
    # before the control could report that it went red. group() above reads its status the same way.
    if CHARON_MUTATION="$1" "$build/buttonconfig-test" > "$build/buttonconfig-mutated.log" 2>&1; then
        got=0
    else
        got=$?
    fi
    if [ "$got" = "$2" ]; then
        printf 'ok   buttonconfig control [%s]: exit=%s\n' "$1" "$got"
        grep -E '^MUTATION|^FAIL' "$build/buttonconfig-mutated.log" | head -3 | sed 's/^/    /'
    else
        printf 'FAIL buttonconfig control [%s]: exit=%s, and it must be %s\n' "$1" "$got" "$2"
        status=1
    fi
}
# The control belongs to the buttonconfig group above, so it runs only when that group is in scope - the
# same gate group() applies, and for the same reason.
#
# It used to run unconditionally, and on a UIKIT2_ONLY run the group is skipped, so "$build/buttonconfig-test"
# was never built.  The shell then failed to EXECUTE it, and every control read that failure's status as if
# it were a verdict.  Measured, on /bin/sh here, a command that cannot be executed exits 1, not 127:
#
#   $ cat $build/buttonconfig-mutated.log
#   run.sh: line 496: .../buttonconfig-test: No such file or directory
#   $ UIKIT2_ONLY=eventattraction sh run.sh
#   ok   buttonconfig control [a fresh configuration has no title]: exit=1
#   FAIL buttonconfig control [--no-plant]: exit=1, and it must be 2
#   FAIL buttonconfig control [no such key]: exit=1, and it must be 2
#
# Six of the eight therefore printed "ok" having run nothing at all, because 1 is what the six PLANTING
# controls expect and 1 is what a missing binary returns; only the two refusals, which expect 2, showed the
# truth.  A control that can report a pass without executing anything is the exact failure this block exists
# to prevent, so the fix is the gate - not a second exit code to recognise, and not a quiet skip.
# An EMPTY $only means every group is in scope - that is what UIKIT2_ONLY's own comment says - so the test
# is "nothing was asked for, or buttonconfig was", not the case pattern alone, which an empty $only would
# fail and would silently stop the control on an ordinary unfiltered run.
case "$only" in
    "" | *" buttonconfig "*)
        for key in "a fresh configuration has no base foreground colour" \
                   "a fresh configuration has no base background colour" \
                   "a fresh configuration has no image" \
                   "a fresh configuration has no image colour transformer" \
                   "a fresh configuration has no preferred symbol configuration" \
                   "a fresh configuration has no title"; do
            control "$key" 1
        done
        control "--no-plant" 2
        control "no such key" 2
        ;;
esac


group contentunavailable "UIContentUnavailableProperties.m UIContentUnavailableConfiguration.m" contentunavailable_test.m

# The link-preview attribution of 14.5 and its view. Its system side is the SDK's own class - both classes
# are in the 16.4 SDK this package compiles against - so this group does not declare the system side, which
# is the stronger of the two positions the suite has.
group eventattribution "UIEventAttribution145.m" eventattribution_test.m

# the spring curve: UIKit's own parameters, our solver, and a real CASpringAnimation
xcrun clang $target -fobjc-arc -Wall -w -I"$harness" "$here/spring_uikit.m" $frameworks -o "$build/spring_uikit"
xcrun clang $target $flags -w -c "$sources/UIView+SpringAnimation.m" -o "$build/plain/spring.o"
xcrun clang $target -fobjc-arc -Wall -I"$harness" "$here/spring_ours.m" "$harness/check.m" "$build/plain/spring.o" $frameworks -o "$build/spring_ours"
xcrun clang -fobjc-arc -Wall -I"$harness" "$here/spring_sample.m" "$harness/check.m" -framework AppKit -framework QuartzCore -o "$build/spring_sample"
"$build/spring_uikit" > "$build/spring_uikit.txt"
if "$build/spring_ours" "$build/spring_uikit.txt" "$build/spring_samples.txt" > "$build/spring_ours.log" 2>&1; then result=0; else result=$?; fi
grep -v '^ok ' "$build/spring_ours.log" || true
echo "spring_ours: exit=$result log=$build/spring_ours.log"
[ "$result" = 0 ] || status=1
if "$build/spring_sample" < "$build/spring_samples.txt" > "$build/spring_sample.log" 2>&1; then result=0; else result=$?; fi
grep -v '^ok ' "$build/spring_sample.log" || true
echo "spring_sample: exit=$result log=$build/spring_sample.log"
[ "$result" = 0 ] || status=1
exit $status
