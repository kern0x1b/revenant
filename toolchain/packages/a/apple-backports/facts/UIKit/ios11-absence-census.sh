#!/bin/sh
# The measurement registry/UIKit/ios11.json cites: does each name the slice's rows name exist in the
# release a row is `absent` about, read class-scoped out of that release's own dyld shared cache.
#
# Usage: CHARON_ROOT=<worktree> sh packages/a/apple-backports/facts/UIKit/ios11-absence-census.sh
#
# Needs nothing but the tree's own tools and the held caches under $HOME/.charon/dyld: no SDK, no
# compiler, no package store. Every rung prints its class and protocol counts before its answers,
# which is the control: 11.0 is a rung the slice's names really do exist on, so a zero on 6.1.3 or
# 4.3 beside those counts is the release's and not the reader's. Drop the 11.0 lines and a run
# certifies nothing.
#
# A property's NAME is not always a selector, so the selectors below are the ones the header's
# getter produces: `useFastSameViewOperations` is its own getter, and the @property(getter=isX)
# families are named by their accessors. Each name is asked as `-[Owner selector]`; the word after it
# is PRESENT or no, and "owner absent" says the release has no such class or protocol at all.
set -eu
root=${CHARON_ROOT:-$PWD}
inventory=$root/tools/corpus/objc-inventory.lua

check() {
    owner=$1
    shift
    for cache in 6.1.3/dyld_shared_cache_armv7 4.3/dyld_shared_cache_armv7 11.0/dyld_shared_cache_arm64; do
        CHARON_ROOT=$root xmake l "$inventory" "$HOME/.charon/dyld/$cache" 2>/dev/null |
        awk -F'\t' -v owner="$owner" -v cache="$cache" -v want="$*" '
            $1 == "class" || $1 == "protocol" { counted[$1]++ }
            ($1 == "class" || $1 == "protocol") && $2 == owner {
                named = 1
                for (field = 5; field <= 6; field++) {
                    count = split($field, part, ",")
                    for (i = 1; i <= count; i++)
                        if (part[i] != "") selector[$2 "|" part[i]] = 1
                }
            }
            END {
                printf "%-38s %d classes %d protocols  ", cache, counted["class"], counted["protocol"]
                if (!named) { print owner ": owner absent"; exit }
                split(want, asked, " ")
                answer = ""
                for (i = 1; i <= length(asked); i++) {
                    bare = asked[i]
                    sub(/^-/, "", bare)
                    answer = answer (i > 1 ? "  " : "") bare "=" ((owner "|-" bare) in selector ? "PRESENT" : "no")
                }
                print answer
            }'
    done
}

# The scroll view's own callback and the delegate question that hangs off it.
check UIScrollView adjustedContentInsetDidChange
check UIScrollViewDelegate scrollViewDidChangeAdjustedContentInset:

# The controller: the safe area and the layout margins, and the 11.0-only system minimum beside them.
check UIViewController viewSafeAreaInsetsDidChange viewLayoutMarginsDidChange \
                       systemMinimumLayoutMargins viewRespectsSystemMinimumLayoutMargins

# The two table-shaped classes and their update group, their separator and their safe area.
check UITableView hasUncommittedUpdates insetsContentViewsToSafeArea separatorInsetReference
check UICollectionView hasUncommittedUpdates reorderingCadence

# The bar item's large-content pair, the split view's edge, NSObject's accessibility trio.
check UIBarItem largeContentSizeImage largeContentSizeImageInsets
check UISplitViewController primaryEdge
check NSObject accessibilityContainerType accessibilityDragSourceDescriptors accessibilityDropPointDescriptors

# The pasteboard, provider-shaped and not.
check UIPasteboard itemProviders setObjects: setObjects:localOnly:expirationDate: \
                       setItemProviders:localOnly:expirationDate:

# Spring loading, asked of both the table and the collection delegate.
check UITableViewDelegate tableView:shouldSpringLoadRowAtIndexPath:withContext:
check UICollectionViewDelegate collectionView:shouldSpringLoadItemAtIndexPath:withContext:

# The focus coordinator the port carries: what it adds beside -addCoordinatedAnimations:.
check UIFocusAnimationCoordinator addCoordinatedFocusingAnimations:completion: \
                             addCoordinatedUnfocusingAnimations:completion:

# The styled custom action the port builds, and the attributed-reading protocols around it.
check UIAccessibilityCustomAction initWithAttributedName:target:selector: attributedName
check UIAccessibilityReadingContent accessibilityAttributedContentForLineNumber: accessibilityAttributedPageContent
check UIScrollViewAccessibilityDelegate accessibilityAttributedScrollStatusForScrollView:
check UIPickerViewAccessibilityDelegate pickerView:accessibilityAttributedHintForComponent: \
                                pickerView:accessibilityAttributedLabelForComponent:

# The extension-side owners, none of which exists before extensions do.
check UITextDocumentProxy documentIdentifier selectedText
check NSItemProvider preferredPresentationSize preferredPresentationStyle teamData
check UIInputViewController hasFullAccess needsInputModeSwitchKey

# The classes and protocols of the slice, asked by name rather than by selector: each is a name the
# release either has or has not, so a zero here is the release's answer to the whole row.
for name in UITextDropProposal UISpringLoadedInteraction UISpringLoadedInteractionBehavior \
             UISpringLoadedInteractionContext UISpringLoadedInteractionEffect \
             UISpringLoadedInteractionSupporting UIFocusSystem UIFocusDebugger \
             UIFocusDebuggerOutput UIFocusAnimationContext UIPasteConfiguration \
             UIPasteConfigurationSupporting UITextPasteConfigurationSupporting \
             UITextPasteDelegate UITextPasteItem UIItemProviderPresentationSizeProviding \
             UIDataSourceTranslating UIAccessibilityContainerDataTable \
             UIAccessibilityContainerDataTableCell UIAccessibilityContentSizeCategoryImageAdjusting \
             UIAccessibilityLocationDescriptor UIDocumentBrowserAction; do
    echo "== $name"
    CHARON_ROOT=$root xmake l "$root/tools/corpus/cache-census.lua" "$name" 6.1.3 4.3 11.0 2>/dev/null |
        grep -E 'of which naming|classes |protocols |^control:'
done