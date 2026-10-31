local tools = path.absolute(path.join(os.scriptdir(), "..", "tools"))
local implemented = import("implemented", {rootdir = tools, anonymous = true})
local sdkfiles = import("sdk", {rootdir = tools, anonymous = true})
local workspace = import("@addon.revenant.workspace", {anonymous = true})

local AREAS = {
    {
        name = "text tabs, constraint identifiers and screen snapshots",
        sources = {"NSTextTab.m", "NSLayoutConstraint+Identifier7.m", "UIScreen+Snapshot7.m"},
        members = {
            "-[NSTextTab initWithTextAlignment:location:options:]", "-[NSTextTab alignment]", "-[NSTextTab location]", "-[NSTextTab options]",
            "-[NSLayoutConstraint identifier]", "-[UIScreen snapshotViewAfterScreenUpdates:]",
        },
    },
    {
        name = "background fetch, dynamic type and state restoration",
        sources = {"UIApplication+BackgroundFetch7.m", "UIApplication+ContentSize7.m", "UIApplication+StateRestoration7.m", "UIViewController+StateRestoration7.m"},
        members = {
            "-[UIApplication setMinimumBackgroundFetchInterval:]", "-[UIApplication backgroundRefreshStatus]", "-[UIApplication preferredContentSizeCategory]",
            "+[UIApplication registerObjectForStateRestoration:restorationIdentifier:]", "-[UIViewController applicationFinishedRestoringState]",
        },
    },
    {
        name = "bar positions, tab bar layout and the iOS 7 bar members",
        sources = {"RevenantWeak.m", "UINavigationBar+BarPosition7.m", "UISearchBar+BarPosition7.m", "UIToolbar+BarPosition7.m", "UITabBar+Layout7.m", "UITabBarItem+SelectedImage7.m"},
        members = {
            "-[UINavigationBar setBackgroundImage:forBarPosition:barMetrics:]", "-[UINavigationBar backgroundImageForBarPosition:barMetrics:]",
            "-[UISearchBar setBackgroundImage:forBarPosition:barMetrics:]", "-[UISearchBar backgroundImageForBarPosition:barMetrics:]",
            "-[UIToolbar delegate]", "-[UITabBar itemPositioning]", "-[UITabBar itemWidth]", "-[UITabBar itemSpacing]", "-[UITabBar barStyle]",
            "-[UITabBar translucent]", "-[UITabBarItem initWithTitle:image:selectedImage:]",
        },
    },
    {
        name = "text, accessibility, print and gesture members of iOS 7",
        sources = {"NSAttributedString+FileURL7.m", "NSObject+AccessibilityPath7.m", "UIGestureRecognizer+Failure7.m", "UIPrintInteractionController+Options7.m",
                   "UIResponder+TextInput7.m", "UISearchDisplayController+NavigationBar7.m", "UISimpleTextPrintFormatter+Attributed7.m"},
        members = {
            "-[NSAttributedString initWithFileURL:options:documentAttributes:error:]", "-[NSMutableAttributedString readFromFileURL:options:documentAttributes:error:]",
            "-[NSObject accessibilityPath]", "-[UIGestureRecognizer shouldRequireFailureOfGestureRecognizer:]",
            "-[UIGestureRecognizer shouldBeRequiredToFailByGestureRecognizer:]", "-[UIPrintInteractionController showsNumberOfCopies]",
            "-[UIResponder textInputMode]", "-[UIResponder textInputContextIdentifier]", "+[UIResponder clearTextInputContextIdentifier:]",
            "-[UISearchDisplayController displaysSearchBarInNavigationBar]", "-[UISearchDisplayController navigationItem]",
            "-[UISimpleTextPrintFormatter initWithAttributedText:]", "-[UISimpleTextPrintFormatter attributedText]",
        },
    },
    {
        name = "iOS 8 split view controller: display modes, collapse and separate",
        sources = {"RevenantWeak.m", "UISplitViewController+DisplayModes8.m", "UISplitViewController+Collapse8.m"},
        members = {
            "-[UISplitViewController isCollapsed]", "-[UISplitViewController collapsed]", "-[UISplitViewController preferredDisplayMode]",
            "-[UISplitViewController displayMode]", "-[UISplitViewController displayModeButtonItem]",
            "-[UISplitViewController preferredPrimaryColumnWidthFraction]", "-[UISplitViewController minimumPrimaryColumnWidth]",
            "-[UISplitViewController maximumPrimaryColumnWidth]", "-[UISplitViewController primaryColumnWidth]",
            "-[UISplitViewController showViewController:sender:]", "-[UISplitViewController showDetailViewController:sender:]",
            "-[UIViewController collapseSecondaryViewController:forSplitViewController:]",
            "-[UIViewController separateSecondaryViewControllerForSplitViewController:]",
            "-[UINavigationController collapseSecondaryViewController:forSplitViewController:]",
        },
    },
    {
        name = "iOS 8 input view controllers and the objects the system provides",
        sources = {"UIInputViewController.m", "UIResponder+InputViewController8.m", "UILexicon.m", "UIDocumentPickerExtensionViewController.m"},
        members = {
            "@UIInputViewController", "-[UIInputViewController inputView]", "-[UIInputViewController textDocumentProxy]",
            "-[UIInputViewController primaryLanguage]", "-[UIInputViewController hasDictationKey]", "-[UIInputViewController dismissKeyboard]",
            "-[UIResponder inputViewController]", "-[UIResponder inputAccessoryViewController]",
            "@UILexiconEntry", "-[UILexiconEntry documentText]", "-[UILexiconEntry userInput]", "@UILexicon", "-[UILexicon entries]",
            "@UIDocumentPickerExtensionViewController", "-[UIDocumentPickerExtensionViewController documentPickerMode]",
            "-[UIDocumentPickerExtensionViewController originalURL]", "-[UIDocumentPickerExtensionViewController validTypes]",
            "-[UIDocumentPickerExtensionViewController providerIdentifier]", "-[UIDocumentPickerExtensionViewController prepareForPresentationInMode:]",
        },
    },
    {
        name = "iOS 8 and 9 members of existing classes",
        sources = {"RevenantWeak.m", "NSLayoutConstraint+Getter8.m", "NSObject+InterfaceBuilder8.m", "UIAlertAction+Getter8.m", "UIApplication+Getter8.m",
                   "UIDocument+UserActivity8.m", "UIImage+Asset8.m", "UIImageAsset.m", "UILocalNotification+Category8.m", "UISearchController+Getter8.m",
                   "UITouch+MajorRadius8.m", "UIUserNotificationAction+Getter8.m", "UIFocusGuide+Getter9.m", "UIView+Focus9.m", "UIScreen+Focus9.m"},
        members = {
            "-[NSLayoutConstraint active]", "-[NSObject prepareForInterfaceBuilder]", "-[UIAlertAction enabled]",
            "-[UIApplication registeredForRemoteNotifications]", "-[UIDocument userActivity]", "-[UIDocument updateUserActivityState:]",
            "-[UIDocument restoreUserActivityState:]", "-[UIImage imageAsset]", "-[UILocalNotification category]", "-[UILocalNotification alertTitle]",
            "-[UISearchController active]", "-[UITouch majorRadius]", "-[UIUserNotificationAction authenticationRequired]",
            "-[UIUserNotificationAction destructive]", "-[UIFocusGuide enabled]", "-[UIView focused]", "-[UIScreen supportsFocus]",
            "-[UIScreen focusedView]", "-[UIScreen focusedItem]",
        },
    },
    {
        name = "iOS 9 touches, presses, documents, search containers and stack views",
        sources = {"RevenantWeak.m", "NSAttributedString+Attachments9.m", "NSObject+AccessibilityAssistive9.m", "NSTextContainer+Getter9.m", "UIBarButtonItemGroup+Getter9.m",
                   "UIStackView+Getter9.m", "UIEvent+Touches9.m", "UITouch+Force9.m", "UIGestureRecognizer+Presses9.m", "UIViewController+KeyCommands9.m",
                   "UIApplication+KeyCommands.m", "UIApplicationShortcutIcon+SystemImage13.m", "UIStoryboardUnwindSegueSource.m", "UIViewController+Unwind9.m",
                   "UISearchContainerViewController.m", "UIDocument+Progress9.m", "UIImage+RightToLeft9.m", "UIView+FocusState9.m", "UIWebView+Options9.m",
                   "UILabel+Tightening9.m"},
        members = {
            "-[NSAttributedString containsAttachmentsInRange:]", "-[NSObject accessibilityAssistiveTechnologyFocusedIdentifiers]",
            "-[NSTextContainer simpleRectangularTextContainer]", "-[UIBarButtonItemGroup displayingRepresentativeItem]",
            "-[UIStackView baselineRelativeArrangement]", "-[UIStackView layoutMarginsRelativeArrangement]",
            "-[UIEvent coalescedTouchesForTouch:]", "-[UIEvent predictedTouchesForTouch:]", "-[UITouch force]", "-[UITouch maximumPossibleForce]",
            "-[UITouch preciseLocationInView:]", "-[UITouch precisePreviousLocationInView:]", "-[UITouch estimatedProperties]",
            "-[UITouch estimatedPropertiesExpectingUpdates]", "-[UITouch estimationUpdateIndex]",
            "-[UIGestureRecognizer ignorePress:forEvent:]", "-[UIGestureRecognizer pressesBegan:withEvent:]", "-[UIGestureRecognizer pressesChanged:withEvent:]",
            "-[UIGestureRecognizer pressesEnded:withEvent:]", "-[UIGestureRecognizer pressesCancelled:withEvent:]",
            "-[UIGestureRecognizer touchesEstimatedPropertiesUpdated:]", "-[UIResponder touchesEstimatedPropertiesUpdated:]",
            "-[UIViewController addKeyCommand:]", "-[UIViewController removeKeyCommand:]", "+[UIApplicationShortcutIcon iconWithSystemImageName:]",
            "@UIStoryboardUnwindSegueSource", "-[UIStoryboardUnwindSegueSource sourceViewController]", "-[UIStoryboardUnwindSegueSource unwindAction]",
            "-[UIStoryboardUnwindSegueSource sender]", "-[UIViewController childViewControllerContainingSegueSource:]",
            "-[UIViewController allowedChildViewControllersForUnwindingFromSource:]", "-[UIViewController unwindForSegue:towardsViewController:]",
            "@UISearchContainerViewController", "-[UISearchContainerViewController initWithSearchController:]", "-[UISearchContainerViewController searchController]",
            "-[UIDocument progress]", "-[UIImage flipsForRightToLeftLayoutDirection]", "-[UIImage imageFlippedForRightToLeftLayoutDirection]",
            "-[UITableView remembersLastFocusedIndexPath]", "-[UICollectionView remembersLastFocusedIndexPath]", "-[UITableViewCell focusStyle]",
            "-[UIWebView allowsLinkPreview]", "-[UIWebView allowsPictureInPictureMediaPlayback]", "-[UILabel allowsDefaultTighteningForTruncation]",
        },
    },
    {
        name = "iOS 10 constraints, fonts, previews, refresh controls and bars",
        sources = {"UIFont+TextStyles10.m", "UICollectionView+Getter10.m", "UIViewPropertyAnimator+Getter10.m", "NSLayoutConstraint+Anchors10.m",
                   "UILayoutGuide+Ambiguity10.m", "UIImage+RendererFormat10.m", "UIPreviewInteraction.m", "UIViewController+FocusRestore10.m",
                   "UIAccessibilityElement+ContainerSpace10.m", "UIScrollView+RefreshControl10.m", "RevenantRefreshHost.m", "UITabBar+Tint10.m", "UICloudSharingController.m"},
        members = {
            "+[UIFont preferredFontForTextStyle:compatibleWithTraitCollection:]", "-[UICollectionView prefetchingEnabled]",
            "-[UIViewPropertyAnimator interruptible]", "-[UIViewPropertyAnimator manualHitTestingEnabled]", "-[UIViewPropertyAnimator userInteractionEnabled]",
            "-[NSLayoutConstraint firstAnchor]", "-[NSLayoutConstraint secondAnchor]", "-[UILayoutGuide constraintsAffectingLayoutForAxis:]",
            "-[UILayoutGuide hasAmbiguousLayout]", "-[UIImage imageRendererFormat]", "@UIPreviewInteraction", "-[UIPreviewInteraction initWithView:]",
            "-[UIPreviewInteraction view]", "-[UIPreviewInteraction delegate]", "-[UIPreviewInteraction cancelInteraction]",
            "-[UIViewController restoresFocusAfterTransition]", "-[UIAccessibilityElement accessibilityFrameInContainerSpace]",
            "-[UIScrollView refreshControl]", "-[UITabBar unselectedItemTintColor]", "-[UITabBarItem badgeColor]",
            "-[UITabBarItem badgeTextAttributesForState:]", "-[UITabBarItem setBadgeTextAttributes:forState:]",
            "@UICloudSharingController", "-[UICloudSharingController initWithShare:container:]", "-[UICloudSharingController initWithPreparationHandler:]",
            "-[UICloudSharingController delegate]", "-[UICloudSharingController share]", "-[UICloudSharingController availablePermissions]",
        },
    },
    {
        name = "iOS 11 and 12 browser actions, item providers, focus objects, update tracking and safe area changes",
        sources = {"RevenantWeak.m", "UIDragInteraction+Getter11.m", "UIDropProposal+Getter11.m", "UIScreen+Getter11.m", "UIPencilInteraction+Getter12.m",
                   "UIDocumentBrowserAction.m", "NSItemProvider+Presentation11.m", "NSObject+AccessibilityContainerType11.m", "UIFocusSystem.m",
                   "UIFocusMovementHint.m", "UITableView+Updates11.m", "UIViewController+SafeAreaChanges11.m", "UISplitViewController+PrimaryEdge11.m"},
        members = {
            "-[UIDragInteraction enabled]", "-[UIDropProposal precise]", "-[UIScreen captured]", "-[UIPencilInteraction enabled]",
            "@UIDocumentBrowserAction", "-[UIDocumentBrowserAction initWithIdentifier:localizedTitle:availability:handler:]", "-[UIDocumentBrowserAction identifier]",
            "-[UIDocumentBrowserAction localizedTitle]", "-[UIDocumentBrowserAction availability]", "-[UIDocumentBrowserAction image]",
            "-[UIDocumentBrowserAction supportedContentTypes]", "-[UIDocumentBrowserAction supportsMultipleItems]",
            "-[NSItemProvider preferredPresentationSize]", "-[NSItemProvider preferredPresentationStyle]", "-[NSItemProvider teamData]",
            "-[NSObject accessibilityContainerType]", "-[NSObject accessibilityDragSourceDescriptors]", "-[NSObject accessibilityDropPointDescriptors]",
            "@UIFocusSystem", "+[UIFocusSystem environment:containsEnvironment:]", "+[UIFocusSystem focusSystemForEnvironment:]",
            "-[UIFocusSystem requestFocusUpdateToEnvironment:]", "-[UIFocusSystem updateFocusIfNeeded]", "-[UIFocusSystem focusedItem]",
            "@UIFocusMovementHint", "-[UIFocusMovementHint movementDirection]", "-[UIFocusMovementHint perspectiveTransform]", "-[UIFocusMovementHint rotation]",
            "-[UIFocusMovementHint translation]", "-[UIFocusMovementHint interactionTransform]",
            "-[UITableView hasUncommittedUpdates]", "-[UITableView insetsContentViewsToSafeArea]", "-[UITableView separatorInsetReference]",
            "-[UICollectionView hasUncommittedUpdates]", "-[UICollectionView reorderingCadence]", "-[UIViewController viewSafeAreaInsetsDidChange]",
            "-[UIViewController systemMinimumLayoutMargins]", "-[UIViewController viewRespectsSystemMinimumLayoutMargins]",
            "-[UIScrollView adjustedContentInsetDidChange]", "-[UISplitViewController primaryEdge]",
        },
    },
    {
        name = "property-name accessors of properties with a getter=isX, from iOS 13 on",
        sources = {"UIImage+Getter13.m", "UIStatusBarManager+Getter13.m", "UIViewController+Getter13.m", "UIWindowScene+Getter13.m", "UIButton+Getter13.m", "UIPointerInteraction+Getter13.m", "UICellAccessory+Getter14.m", "UICellConfigurationState+Getter14.m", "UICollectionView+Getter14.m", "UIControl+Getter14.m", "UIIndirectScribbleInteraction+Getter14.m", "UIPointerLockState+Getter14.m", "UIScribbleInteraction+Getter14.m", "UIViewConfigurationState+Getter14.m", "NSTextRange+Getter15.m", "NSTextSelection+Getter15.m", "UITableView+Getter15.m", "UIToolTipInteraction+Getter15.m", "NSTextList+Getter16.m", "UIBarButtonItemGroup+Getter16.m", "UIFindInteraction+Getter16.m", "UISceneWindowingBehaviors+Getter16.m", "UITextInputContext+Getter16.m", "UIContentUnavailableButtonProperties+Getter17.m", "UIContentUnavailableView+Getter17.m", "UIScrollView+Getter17.m", "UISceneSystemProtectionManager+Getter18.m", "UITab+Getter18.m", "UITabBarControllerSidebar+Getter18.m", "UIUpdateInfo+Getter18.m", "UIUpdateLink+Getter18.m", "UIGlassEffect+Getter26.m", "UIScrollEdgeEffect+Getter26.m", "UIWindowSceneGeometry+Getter26.m"},
        members = {
            "-[UIImage symbolImage]", "-[UIStatusBarManager statusBarHidden]", "-[UIViewController modalInPresentation]", 
            "-[UIWindowScene fullScreen]", "-[UIButton pointerInteractionEnabled]", "-[UIPointerInteraction enabled]", 
            "-[UICellAccessory hidden]", "-[UICellConfigurationState editing]", "-[UICellConfigurationState expanded]", 
            "-[UICellConfigurationState reordering]", "-[UICellConfigurationState swiped]", "-[UICollectionView editing]", 
            "-[UIControl contextMenuInteractionEnabled]", "-[UIIndirectScribbleInteraction handlingWriting]", "-[UIPointerLockState locked]", 
            "-[UIScribbleInteraction handlingWriting]", "-[UIViewConfigurationState disabled]", "-[UIViewConfigurationState focused]", 
            "-[UIViewConfigurationState highlighted]", "-[UIViewConfigurationState selected]", "-[NSTextRange empty]", 
            "-[NSTextSelection logical]", "-[NSTextSelection transient]", "-[UIButton hovered]", "-[UITableView prefetchingEnabled]", 
            "-[UIToolTipInteraction enabled]", "-[UIViewConfigurationState pinned]", "-[NSTextList ordered]", 
            "-[UIBarButtonItemGroup hidden]", "-[UIFindInteraction findNavigatorVisible]", "-[UISceneWindowingBehaviors closable]", 
            "-[UISceneWindowingBehaviors miniaturizable]", "-[UITextInputContext dictationInputExpected]", 
            "-[UITextInputContext hardwareKeyboardInputExpected]", "-[UITextInputContext pencilInputExpected]", 
            "-[UIContentUnavailableButtonProperties enabled]", "-[UIContentUnavailableView scrollEnabled]", 
            "-[UIScrollView scrollAnimating]", "-[UIScrollView zoomAnimating]", 
            "-[UISceneSystemProtectionManager userAuthenticationEnabled]", "-[UITab hidden]", "-[UITab hiddenByDefault]", 
            "-[UITabBarControllerSidebar hidden]", "-[UIUpdateInfo immediatePresentationExpected]", 
            "-[UIUpdateInfo lowLatencyEventDispatchConfirmed]", "-[UIUpdateInfo performingLowLatencyPhases]", "-[UIUpdateLink enabled]", 
            "-[UITab enabled]", "-[UIGlassEffect interactive]", "-[UIScrollEdgeEffect hidden]", 
            "-[UIWindowSceneGeometry interactivelyResizing]", "-[UIWindowSceneGeometry interfaceOrientationLocked]", 
        },
    },
    {
        name = "iOS 13 to 15 browser options, split view columns, text state and content size limits",
        sources = {"RevenantWeak.m", "UIDocumentBrowserViewController.m", "UIFontDescriptor+Design13.m", "UIResponder+Menus13.m", "UIPrintPageRenderer+Quality14.m",
                   "UIViewController+ContentScrollView15.m", "UITextInteractionState15.m", "UIKit15_0.m", "UIScene+Restoration15.m", "UIApplication+StateRestoration7.m",
                   "UISplitViewController+Columns14.m", "UISplitViewController+DisplayModes8.m", "UISplitViewController+Collapse8.m", "UIView+TraitEnvironment.m",
                   "UICellAccessory.m"},
        members = {
            "-[UIDocumentBrowserViewController initForOpeningContentTypes:]", "-[UIDocumentBrowserViewController contentTypesForRecentDocuments]",
            "-[UIDocumentBrowserViewController shouldShowFileExtensions]", "-[UIDocumentBrowserViewController localizedCreateDocumentActionTitle]",
            "-[UIDocumentBrowserViewController defaultDocumentAspectRatio]", "-[UIFontDescriptor fontDescriptorWithDesign:]",
            "-[UIResponder buildMenuWithBuilder:]", "-[UIPrintPageRenderer currentRenderingQualityForRequestedRenderingQuality:]",
            "-[UIViewController setContentScrollView:forEdge:]", "-[UIViewController contentScrollViewForEdge:]", "-[UITextField interactionState]",
            "-[UITextView interactionState]", "-[UITableView allowsFocus]", "-[UITableView allowsFocusDuringEditing]", "-[UICollectionView allowsFocus]",
            "-[UICollectionView allowsFocusDuringEditing]", "-[UIDatePicker roundsToMinuteInterval]", "-[UIPrintInteractionController showsPaperOrientation]",
            "-[UIActivityViewController allowsProminentActivity]", "-[UIBarButtonItem changesSelectionAsPrimaryAction]", "-[UIWindow canBecomeKeyWindow]",
            "-[UIWindowScene focusSystem]", "-[UIScene extendStateRestoration]", "-[UIScene completeStateRestoration]",
            "-[UISplitViewController initWithStyle:]", "-[UISplitViewController style]", "-[UISplitViewController setViewController:forColumn:]",
            "-[UISplitViewController viewControllerForColumn:]", "-[UISplitViewController hideColumn:]", "-[UISplitViewController showColumn:]",
            "-[UISplitViewController preferredSplitBehavior]", "-[UISplitViewController splitBehavior]", "-[UISplitViewController showsSecondaryOnlyButton]",
            "-[UISplitViewController displayModeButtonVisibility]", "-[UISplitViewController preferredPrimaryColumnWidth]",
            "-[UISplitViewController preferredSupplementaryColumnWidthFraction]", "-[UISplitViewController preferredSupplementaryColumnWidth]",
            "-[UISplitViewController minimumSupplementaryColumnWidth]", "-[UISplitViewController maximumSupplementaryColumnWidth]",
            "-[UISplitViewController supplementaryColumnWidth]", "-[UIView minimumContentSizeCategory]", "-[UIView maximumContentSizeCategory]",
            "@UICellAccessoryDetail", "-[UICellAccessoryDetail actionHandler]",
        },
    },
    {
        name = "iOS 7 web view pagination and the TextKit objects of a text view",
        sources = {"UIWebView+Pagination7.m", "UITextView+TextKit7.m"},
        members = {
            "-[UIWebView paginationMode]", "-[UIWebView paginationBreakingMode]", "-[UIWebView pageLength]", "-[UIWebView gapBetweenPages]", "-[UIWebView pageCount]",
            "-[UITextView initWithFrame:textContainer:]", "-[UITextView textStorage]", "-[UITextView layoutManager]", "-[UITextView textContainer]",
            "-[UITextView selectable]", "-[UITextView linkTextAttributes]",
        },
    },
    {
        name = "iOS 16 and 17 bar item groups, navigation items, page control progress, shapes, image reading",
        sources = {"UIImageReader.m", "UIImage+DynamicRange17.m", "UIBarButtonItemGroup+Creating16.m", "UIDocumentProperties.m", "UINavigationItem+Groups16.m",
                   "UIPageControl+Indicators14.m", "UIPageControlProgress.m", "UIViewController+ContentUnavailable17.m", "UIShape.m", "UIView+HoverStyle17.m"},
        members = {
            "@UIImageReaderConfiguration", "-[UIImageReaderConfiguration pixelsPerInch]", "-[UIImageReaderConfiguration preferredThumbnailSize]",
            "-[UIImageReaderConfiguration prefersHighDynamicRange]", "-[UIImageReaderConfiguration preparesImagesForDisplay]", "@UIImageReader",
            "+[UIImageReader readerWithConfiguration:]", "-[UIImageReader configuration]", "-[UIImageReader imageWithContentsOfFileURL:]",
            "-[UIImageReader imageWithData:]", "-[UIImageReader imageWithContentsOfFileURL:completion:]", "-[UIImageReader imageWithData:completion:]",
            "-[UIImage isHighDynamicRange]", "-[UIImage imageRestrictedToStandardDynamicRange]",
            "+[UIBarButtonItemGroup fixedGroupWithRepresentativeItem:items:]", "+[UIBarButtonItemGroup movableGroupWithCustomizationIdentifier:representativeItem:items:]",
            "+[UIBarButtonItemGroup optionalGroupWithCustomizationIdentifier:inDefaultCustomization:representativeItem:items:]",
            "-[UIBarButtonItem creatingFixedGroup]", "-[UIBarButtonItem creatingMovableGroupWithCustomizationIdentifier:]",
            "-[UIBarButtonItem creatingOptionalGroupWithCustomizationIdentifier:inDefaultCustomization:]", "-[UIBarButtonItem menuRepresentation]",
            "-[UIBarButtonItem preferredMenuElementOrder]", "-[UIButton preferredMenuElementOrder]", "@UIDocumentProperties",
            "-[UIDocumentProperties initWithURL:]", "-[UIDocumentProperties initWithMetadata:]", "-[UIDocumentProperties metadata]",
            "-[UIDocumentProperties dragItemsProvider]", "-[UIDocumentProperties activityViewControllerProvider]", "-[UIDocumentProperties wantsIconRepresentation]",
            "-[UINavigationItem leadingItemGroups]", "-[UINavigationItem trailingItemGroups]", "-[UINavigationItem centerItemGroups]",
            "-[UINavigationItem pinnedTrailingGroup]", "-[UINavigationItem style]", "-[UINavigationItem backAction]", "-[UINavigationItem titleMenuProvider]",
            "-[UINavigationItem renameDelegate]", "-[UINavigationItem documentProperties]", "-[UINavigationItem customizationIdentifier]",
            "-[UINavigationItem additionalOverflowItems]", "-[UINavigationItem overflowPresentationSource]",
            "-[UIPageControl currentPageIndicatorImageForPage:]", "-[UIPageControl setCurrentPageIndicatorImage:forPage:]",
            "-[UIPageControl preferredCurrentPageIndicatorImage]", "-[UIPageControl direction]", "-[UIPageControl progress]",
            "@UIPageControlProgress", "-[UIPageControlProgress delegate]", "-[UIPageControlProgress currentProgress]", "-[UIPageControlProgress progressVisible]",
            "@UIPageControlTimerProgress", "-[UIPageControlTimerProgress initWithPreferredDuration:]", "-[UIPageControlTimerProgress resetsToInitialPageAfterEnd]",
            "-[UIPageControlTimerProgress running]", "-[UIPageControlTimerProgress resumeTimer]", "-[UIPageControlTimerProgress pauseTimer]",
            "-[UIPageControlTimerProgress preferredDuration]", "-[UIPageControlTimerProgress setDuration:forPage:]", "-[UIPageControlTimerProgress durationForPage:]",
            "-[UIViewController contentUnavailableConfiguration]", "-[UIViewController contentUnavailableConfigurationState]",
            "-[UIViewController setNeedsUpdateContentUnavailableConfiguration]", "-[UIViewController updateContentUnavailableConfigurationUsingState:]",
            "@UIShape", "+[UIShape rectShapeWithCornerRadius:]", "+[UIShape rectShapeWithCornerRadius:cornerCurve:]",
            "+[UIShape rectShapeWithCornerRadius:cornerCurve:maskedCorners:]", "+[UIShape fixedRectShapeWithRect:]", "+[UIShape fixedRectShapeWithRect:cornerRadius:]",
            "+[UIShape fixedRectShapeWithRect:cornerRadius:cornerCurve:maskedCorners:]", "+[UIShape shapeWithBezierPath:]", "+[UIShape shapeWithProvider:]",
            "-[UIShape resolvedShapeInContext:]", "-[UIShape shapeByApplyingInsets:]", "-[UIShape shapeByApplyingInset:]", "@UIResolvedShape",
            "-[UIResolvedShape shape]", "-[UIResolvedShape boundingRect]", "-[UIResolvedShape path]", "-[UIResolvedShape shapeByApplyingInsets:]",
            "-[UIResolvedShape shapeByApplyingInset:]", "@UIShapeResolutionContext", "-[UIShapeResolutionContext contentShape]",
            "@UIHoverStyle", "+[UIHoverStyle styleWithEffect:shape:]", "+[UIHoverStyle styleWithShape:]", "+[UIHoverStyle automaticStyle]", "-[UIHoverStyle effect]",
            "-[UIHoverStyle shape]", "-[UIHoverStyle isEnabled]", "-[UIHoverStyle enabled]", "@UIHoverHighlightEffect", "+[UIHoverHighlightEffect effect]", "@UIHoverLiftEffect",
            "+[UIHoverLiftEffect effect]", "@UIHoverAutomaticEffect", "+[UIHoverAutomaticEffect effect]", "-[UIView hoverStyle]",
        },
    },
    {
        name = "iOS 16 and 17 data objects, paste control, scene activation requests and canvas feedback",
        sources = {"UIKit17_0.m", "UIPasteControl.m", "UICanvasFeedbackGenerator.m", "UIPageControlProgress.m", "UIShape.m"},
        members = {
            "@UITextItem", "-[UITextItem contentType]", "-[UITextItem range]", "-[UITextItem link]", "-[UITextItem textAttachment]", "-[UITextItem tagIdentifier]",
            "@UITextItemMenuPreview", "+[UITextItemMenuPreview defaultPreview]", "-[UITextItemMenuPreview initWithView:]", "@UITextItemMenuConfiguration",
            "+[UITextItemMenuConfiguration configurationWithMenu:]", "+[UITextItemMenuConfiguration configurationWithPreview:menu:]", "@UIPencilHoverPose",
            "-[UIPencilHoverPose location]", "-[UIPencilHoverPose zOffset]", "-[UIPencilHoverPose azimuthAngle]", "-[UIPencilHoverPose azimuthUnitVector]",
            "-[UIPencilHoverPose altitudeAngle]", "-[UIPencilHoverPose rollAngle]", "@UIPencilInteractionTap", "-[UIPencilInteractionTap timestamp]",
            "-[UIPencilInteractionTap hoverPose]", "@UIPencilInteractionSqueeze", "-[UIPencilInteractionSqueeze timestamp]", "-[UIPencilInteractionSqueeze phase]",
            "-[UIPencilInteractionSqueeze hoverPose]", "@UISymbolEffectCompletionContext", "-[UISymbolEffectCompletionContext finished]",
            "-[UISymbolEffectCompletionContext sender]", "-[UISymbolEffectCompletionContext effect]", "-[UISymbolEffectCompletionContext contentTransition]",
            "@UIMenuDisplayPreferences", "-[UIMenuDisplayPreferences maximumNumberOfTitleLines]", "@UIWindowSceneStandardPlacement",
            "+[UIWindowSceneStandardPlacement standardPlacement]", "@UIWindowSceneProminentPlacement", "+[UIWindowSceneProminentPlacement prominentPlacement]",
            "@UISceneSessionActivationRequest", "+[UISceneSessionActivationRequest request]", "+[UISceneSessionActivationRequest requestWithRole:]",
            "+[UISceneSessionActivationRequest requestWithSession:]", "-[UISceneSessionActivationRequest role]", "-[UISceneSessionActivationRequest session]",
            "-[UISceneSessionActivationRequest userActivity]", "-[UISceneSessionActivationRequest options]",
            "-[UIApplication activateSceneSessionForRequest:errorHandler:]", "-[UIPencilInteraction initWithDelegate:]", "-[UITouch rollAngle]",
            "-[UIHoverGestureRecognizer rollAngle]", "-[UITextSelectionRect transform]", "-[UILabel preferredVibrancy]", "-[UITextView borderStyle]",
            "@UIPasteControl", "-[UIPasteControl initWithConfiguration:]", "-[UIPasteControl configuration]", "-[UIPasteControl target]",
            "@UICanvasFeedbackGenerator", "-[UICanvasFeedbackGenerator alignmentOccurredAtLocation:]", "-[UICanvasFeedbackGenerator pathCompletedAtLocation:]",
            "-[UIPageControlProgress progressVisible]", "-[UIPageControlTimerProgress running]", "-[UIHoverStyle enabled]",
        },
    },
    {
        name = "user notifications: the notification center over local notifications",
        sources = {"UNUserNotificationCenter.m"},
        members = {
            "@UNUserNotificationCenter", "+[UNUserNotificationCenter currentNotificationCenter]", "-[UNUserNotificationCenter delegate]",
            "-[UNUserNotificationCenter setDelegate:]", "-[UNUserNotificationCenter requestAuthorizationWithOptions:completionHandler:]",
            "-[UNUserNotificationCenter getNotificationSettingsWithCompletionHandler:]", "-[UNUserNotificationCenter addNotificationRequest:withCompletionHandler:]",
            "-[UNUserNotificationCenter setNotificationCategories:]", "-[UNUserNotificationCenter getNotificationCategoriesWithCompletionHandler:]",
            "-[UNUserNotificationCenter getPendingNotificationRequestsWithCompletionHandler:]",
            "-[UNUserNotificationCenter removePendingNotificationRequestsWithIdentifiers:]", "-[UNUserNotificationCenter removeAllPendingNotificationRequests]",
        },
    },
    {
        name = "UIKeyboardType backport: webSearch and asciiCapableNumberPad",
        sources = {"UIKeyboardType+Backport.m"},
        members = {
            "revenant_keyboard_type_fallback", "revenant_keyboard_type_name",
        },
    },
    {
        name = "UIBackgroundFetchResult enum backport",
        sources = {"UIBackgroundFetchResult+Backport.m"},
        members = {
            "revenant_background_fetch_result_name",
        },
    },
    {
        name = "UIUserActivityRestoring protocol backport",
        sources = {"UIUserActivityRestoring+Backport.m"},
        members = {
            "@UIUserActivityRestoring", "revenant_emit_UIUserActivityRestoring",
        },
    },
    {
        name = "UIApplicationDelegate backport: background fetch, open URL, user activity, shortcut actions",
        sources = {"UIApplicationDelegate+Backport.m"},
        members = {
            "-[UIApplicationDelegate application:performFetchWithCompletionHandler:]",
            "-[UIApplicationDelegate application:didReceiveRemoteNotification:fetchCompletionHandler:]",
            "-[UIApplicationDelegate application:handleEventsForBackgroundURLSession:completionHandler:]",
            "-[UIApplicationDelegate application:openURL:options:]",
            "-[UIApplicationDelegate application:continueUserActivity:restorationHandler:]",
            "-[UIApplicationDelegate application:willContinueUserActivityWithType:]",
            "-[UIApplicationDelegate application:didFailToContinueUserActivityWithType:error:]",
            "-[UIApplicationDelegate application:didUpdateUserActivity:]",
            "-[UIApplicationDelegate application:performActionForShortcutItem:completionHandler:]",
        },
    },
    {
        name = "iOS 13 large content viewer: the interaction and the item properties of views",
        sources = {"UILargeContentViewer.m"},
        members = {
            "@UILargeContentViewerInteraction", "-[UILargeContentViewerInteraction initWithDelegate:]", "-[UILargeContentViewerInteraction delegate]",
            "-[UILargeContentViewerInteraction gestureRecognizerForExclusionRelationship]", "+[UILargeContentViewerInteraction isEnabled]",
            "-[UILargeContentViewerInteraction view]", "-[UIView showsLargeContentViewer]", "-[UIView setShowsLargeContentViewer:]",
            "-[UIView largeContentTitle]", "-[UIView setLargeContentTitle:]", "-[UIView largeContentImage]", "-[UIView setLargeContentImage:]",
            "-[UIView scalesLargeContentImage]", "-[UIView setScalesLargeContentImage:]", "-[UIView largeContentImageInsets]",
            "-[UIView setLargeContentImageInsets:]",
        },
    },
    {
        name = "iOS 13 and 14 button role, switch title and segmented control tint",
        sources = {"UIButton+Actions14.m", "UISwitch+Style14.m", "UISegmentedControl+SelectedTint13.m"},
        members = {
            "-[UIButton role]", "-[UIButton setRole:]", "-[UISwitch title]", "-[UISwitch setTitle:]", "-[UISwitch preferredStyle]",
            "-[UISegmentedControl selectedSegmentTintColor]", "-[UISegmentedControl setSelectedSegmentTintColor:]",
        },
    },
    {
        name = "iOS 11, 13 and 14 scroll indicator insets, pasteboard detection, split view background and search scope bar",
        sources = {"UIScrollView+IndicatorInsets13.m", "UIPasteboard+Detection14.m", "UISplitViewController+Background13.m", "UISearchController+ScopeBar.m"},
        members = {
            "-[UIScrollView automaticallyAdjustsScrollIndicatorInsets]", "-[UIScrollView setAutomaticallyAdjustsScrollIndicatorInsets:]",
            "-[UIPasteboard detectPatternsForPatterns:completionHandler:]", "-[UIPasteboard detectPatternsForPatterns:inItemSet:completionHandler:]",
            "-[UIPasteboard detectValuesForPatterns:completionHandler:]", "-[UIPasteboard detectValuesForPatterns:inItemSet:completionHandler:]",
            "-[UISplitViewController primaryBackgroundStyle]", "-[UISplitViewController setPrimaryBackgroundStyle:]",
            "-[UISearchController automaticallyShowsScopeBar]", "-[UISearchController setAutomaticallyShowsScopeBar:]",
        },
    },
    {
        name = "iOS 16 edit menu interaction",
        sources = {"UIEditMenuInteraction.m", "RevenantMenuElements.m"},
        members = {
            "@UIEditMenuInteraction", "-[UIEditMenuInteraction initWithDelegate:]", "-[UIEditMenuInteraction delegate]", "-[UIEditMenuInteraction view]",
            "-[UIEditMenuInteraction presentEditMenuWithConfiguration:]", "-[UIEditMenuInteraction dismissMenu]", "-[UIEditMenuInteraction reloadVisibleMenu]",
            "-[UIEditMenuInteraction updateVisibleMenuPositionAnimated:]", "-[UIEditMenuInteraction locationInView:]",
        },
    },
    {
        name = "iOS 13 font picker: the configuration and the picker",
        sources = {"UIFontPickerViewController.m"},
        members = {
            "@UIFontPickerViewController", "@UIFontPickerViewControllerConfiguration", "-[UIFontPickerViewControllerConfiguration includeFaces]",
            "-[UIFontPickerViewControllerConfiguration setIncludeFaces:]", "-[UIFontPickerViewControllerConfiguration displayUsingSystemFont]",
            "-[UIFontPickerViewControllerConfiguration filteredTraits]", "-[UIFontPickerViewControllerConfiguration filteredLanguagesPredicate]",
            "+[UIFontPickerViewControllerConfiguration filterPredicateForFilteredLanguages:]", "-[UIFontPickerViewController initWithConfiguration:]",
            "-[UIFontPickerViewController configuration]", "-[UIFontPickerViewController delegate]", "-[UIFontPickerViewController setDelegate:]",
            "-[UIFontPickerViewController selectedFontDescriptor]", "-[UIFontPickerViewController setSelectedFontDescriptor:]",
        },
    },
    {
        name = "iOS 14 color well",
        sources = {"UIColorWell.m"},
        members = {
            "@UIColorWell", "-[UIColorWell initWithFrame:]", "-[UIColorWell selectedColor]", "-[UIColorWell setSelectedColor:]",
            "-[UIColorWell supportsAlpha]", "-[UIColorWell setSupportsAlpha:]", "-[UIColorWell title]", "-[UIColorWell setTitle:]",
        },
    },
}

