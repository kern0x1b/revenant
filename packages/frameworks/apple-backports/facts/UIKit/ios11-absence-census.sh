#!/bin/sh
set -eu
root=${REVENANT_ROOT:-$PWD}
inventory=$root/tools/corpus/objc-inventory.lua

check() {
    owner=$1
    shift
    for cache in 6.1.3/dyld_shared_cache_armv7 4.3/dyld_shared_cache_armv7 11.0/dyld_shared_cache_arm64; do
        REVENANT_ROOT=$root xmake l "$inventory" "$HOME/.revenant/dyld/$cache" 2>/dev/null |
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

check UIScrollView adjustedContentInsetDidChange
check UIScrollViewDelegate scrollViewDidChangeAdjustedContentInset:

check UIViewController viewSafeAreaInsetsDidChange viewLayoutMarginsDidChange \
                       systemMinimumLayoutMargins viewRespectsSystemMinimumLayoutMargins

check UITableView hasUncommittedUpdates insetsContentViewsToSafeArea separatorInsetReference
check UICollectionView hasUncommittedUpdates reorderingCadence

check UIBarItem largeContentSizeImage largeContentSizeImageInsets
check UISplitViewController primaryEdge
check NSObject accessibilityContainerType accessibilityDragSourceDescriptors accessibilityDropPointDescriptors

check UIPasteboard itemProviders setObjects: setObjects:localOnly:expirationDate: \
                       setItemProviders:localOnly:expirationDate:

check UITableViewDelegate tableView:shouldSpringLoadRowAtIndexPath:withContext:
check UICollectionViewDelegate collectionView:shouldSpringLoadItemAtIndexPath:withContext:

check UIFocusAnimationCoordinator addCoordinatedFocusingAnimations:completion: \
                             addCoordinatedUnfocusingAnimations:completion:

check UIAccessibilityCustomAction initWithAttributedName:target:selector: attributedName
check UIAccessibilityReadingContent accessibilityAttributedContentForLineNumber: accessibilityAttributedPageContent
check UIScrollViewAccessibilityDelegate accessibilityAttributedScrollStatusForScrollView:
check UIPickerViewAccessibilityDelegate pickerView:accessibilityAttributedHintForComponent: \
                                pickerView:accessibilityAttributedLabelForComponent:

check UITextDocumentProxy documentIdentifier selectedText
check NSItemProvider preferredPresentationSize preferredPresentationStyle teamData
check UIInputViewController hasFullAccess needsInputModeSwitchKey

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
    REVENANT_ROOT=$root xmake l "$root/tools/corpus/cache-census.lua" "$name" 6.1.3 4.3 11.0 2>/dev/null |
        grep -E 'of which naming|classes |protocols |^control:'
done
