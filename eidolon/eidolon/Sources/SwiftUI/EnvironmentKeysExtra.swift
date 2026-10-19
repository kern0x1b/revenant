// the environment keys of SDK 26.2 this module carries: the type Apple declares and the default the
// framework of macOS 27 answers with (.agent-work/host/envdefaults.txt holds the measurement).
// A key is storage: a value views read and modifiers write, whether or not a view acts on it.
// Keys with no public default on the host take the value Apple's own bodies show, or the one a
// person on iOS 6 could not have switched on.

struct _accessibilityDifferentiateWithoutColorKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _accessibilityInvertColorsKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _accessibilityLargeContentViewerEnabledKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _accessibilityQuickActionsEnabledKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _accessibilityReduceMotionKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _accessibilityReduceTransparencyKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _accessibilityShowButtonShapesKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _buttonBorderShapeKey: EnvironmentKey { static var defaultValue: ButtonBorderShape { .automatic } }
struct _colorSchemeContrastKey: EnvironmentKey { static var defaultValue: ColorSchemeContrast { .standard } }
struct _deviceVariantKey: EnvironmentKey { static var defaultValue: _DeviceVariant { .regular } }
struct _emittableNavigationIndicatorVisibilityABIKey: EnvironmentKey { static var defaultValue: Visibility { .hidden } }
struct _focusSystemKey: EnvironmentKey { static var defaultValue: _FocusSystem { _FocusSystem() } }
struct _navigationIndicatorVisibilityABIKey: EnvironmentKey { static var defaultValue: Visibility { .hidden } }
struct _openSensitiveURLKey: EnvironmentKey { static var defaultValue: OpenURLAction { OpenURLAction() } }
struct _openURLKey: EnvironmentKey { static var defaultValue: OpenURLAction { OpenURLAction() } }
struct _plainListSectionSpacingKey: EnvironmentKey { static var defaultValue: CGFloat? { nil } }
struct _useVibrantStylingKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _writingToolsBehaviorKey: EnvironmentKey { static var defaultValue: WritingToolsBehavior? { nil } }
struct AccessibilityAssistiveAccessEnabledKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct AccessibilityDimFlashingLightsKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct AccessibilityPlayAnimatedImagesKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct AccessibilityPrefersHeadAnchorAlternativeKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct AccessibilityShowBordersKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct AppearsActiveKey: EnvironmentKey { static var defaultValue: Bool { true } }
struct BackgroundMaterialKey: EnvironmentKey { static var defaultValue: Material? { nil } }
struct BackgroundProminenceKey: EnvironmentKey { static var defaultValue: BackgroundProminence { BackgroundProminence.standard } }
struct BadgeProminenceKey: EnvironmentKey { static var defaultValue: BadgeProminence { BadgeProminence.standard } }
struct ButtonRepeatBehaviorKey: EnvironmentKey { static var defaultValue: ButtonRepeatBehavior { ButtonRepeatBehavior.automatic } }
struct ButtonSizingKey: EnvironmentKey { static var defaultValue: ButtonSizing { ButtonSizing.automatic } }
struct ContentTransitionAddsDrawingGroupKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct DefaultAppStorageDefaultsKey: EnvironmentKey { static var defaultValue: UserDefaults { UserDefaults.standard } }
struct DocumentConfigurationKey: EnvironmentKey { static var defaultValue: DocumentConfiguration? { nil } }
struct FindContextKey: EnvironmentKey { static var defaultValue: FindContext? { nil } }
struct IsFocusEffectEnabledKey: EnvironmentKey { static var defaultValue: Bool { true } }
struct IsTabBarShowingSectionsKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct IsUserAuthenticationEnabledKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct KeyboardShortcutKey: EnvironmentKey { static var defaultValue: KeyboardShortcut? { nil } }
struct LabelIconToTitleSpacingKey: EnvironmentKey { static var defaultValue: CGFloat? { nil } }
struct LabelReservedIconWidthKey: EnvironmentKey { static var defaultValue: CGFloat? { nil } }
struct LabelsVisibilityKey: EnvironmentKey { static var defaultValue: Visibility { .automatic } }
struct MaterialActiveAppearanceKey: EnvironmentKey { static var defaultValue: MaterialActiveAppearance { MaterialActiveAppearance.automatic } }
struct MenuIndicatorVisibilityKey: EnvironmentKey { static var defaultValue: Visibility { .automatic } }
struct MenuOrderKey: EnvironmentKey { static var defaultValue: MenuOrder { MenuOrder.automatic } }
struct NavigationLinkIndicatorVisibilityKey: EnvironmentKey { static var defaultValue: Visibility { .hidden } }
struct PreferredPencilDoubleTapActionKey: EnvironmentKey { static var defaultValue: PencilPreferredAction { PencilPreferredAction.switchEraser } }
struct PreferredPencilSqueezeActionKey: EnvironmentKey { static var defaultValue: PencilPreferredAction { PencilPreferredAction.showContextualPalette } }
struct RemoteDeviceIdentifierKey: EnvironmentKey { static var defaultValue: RemoteDeviceIdentifier? { nil } }
struct ResetFocusKey: EnvironmentKey { static var defaultValue: ResetFocusAction { ResetFocusAction() } }
struct ScrollDismissesKeyboardModeKey: EnvironmentKey { static var defaultValue: ScrollDismissesKeyboardMode { ScrollDismissesKeyboardMode.automatic } }
struct SearchSuggestionsPlacementKey: EnvironmentKey { static var defaultValue: SearchSuggestionsPlacement { .automatic } }
struct SidebarRowSizeKey: EnvironmentKey { static var defaultValue: SidebarRowSize { .medium } }
struct SpringLoadingBehaviorKey: EnvironmentKey { static var defaultValue: SpringLoadingBehavior { SpringLoadingBehavior.automatic } }
struct SupportsRemoteScenesKey: EnvironmentKey { static var defaultValue: Bool { true } }
struct SymbolColorRenderingModeKey: EnvironmentKey { static var defaultValue: SymbolColorRenderingMode? { nil } }
struct SymbolVariableValueModeKey: EnvironmentKey { static var defaultValue: SymbolVariableValueMode? { nil } }
struct TabBarPlacementKey: EnvironmentKey { static var defaultValue: TabBarPlacement? { nil } }
struct TabViewBottomAccessoryPlacementKey: EnvironmentKey { static var defaultValue: TabViewBottomAccessoryPlacement? { nil } }
struct TextSelectionAffinityKey: EnvironmentKey { static var defaultValue: TextSelectionAffinity { .automatic } }
struct ToolbarLabelStyleKey: EnvironmentKey { static var defaultValue: ToolbarLabelStyle? { nil } }
struct WritingToolsBehaviorKey: EnvironmentKey { static var defaultValue: WritingToolsBehavior? { nil } }