local function key_of(member)
    local class = member:match("^@(%S+)$")
    if class then
        return "class||" .. class
    end
    local sign, owner, selector = member:match("^([%+%-])%[(%S+) ([^%]]+)%]$")
    assert(sign, "not a member: " .. member)
    return (sign == "+" and "class method" or "instance method") .. "|" .. owner .. "|" .. selector
end

function main()
    local sdk = os.getenv("REVENANT_GEN_SDK")
    if not sdk or sdk == "" then
        sdk = sdkfiles.sdk_folder()
    end
    local sources = path.absolute(path.join(os.scriptdir(), "..", "src", "UIKit"))
    local root = path.join(workspace.scratch(), "uikit-test")
    os.tryrm(root)
    local objects, total = 0, 0
    for _, area in ipairs(AREAS) do
        for _, name in ipairs(area.sources) do
            local object = path.join(root, "UIKit", "src", "UIKit", name .. ".o")
            os.mkdir(path.directory(object))
            os.vrunv("clang", {"-target", "armv7-apple-ios6.0", "-isysroot", sdk, "-fobjc-arc", "-Os", "-w", "-c", "-o", object,
                path.join(sources, name)})
            objects = objects + 1
        end
    end
    local keys = implemented.from_objects(root).UIKit or {}
    local missing = {}
    for _, area in ipairs(AREAS) do
        for _, member in ipairs(area.members) do
            total = total + 1
            if not keys[key_of(member)] then
                table.insert(missing, area.name .. ": " .. member)
            end
        end
    end
    assert(#missing == 0, "members not implemented by the compiled UIKit objects:\n" .. table.concat(missing, "\n"))
    os.tryrm(root)
    print("uikit tests passed: " .. total .. " members implemented by " .. objects .. " objects in " .. #AREAS .. " areas")
end
