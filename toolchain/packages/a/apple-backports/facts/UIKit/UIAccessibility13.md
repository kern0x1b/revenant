# Accessibility of iOS 13 and 14

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), for the answers and the values, and the `views13` group of
`tests/backports/host/uikit2` for the members that are categories.

## Settings

`UIAccessibilityShouldDifferentiateWithoutColor()`, `UIAccessibilityIsOnOffSwitchLabelsEnabled()`, `UIAccessibilityButtonShapesEnabled()`
and `UIAccessibilityPrefersCrossFadeTransitions()` answer NO: iOS 6 has none of the settings. `UIAccessibilityIsVideoAutoplayEnabled()`
answers YES, as the host does with the setting at its default, and nothing on the release turns video previews off. The
notifications that would say they changed - `...ShouldDifferentiateWithoutColorDidChangeNotification`,
`...OnOffSwitchLabelsDidChangeNotification`, `...VideoAutoplayStatusDidChangeNotification`, `...ButtonShapesEnabledStatusDidChangeNotification`
and `...PrefersCrossFadeTransitionsStatusDidChangeNotification` - are their own names and are never posted.

## Names

`UIAccessibilityTextAttributeContext`, `UIAccessibilitySpeechAttributeSpellOut` and the seven `UIAccessibilityTextualContext...`
values are the strings of their names, as the host has them. VoiceOver of iOS 6 reads no text by them.

## Objects

`accessibilityUserInputLabels` answers an empty array until set, `accessibilityAttributedUserInputLabels` nil; setting one gives the
other: the attributed labels of plain ones are attributed strings with no attributes, the plain ones of attributed labels their
strings. The arrays are copied. `accessibilityTextualContext` and `accessibilityRespondsToUserInteraction` (NO) are kept. There is no
Voice Control or dictation context on the release to read them, so the first one set says so once in the log.

## Custom actions

`UIAccessibilityCustomAction` on this release: the constructors and properties are real, and VoiceOver lists none of the actions.
The handler forms `-initWithName:actionHandler:` (iOS 13) and `-initWithName:image:actionHandler:` and
`-initWithName:image:target:selector:` (iOS 14) are made and keep their handler and image, with `actionHandler` and `image` as
properties, read back as they were set. An action is performed by `-charonPerform`: a handler is called once with the action and
answers what it answers; a target gets its selector once, with the action as the one argument; an action with neither performs
nothing. The `customaction` group of `tests/backports/host/uikit2` checks each of the three, and compares the constructors and
the properties with the host's answers on the same arguments.

The release never performs one, and that is the release's own behaviour, not a gap of the port. On 6.1.3, VoiceOver has no
custom-actions UI: no rotor or menu of the release lists an element's custom actions, so the system has nothing to perform one
with. `-charonPerform` is therefore invoked by the port's own callers and by the `customaction` group, never by VoiceOver, and the
rows say so in their effect.

The measurement, from `tools/corpus/objc-inventory.lua` over the 6.1.3 cache (the inventory of every class, 12549 lines): the
selectors that name a custom action or an accessibility perform are

    -accessibilityCustomActions  (the getter; the inventory has no setter of it on the release)
    -accessibilityPerformCustomAction:, -accessibilityPerformAction:withValue:,
    -accessibilityPerformEscape, -accessibilityPerformMagicTap, -accessibilityActivate

and every one of them is carried by NSObject alone. No class of the release overrides one: a class that performed a custom
action on the element would declare its selector, and none does. The bodies of the NSObject entries are not read here
(the inventory gives selectors, not addresses), so the claim rests on the owners and on the absence of a custom-action UI, not on
disassembly of the defaults. The port's `-charonPerform` is the only code that performs a custom action on this release.

The two iOS 14 forms that take an ATTRIBUTED name **and** an image are made too, in
`UIKit/UIAccessibilityCustomAction+AttributedNameImage14.m`, and the iOS 11 form `initWithAttributedName:target:selector:` is
`implemented` in `UIKit/UIAccessibilityCustomAction+AttributedName11.m` (`registry/UIKit/ios11.json`). Each of the two is one
composition, not a second source of truth: the name and the target or the handler come from the 11.0 form and the image from the
port's own `image` property.

The release carries none of this. `objc.inventory` over both band ends, read with

    CHARON_ROOT=<checkout> xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7
    CHARON_ROOT=<checkout> xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/4.3/dyld_shared_cache_armv7

finds `UIAccessibilityCustomAction` as neither a class nor a protocol in either cache - the same run read 11378 classes and 1171
protocols on 6.1.3 and 7187 and 564 on 4.3, which is the control: the reader saw the whole of both caches, so a zero is the
release's and not the reader's. The port builds the class in `UIKit/UIAccessibilityCustomAction.m`, which is why a row here can be
`implemented` at all.

What the two initialisers do is the host's own UIKit under Mac Catalyst (macOS 27.0), recorded by
`tests/backports/host/uikitconst/run.sh` over the twenty `action.*` cases in `tests/backports/device/uikitconst-cases.m`, which
the device test reads out of `tests/backports/device/UIKitConstants-expectations.h`. The answers, as that run printed them:

    action.attributedImage.name: Links
    action.attributedImage.attributedString: Links
    action.attributedImage.keepsAttributes: keeps
    action.attributedImage.imageIsSame: same
    action.attributedImage.targetIsSame: same
    action.attributedImage.selector: description
    action.attributedImage.actionHandlerIsNil: nil
    action.attributedImage.attributedStringAfterNameSet: Renamed
    action.attributedImage.keepsAttributesAfterNameSet: drops
    action.attributedImageHandler.name: Links
    action.attributedImageHandler.attributedString: Links
    action.attributedImageHandler.keepsAttributes: keeps
    action.attributedImageHandler.imageIsSame: same
    action.attributedImageHandler.actionHandlerIsSet: set
    action.attributedImageHandler.targetIsNil: nil
    action.attributedImageHandler.selectorIsNull: null
    action.plainImageHandler.targetIsNil: nil
    action.plainImageHandler.selectorIsNull: null
    action.attributedOnly.imageIsNil: nil
    action.attributedOnly.actionHandlerIsNil: nil

Three of those are the reason this object is written the way it is. A handler form carries **no target and no selector** - the
`attributedImageHandler` answers agree with the `plainImageHandler` ones, so the port's two handler forms do not disagree about
what a handler carries, and `[self initWithAttributedName:target:nil selector:NULL]` is what the host's own shape asks for. The
11.0 form answers **no image**, so an image is exactly what the two 14.0 forms add and nothing else. And the plain name and the
attributed name are one name in two spellings: setting `name` moves the string across. The host drops the attributes when it does
(`keepsAttributesAfterNameSet: drops`), because its plain setter is one source of truth for both; the port keeps them, because
`UIAccessibilityCustomAction+AttributedName11.m` holds the style in an associated object that the class's own `setName:` does not
touch. That difference belongs to the 11.0 row and its object, and is left there.
