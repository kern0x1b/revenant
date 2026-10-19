#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

static NSString *image_of(const void *address)
{
    Dl_info info;
    return dladdr(address, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static NSString *raises(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return exception.name;
    }
    return nil;
}

static NSData *archived(id object)
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    archiver.requiresSecureCoding = YES;
    [archiver encodeObject:object forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    return data;
}

static id unarchived(NSData *data, Class root)
{
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    unarchiver.requiresSecureCoding = YES;
    id object = [unarchiver decodeObjectOfClass:root forKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    return object;
}

static NSString *stripped(id object)
{
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    NSString *text = [NSString stringWithFormat:@"%@", object];
    return [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
}

@interface Recipient : NSObject <UIContextMenuInteractionDelegate>
@end

@implementation Recipient

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location
{
    return nil;
}

@end

int main(void)
{
    @autoreleasepool {
        NSArray *classes = @[@"UIMenuElement", @"UIAction", @"UIMenu", @"UIDeferredMenuElement", @"UIMenuSystem", @"UIContextMenuConfiguration", @"UIContextMenuInteraction",
                             @"UIPreviewParameters", @"UIPreviewTarget", @"UITargetedPreview"];
        for (NSString *name in classes) {
            Class cls = NSClassFromString(name);
            CHECK(cls != Nil, NAMED(@"%@ is there", name));
            if (cls)
                CHECK_EQUAL(image_of((__bridge const void *)cls), @"libUIKitBackports.dylib", NAMED(@"%@ comes from the backports library", name));
        }
        CHECK([UIAction superclass] == [UIMenuElement class] && [UIMenu superclass] == [UIMenuElement class] && [UIDeferredMenuElement superclass] == [UIMenuElement class],
              "the three kinds of element descend from UIMenuElement");

        NSArray *identifiers = @[
            @[@"UIMenuApplication", @"com.apple.menu.application"],
            @[@"UIMenuFile", @"com.apple.menu.file"],
            @[@"UIMenuEdit", @"com.apple.menu.edit"],
            @[@"UIMenuView", @"com.apple.menu.view"],
            @[@"UIMenuWindow", @"com.apple.menu.window"],
            @[@"UIMenuHelp", @"com.apple.menu.help"],
            @[@"UIMenuAbout", @"com.apple.menu.about"],
            @[@"UIMenuPreferences", @"com.apple.menu.preferences"],
            @[@"UIMenuServices", @"com.apple.menu.services"],
            @[@"UIMenuHide", @"com.apple.menu.hide"],
            @[@"UIMenuQuit", @"com.apple.menu.quit"],
            @[@"UIMenuNewScene", @"com.apple.menu.new-item"],
            @[@"UIMenuClose", @"com.apple.menu.close"],
            @[@"UIMenuPrint", @"com.apple.menu.print"],
            @[@"UIMenuUndoRedo", @"com.apple.menu.undo-redo"],
            @[@"UIMenuStandardEdit", @"com.apple.menu.standard-edit"],
            @[@"UIMenuFind", @"com.apple.menu.find"],
            @[@"UIMenuReplace", @"com.apple.menu.replace"],
            @[@"UIMenuShare", @"com.apple.menu.share"],
            @[@"UIMenuTextStyle", @"com.apple.menu.text-style"],
            @[@"UIMenuSpelling", @"com.apple.menu.spelling"],
            @[@"UIMenuSpellingPanel", @"com.apple.menu.spelling-panel"],
            @[@"UIMenuSpellingOptions", @"com.apple.menu.spelling-options"],
            @[@"UIMenuSubstitutions", @"com.apple.menu.substitutions"],
            @[@"UIMenuSubstitutionsPanel", @"com.apple.menu.substitutions-panel"],
            @[@"UIMenuSubstitutionOptions", @"com.apple.menu.substitution-options"],
            @[@"UIMenuTransformations", @"com.apple.menu.transformations"],
            @[@"UIMenuSpeech", @"com.apple.command.speech"],
            @[@"UIMenuLookup", @"com.apple.menu.lookup"],
            @[@"UIMenuLearn", @"com.apple.menu.learn"],
            @[@"UIMenuFormat", @"com.apple.menu.format"],
            @[@"UIMenuFont", @"com.apple.menu.font"],
            @[@"UIMenuTextSize", @"com.apple.menu.text-size"],
            @[@"UIMenuTextColor", @"com.apple.menu.text-color"],
            @[@"UIMenuTextStylePasteboard", @"com.apple.menu.text-style-pasteboard"],
            @[@"UIMenuText", @"com.apple.menu.text"],
            @[@"UIMenuWritingDirection", @"com.apple.menu.writing-direction"],
            @[@"UIMenuAlignment", @"com.apple.menu.alignment"],
            @[@"UIMenuToolbar", @"com.apple.menu.toolbar"],
            @[@"UIMenuFullscreen", @"com.apple.menu.fullscreen"],
            @[@"UIMenuMinimizeAndZoom", @"com.apple.menu.minimize-and-zoom"],
            @[@"UIMenuBringAllToFront", @"com.apple.menu.bring-all-to-front"],
            @[@"UIMenuRoot", @"com.apple.menu.root"],
            @[@"UIMenuOpenRecent", @"com.apple.menu.open-recent"],
            @[@"UIMenuOpen", @"com.apple.menu.open"]
        ];
        BOOL values = YES, carried = YES;
        for (NSArray *pair in identifiers) {
            void *symbol = dlsym(RTLD_DEFAULT, [pair[0] UTF8String]);
            NSString *value = symbol ? *(__unsafe_unretained NSString **)symbol : nil;
            values = values && [value isEqual:pair[1]];
            carried = carried && [image_of(symbol) isEqual:@"libUIKitBackports.dylib"];
        }
        CHECK(identifiers.count == 45, "the table holds 45 menu identifiers");
        CHECK(values, "the 45 menu identifiers have the strings read off the host");
        CHECK(carried, "and come from the backports library");

        UIAction *plain = [UIAction actionWithTitle:@"T" image:nil identifier:nil handler:^(UIAction *action) {}];
        CHECK_EQUAL(stripped(plain), @"<UIAction: PTR; title = T>", "an action prints its title");
        CHECK([plain.identifier hasPrefix:@"com.apple.action.dynamic."] && plain.attributes == 0 && plain.state == UIMenuElementStateOff && plain.image == nil && plain.discoverabilityTitle == nil,
              "and has a generated identifier and the default attributes and state");
        UIAction *bare = [UIAction actionWithHandler:^(UIAction *action) {}];
        CHECK([bare.title isEqualToString:@""] && bare.sender == nil, "an action made from a handler has an empty title and no sender");
        UIAction *set = [UIAction actionWithTitle:@"S" image:nil identifier:@"com.x" handler:^(UIAction *action) {}];
        set.attributes = UIMenuElementAttributesDisabled | UIMenuElementAttributesDestructive;
        set.state = UIMenuElementStateOn;
        set.discoverabilityTitle = @"D";
        CHECK_EQUAL(stripped(set), @"<UIAction: PTR; title = S; attributes = (Disabled|Destructive)>", "an action prints its attributes");
        UIAction *copy = [set copy];
        CHECK(copy != set && [copy isEqual:set] && copy.state == UIMenuElementStateOn && copy.attributes == set.attributes && [copy.discoverabilityTitle isEqualToString:@"D"],
              "a copy of an action is another action that is equal and has the same fields");
        UIAction *sameId = [UIAction actionWithTitle:@"Other" image:nil identifier:@"com.x" handler:nil];
        CHECK([sameId isEqual:set] && sameId.hash == set.hash && ![plain isEqual:set], "actions are equal by identifier");
        UIAction *decoded = unarchived(archived(set), [UIAction class]);
        CHECK([decoded.title isEqualToString:@"S"] && [decoded.identifier isEqualToString:@"com.x"] && decoded.attributes == set.attributes && decoded.state == UIMenuElementStateOn
                  && [decoded.discoverabilityTitle isEqualToString:@"D"],
              "an action is archived with secure coding and comes back with its fields");

        UIMenu *inner = [UIMenu menuWithTitle:@"Inner" image:nil identifier:@"com.inner" options:UIMenuOptionsDisplayInline children:@[plain]];
        UIMenu *menu = [UIMenu menuWithTitle:@"M" image:nil identifier:@"com.m" options:UIMenuOptionsDisplayInline | UIMenuOptionsDestructive children:@[set, inner]];
        CHECK_EQUAL(stripped(menu), @"<UIMenu: PTR; title = M; identifier = com.m; options = (Inline|Destructive); children = <NSArray: PTR>>",
                    "a menu prints its title, identifier, options and children");
        CHECK(menu.children.count == 2 && [[UIMenu menuWithChildren:@[set]].title isEqualToString:@""] && [[UIMenu menuWithTitle:@"a" children:@[]].identifier hasPrefix:@"com.apple.menu.dynamic."],
              "a menu keeps its children, and one made without a title or identifier has an empty title and a generated identifier");
        UIMenu *deep = [menu copy];
        CHECK(deep != menu && [deep isEqual:menu] && deep.children[0] != set && [deep.children[0] isEqual:set], "a copy of a menu copies its children");
        CHECK([menu menuByReplacingChildren:@[plain]].children.count == 1 && [[menu menuByReplacingChildren:@[plain]] isEqual:menu] && [menu menuByReplacingChildren:nil].children.count == 2,
              "replacing the children keeps the rest, and nil replaces nothing");
        UIMenu *roundtrip = unarchived(archived(menu), [UIMenu class]);
        CHECK([roundtrip isEqual:menu] && roundtrip.options == menu.options && roundtrip.children.count == 2 && [roundtrip.children[1] isKindOfClass:[UIMenu class]],
              "a menu is archived with secure coding and comes back with its children");
        CHECK_EQUAL(raises(^{ [UIMenu menuWithTitle:@"a" children:@[@"x"]]; }), NSInvalidArgumentException, "a child that is not an element is refused");

        UIDeferredMenuElement *deferred = [UIDeferredMenuElement elementWithProvider:^(void (^completion)(NSArray *elements)) { completion(@[]); }];
        CHECK([deferred copy] == deferred && ![deferred isEqual:[UIDeferredMenuElement elementWithProvider:nil]] && deferred.title.length > 0,
              "a deferred element has a title, copies to itself and equals only itself");

        CHECK([UIMenuSystem mainSystem] == [UIMenuSystem mainSystem] && [UIMenuSystem mainSystem] != [UIMenuSystem contextSystem], "there are two shared menu systems");

        UIContextMenuConfiguration *generated = [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:nil];
        UIContextMenuConfiguration *named = [UIContextMenuConfiguration configurationWithIdentifier:@"x" previewProvider:nil actionProvider:nil];
        CHECK([(id)generated.identifier isKindOfClass:[NSUUID class]] && [(id)named.identifier isEqual:@"x"]
                  && ![named isEqual:[UIContextMenuConfiguration configurationWithIdentifier:@"x" previewProvider:nil actionProvider:nil]],
              "a configuration has a generated identifier or the one it is given, and equals only itself");

        Recipient *recipient = [[Recipient alloc] init];
        UIContextMenuInteraction *interaction = [[UIContextMenuInteraction alloc] initWithDelegate:recipient];
        CGPoint location = [interaction locationInView:nil];
        __block int called = 0;
        [interaction updateVisibleMenuWithBlock:^UIMenu *(UIMenu *visible) {
            called++;
            return visible;
        }];
        [interaction dismissMenu];
        CHECK(interaction.delegate == recipient && interaction.view == nil && location.x == CGFLOAT_MAX && location.y == CGFLOAT_MAX && called == 0,
              "an interaction at rest has its delegate, no view and no location, and calls no block");
        CHECK(interaction.menuAppearance == UIContextMenuInteractionAppearanceCompact, "its menu is compact: iOS 6 draws no preview");

        UIPreviewParameters *parameters = [[UIPreviewParameters alloc] init];
        CHECK(parameters.backgroundColor != nil && parameters.visiblePath == nil && parameters.shadowPath == nil, "preview parameters have a background and no paths at first");
        parameters.backgroundColor = [UIColor redColor];
        parameters.backgroundColor = nil;
        CHECK(parameters.backgroundColor != nil, "and a nil background is the default again");
        parameters.visiblePath = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 5, 5)];
        parameters.shadowPath = [UIBezierPath bezierPathWithRect:CGRectMake(1, 1, 5, 5)];
        UIPreviewParameters *parametersCopy = [parameters copy];
        CHECK(parametersCopy != parameters && parametersCopy.visiblePath != parameters.visiblePath && CGRectEqualToRect(parametersCopy.shadowPath.bounds, CGRectMake(1, 1, 5, 5)),
              "a copy has copies of the paths");
        UIPreviewParameters *text = [[UIPreviewParameters alloc] initWithTextLineRects:@[[NSValue valueWithCGRect:CGRectMake(0, 0, 10, 10)]]];
        CHECK(CGRectEqualToRect(text.visiblePath.bounds, CGRectMake(-14, -10, 38, 30)), "the path of a line of text is its rectangle made larger by 14 and 10");
        CHECK([[UIPreviewParameters alloc] initWithTextLineRects:@[]].visiblePath == nil, "and there is none for no lines");

        CHECK([UIMenuController instancesRespondToSelector:@selector(showMenuFromView:rect:)] && [UIMenuController instancesRespondToSelector:@selector(hideMenuFromView:)]
                  && [UIMenuController instancesRespondToSelector:@selector(hideMenu)],
              "the menu controller shows and hides from a view");
        CHECK([UIAction instancesRespondToSelector:@selector(sender)] && [UIMenu respondsToSelector:@selector(menuWithChildren:)] && [UIAction respondsToSelector:@selector(actionWithHandler:)]
                  && [UIContextMenuInteraction instancesRespondToSelector:@selector(updateVisibleMenuWithBlock:)] && [UIPreviewParameters instancesRespondToSelector:@selector(shadowPath)],
              "the members of iOS 14 are there");
        CHECK([UIMenuElement instancesRespondToSelector:@selector(subtitle)] && [UIMenu instancesRespondToSelector:@selector(preferredElementSize)]
                  && [UIMenu instancesRespondToSelector:@selector(selectedElements)],
              "the members of iOS 15 and 16 that the menus carry are there");
        CHECK(![UIDeferredMenuElement respondsToSelector:@selector(elementWithUncachedProvider:)]
                  && ![UIContextMenuConfiguration instancesRespondToSelector:@selector(badgeCount)],
              "and the members of later releases are not");

        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}