extension EnvironmentValues {
    public var _accessibilityDifferentiateWithoutColor: Bool {
        get { self[_accessibilityDifferentiateWithoutColorKey.self] }
        set { self[_accessibilityDifferentiateWithoutColorKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _accessibilityInvertColors: Bool {
        get { self[_accessibilityInvertColorsKey.self] }
        set { self[_accessibilityInvertColorsKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _accessibilityLargeContentViewerEnabled: Bool {
        get { self[_accessibilityLargeContentViewerEnabledKey.self] }
        set { self[_accessibilityLargeContentViewerEnabledKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _accessibilityQuickActionsEnabled: Bool {
        get { self[_accessibilityQuickActionsEnabledKey.self] }
        set { self[_accessibilityQuickActionsEnabledKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _accessibilityReduceMotion: Bool {
        get { self[_accessibilityReduceMotionKey.self] }
        set { self[_accessibilityReduceMotionKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _accessibilityReduceTransparency: Bool {
        get { self[_accessibilityReduceTransparencyKey.self] }
        set { self[_accessibilityReduceTransparencyKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _accessibilityShowButtonShapes: Bool {
        get { self[_accessibilityShowButtonShapesKey.self] }
        set { self[_accessibilityShowButtonShapesKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _buttonBorderShape: ButtonBorderShape {
        get { self[_buttonBorderShapeKey.self] }
        set { self[_buttonBorderShapeKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _colorSchemeContrast: ColorSchemeContrast {
        get { self[_colorSchemeContrastKey.self] }
        set { self[_colorSchemeContrastKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _deviceVariant: _DeviceVariant {
        get { self[_deviceVariantKey.self] }
        set { self[_deviceVariantKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _emittableNavigationIndicatorVisibilityABI: Visibility {
        get { self[_emittableNavigationIndicatorVisibilityABIKey.self] }
        set { self[_emittableNavigationIndicatorVisibilityABIKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _focusSystem: _FocusSystem {
        get { self[_focusSystemKey.self] }
        set { self[_focusSystemKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _navigationIndicatorVisibilityABI: Visibility {
        get { self[_navigationIndicatorVisibilityABIKey.self] }
        set { self[_navigationIndicatorVisibilityABIKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _openSensitiveURL: OpenURLAction {
        get { self[_openSensitiveURLKey.self] }
        set { self[_openSensitiveURLKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _openURL: OpenURLAction {
        get { self[_openURLKey.self] }
        set { self[_openURLKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _plainListSectionSpacing: CGFloat? {
        get { self[_plainListSectionSpacingKey.self] }
        set { self[_plainListSectionSpacingKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _useVibrantStyling: Bool {
        get { self[_useVibrantStylingKey.self] }
        set { self[_useVibrantStylingKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var _writingToolsBehavior: WritingToolsBehavior? {
        get { self[_writingToolsBehaviorKey.self] }
        set { self[_writingToolsBehaviorKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var accessibilityAssistiveAccessEnabled: Bool {
        get { self[AccessibilityAssistiveAccessEnabledKey.self] }
        set { self[AccessibilityAssistiveAccessEnabledKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var accessibilityDimFlashingLights: Bool {
        get { self[AccessibilityDimFlashingLightsKey.self] }
        set { self[AccessibilityDimFlashingLightsKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var accessibilityPlayAnimatedImages: Bool {
        get { self[AccessibilityPlayAnimatedImagesKey.self] }
        set { self[AccessibilityPlayAnimatedImagesKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var accessibilityPrefersHeadAnchorAlternative: Bool {
        get { self[AccessibilityPrefersHeadAnchorAlternativeKey.self] }
        set { self[AccessibilityPrefersHeadAnchorAlternativeKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var accessibilityShowBorders: Bool {
        get { self[AccessibilityShowBordersKey.self] }
        set { self[AccessibilityShowBordersKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var appearsActive: Bool {
        get { self[AppearsActiveKey.self] }
        set { self[AppearsActiveKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var backgroundMaterial: Material? {
        get { self[BackgroundMaterialKey.self] }
        set { self[BackgroundMaterialKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var backgroundProminence: BackgroundProminence {
        get { self[BackgroundProminenceKey.self] }
        set { self[BackgroundProminenceKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var badgeProminence: BadgeProminence {
        get { self[BadgeProminenceKey.self] }
        set { self[BadgeProminenceKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var buttonRepeatBehavior: ButtonRepeatBehavior {
        get { self[ButtonRepeatBehaviorKey.self] }
        set { self[ButtonRepeatBehaviorKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var buttonSizing: ButtonSizing {
        get { self[ButtonSizingKey.self] }
        set { self[ButtonSizingKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var contentTransitionAddsDrawingGroup: Bool {
        get { self[ContentTransitionAddsDrawingGroupKey.self] }
        set { self[ContentTransitionAddsDrawingGroupKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var defaultAppStorageDefaults: UserDefaults {
        get { self[DefaultAppStorageDefaultsKey.self] }
        set { self[DefaultAppStorageDefaultsKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var documentConfiguration: DocumentConfiguration? {
        get { self[DocumentConfigurationKey.self] }
        set { self[DocumentConfigurationKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var findContext: FindContext? {
        get { self[FindContextKey.self] }
        set { self[FindContextKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var isFocusEffectEnabled: Bool {
        get { self[IsFocusEffectEnabledKey.self] }
        set { self[IsFocusEffectEnabledKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var isTabBarShowingSections: Bool {
        get { self[IsTabBarShowingSectionsKey.self] }
        set { self[IsTabBarShowingSectionsKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var isUserAuthenticationEnabled: Bool {
        get { self[IsUserAuthenticationEnabledKey.self] }
        set { self[IsUserAuthenticationEnabledKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var keyboardShortcut: KeyboardShortcut? {
        get { self[KeyboardShortcutKey.self] }
        set { self[KeyboardShortcutKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var labelIconToTitleSpacing: CGFloat? {
        get { self[LabelIconToTitleSpacingKey.self] }
        set { self[LabelIconToTitleSpacingKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var labelReservedIconWidth: CGFloat? {
        get { self[LabelReservedIconWidthKey.self] }
        set { self[LabelReservedIconWidthKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var labelsVisibility: Visibility {
        get { self[LabelsVisibilityKey.self] }
        set { self[LabelsVisibilityKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var materialActiveAppearance: MaterialActiveAppearance {
        get { self[MaterialActiveAppearanceKey.self] }
        set { self[MaterialActiveAppearanceKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var menuIndicatorVisibility: Visibility {
        get { self[MenuIndicatorVisibilityKey.self] }
        set { self[MenuIndicatorVisibilityKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var menuOrder: MenuOrder {
        get { self[MenuOrderKey.self] }
        set { self[MenuOrderKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var navigationLinkIndicatorVisibility: Visibility {
        get { self[NavigationLinkIndicatorVisibilityKey.self] }
        set { self[NavigationLinkIndicatorVisibilityKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var preferredPencilDoubleTapAction: PencilPreferredAction {
        get { self[PreferredPencilDoubleTapActionKey.self] }
        set { self[PreferredPencilDoubleTapActionKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var preferredPencilSqueezeAction: PencilPreferredAction {
        get { self[PreferredPencilSqueezeActionKey.self] }
        set { self[PreferredPencilSqueezeActionKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var remoteDeviceIdentifier: RemoteDeviceIdentifier? {
        get { self[RemoteDeviceIdentifierKey.self] }
        set { self[RemoteDeviceIdentifierKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var resetFocus: ResetFocusAction {
        get { self[ResetFocusKey.self] }
        set { self[ResetFocusKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var scrollDismissesKeyboardMode: ScrollDismissesKeyboardMode {
        get { self[ScrollDismissesKeyboardModeKey.self] }
        set { self[ScrollDismissesKeyboardModeKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var searchSuggestionsPlacement: SearchSuggestionsPlacement {
        get { self[SearchSuggestionsPlacementKey.self] }
        set { self[SearchSuggestionsPlacementKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var sidebarRowSize: SidebarRowSize {
        get { self[SidebarRowSizeKey.self] }
        set { self[SidebarRowSizeKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var springLoadingBehavior: SpringLoadingBehavior {
        get { self[SpringLoadingBehaviorKey.self] }
        set { self[SpringLoadingBehaviorKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var supportsRemoteScenes: Bool {
        get { self[SupportsRemoteScenesKey.self] }
        set { self[SupportsRemoteScenesKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var symbolColorRenderingMode: SymbolColorRenderingMode? {
        get { self[SymbolColorRenderingModeKey.self] }
        set { self[SymbolColorRenderingModeKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var symbolVariableValueMode: SymbolVariableValueMode? {
        get { self[SymbolVariableValueModeKey.self] }
        set { self[SymbolVariableValueModeKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var tabBarPlacement: TabBarPlacement? {
        get { self[TabBarPlacementKey.self] }
        set { self[TabBarPlacementKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var tabViewBottomAccessoryPlacement: TabViewBottomAccessoryPlacement? {
        get { self[TabViewBottomAccessoryPlacementKey.self] }
        set { self[TabViewBottomAccessoryPlacementKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var textSelectionAffinity: TextSelectionAffinity {
        get { self[TextSelectionAffinityKey.self] }
        set { self[TextSelectionAffinityKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var toolbarLabelStyle: ToolbarLabelStyle? {
        get { self[ToolbarLabelStyleKey.self] }
        set { self[ToolbarLabelStyleKey.self] = newValue }
    }
}
extension EnvironmentValues {
    public var writingToolsBehavior: WritingToolsBehavior? {
        get { self[WritingToolsBehaviorKey.self] }
        set { self[WritingToolsBehaviorKey.self] = newValue }
    }
}
