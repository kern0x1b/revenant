#include "../revenant_impl.h"
#import "RevenantMenus.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

extern const UIMenuIdentifier BACKPORT_IMPL(UIMenuRoot);

typedef BOOL (^RevenantElementMatch)(UIMenuElement *element);
typedef NSArray<UIMenuElement *> *(^RevenantElementReplacement)(UIMenuElement *element);

static BOOL revenant_rewrite(NSArray<UIMenuElement *> *elements, RevenantElementMatch match, RevenantElementReplacement replacement, NSArray<UIMenuElement *> **result)
{
    NSMutableArray<UIMenuElement *> *rewritten = [NSMutableArray arrayWithCapacity:elements.count];
    BOOL changed = NO;
    for (UIMenuElement *element in elements) {
        if (!changed && match(element)) {
            [rewritten addObjectsFromArray:replacement(element)];
            changed = YES;
            continue;
        }
        if (!changed && [element isKindOfClass:[UIMenu class]]) {
            NSArray<UIMenuElement *> *inner = nil;
            if (revenant_rewrite([(UIMenu *)element children], match, replacement, &inner)) {
                [rewritten addObject:[(UIMenu *)element menuByReplacingChildren:inner]];
                changed = YES;
                continue;
            }
        }
        [rewritten addObject:element];
    }
    *result = rewritten;
    return changed;
}

static UIMenuElement *revenant_find(NSArray<UIMenuElement *> *elements, RevenantElementMatch match)
{
    for (UIMenuElement *element in elements) {
        if (match(element))
            return element;
        if ([element isKindOfClass:[UIMenu class]]) {
            UIMenuElement *inner = revenant_find([(UIMenu *)element children], match);
            if (inner)
                return inner;
        }
    }
    return nil;
}

static RevenantElementMatch revenant_menu_match(UIMenuIdentifier identifier)
{
    return ^BOOL(UIMenuElement *element) {
        return [element isKindOfClass:[UIMenu class]] && [[(UIMenu *)element identifier] isEqual:identifier];
    };
}

static RevenantElementMatch revenant_action_match(UIActionIdentifier identifier)
{
    return ^BOOL(UIMenuElement *element) {
        return [element isKindOfClass:[UIAction class]] && [[(UIAction *)element identifier] isEqual:identifier];
    };
}

static RevenantElementMatch revenant_command_match(SEL action, id propertyList)
{
    return ^BOOL(UIMenuElement *element) {
        if (![element isKindOfClass:[UICommand class]])
            return NO;
        UICommand *command = (UICommand *)element;
        return command.action == action && (command.propertyList == propertyList || [command.propertyList isEqual:propertyList]);
    };
}

@implementation RevenantMenuBuilder {
@private
    UIMenuSystem *_system;
    UIMenu *_root;
}

- (instancetype)initWithSystem:(UIMenuSystem *)system menus:(NSArray<UIMenuElement *> *)menus
{
    if ((self = [super init])) {
        _system = system;
        _root = [UIMenu menuWithTitle:@"" image:nil identifier:BACKPORT_IMPL(UIMenuRoot) options:0 children:menus ?: @[]];
    }
    return self;
}

- (UIMenuSystem *)system
{
    return _system;
}

- (UIMenu *)root
{
    return _root;
}

- (BOOL)revenant_rewrite:(RevenantElementMatch)match with:(RevenantElementReplacement)replacement
{
    NSArray<UIMenuElement *> *result = nil;
    if (!revenant_rewrite(_root.children, match, replacement, &result))
        return NO;
    _root = [_root menuByReplacingChildren:result];
    return YES;
}

- (void)revenant_insert:(NSArray<UIMenuElement *> *)elements before:(BOOL)before matching:(RevenantElementMatch)match
{
    [self revenant_rewrite:match with:^NSArray<UIMenuElement *> *(UIMenuElement *sibling) {
        return before ? [elements arrayByAddingObject:sibling] : [@[sibling] arrayByAddingObjectsFromArray:elements];
    }];
}

- (void)revenant_insert:(NSArray<UIMenuElement *> *)elements atStart:(BOOL)start ofMenu:(UIMenuIdentifier)identifier
{
    if ([[_root identifier] isEqual:identifier]) {
        NSArray<UIMenuElement *> *children = _root.children;
        _root = [_root menuByReplacingChildren:start ? [elements arrayByAddingObjectsFromArray:children] : [children arrayByAddingObjectsFromArray:elements]];
        return;
    }
    [self revenant_rewrite:revenant_menu_match(identifier) with:^NSArray<UIMenuElement *> *(UIMenuElement *parent) {
        NSArray<UIMenuElement *> *children = [(UIMenu *)parent children];
        return @[[(UIMenu *)parent menuByReplacingChildren:start ? [elements arrayByAddingObjectsFromArray:children] : [children arrayByAddingObjectsFromArray:elements]]];
    }];
}

- (UIMenu *)menuForIdentifier:(UIMenuIdentifier)identifier
{
    if ([[_root identifier] isEqual:identifier])
        return _root;
    return (UIMenu *)revenant_find(_root.children, revenant_menu_match(identifier));
}

- (UIAction *)actionForIdentifier:(UIActionIdentifier)identifier
{
    return (UIAction *)revenant_find(_root.children, revenant_action_match(identifier));
}

- (UICommand *)commandForAction:(SEL)action propertyList:(id)propertyList
{
    return (UICommand *)revenant_find(_root.children, revenant_command_match(action, propertyList));
}

- (void)replaceMenuForIdentifier:(UIMenuIdentifier)replacedIdentifier withMenu:(UIMenu *)replacementMenu
{
    [self replaceMenuForIdentifier:replacedIdentifier withElements:@[replacementMenu]];
}

- (void)replaceMenuForIdentifier:(UIMenuIdentifier)replacedIdentifier withElements:(NSArray<UIMenuElement *> *)replacementElements
{
    [self revenant_rewrite:revenant_menu_match(replacedIdentifier) with:^NSArray<UIMenuElement *> *(UIMenuElement *element) {
        return replacementElements;
    }];
}

- (void)replaceActionForIdentifier:(UIActionIdentifier)replacedIdentifier withElements:(NSArray<UIMenuElement *> *)replacementElements
{
    [self revenant_rewrite:revenant_action_match(replacedIdentifier) with:^NSArray<UIMenuElement *> *(UIMenuElement *element) {
        return replacementElements;
    }];
}

- (void)replaceCommandForAction:(SEL)replacedAction propertyList:(id)replacedPropertyList withElements:(NSArray<UIMenuElement *> *)replacementElements
{
    [self revenant_rewrite:revenant_command_match(replacedAction, replacedPropertyList) with:^NSArray<UIMenuElement *> *(UIMenuElement *element) {
        return replacementElements;
    }];
}

- (void)replaceChildrenOfMenuForIdentifier:(UIMenuIdentifier)parentIdentifier fromChildrenBlock:(NSArray<UIMenuElement *> *(NS_NOESCAPE ^)(NSArray<UIMenuElement *> *))childrenBlock
{
    if ([[_root identifier] isEqual:parentIdentifier]) {
        _root = [_root menuByReplacingChildren:childrenBlock(_root.children)];
        return;
    }
    [self revenant_rewrite:revenant_menu_match(parentIdentifier) with:^NSArray<UIMenuElement *> *(UIMenuElement *parent) {
        return @[[(UIMenu *)parent menuByReplacingChildren:childrenBlock([(UIMenu *)parent children])]];
    }];
}

- (void)insertSiblingMenu:(UIMenu *)siblingMenu beforeMenuForIdentifier:(UIMenuIdentifier)siblingIdentifier
{
    [self revenant_insert:@[siblingMenu] before:YES matching:revenant_menu_match(siblingIdentifier)];
}

- (void)insertSiblingMenu:(UIMenu *)siblingMenu afterMenuForIdentifier:(UIMenuIdentifier)siblingIdentifier
{
    [self revenant_insert:@[siblingMenu] before:NO matching:revenant_menu_match(siblingIdentifier)];
}

- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements beforeMenuForIdentifier:(UIMenuIdentifier)siblingIdentifier
{
    [self revenant_insert:insertedElements before:YES matching:revenant_menu_match(siblingIdentifier)];
}

- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements afterMenuForIdentifier:(UIMenuIdentifier)siblingIdentifier
{
    [self revenant_insert:insertedElements before:NO matching:revenant_menu_match(siblingIdentifier)];
}

- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements beforeActionForIdentifier:(UIActionIdentifier)siblingIdentifier
{
    [self revenant_insert:insertedElements before:YES matching:revenant_action_match(siblingIdentifier)];
}

- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements afterActionForIdentifier:(UIActionIdentifier)siblingIdentifier
{
    [self revenant_insert:insertedElements before:NO matching:revenant_action_match(siblingIdentifier)];
}

- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements beforeCommandForAction:(SEL)siblingAction propertyList:(id)siblingPropertyList
{
    [self revenant_insert:insertedElements before:YES matching:revenant_command_match(siblingAction, siblingPropertyList)];
}

- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements afterCommandForAction:(SEL)siblingAction propertyList:(id)siblingPropertyList
{
    [self revenant_insert:insertedElements before:NO matching:revenant_command_match(siblingAction, siblingPropertyList)];
}

- (void)insertChildMenu:(UIMenu *)childMenu atStartOfMenuForIdentifier:(UIMenuIdentifier)parentIdentifier
{
    [self revenant_insert:@[childMenu] atStart:YES ofMenu:parentIdentifier];
}

- (void)insertChildMenu:(UIMenu *)childMenu atEndOfMenuForIdentifier:(UIMenuIdentifier)parentIdentifier
{
    [self revenant_insert:@[childMenu] atStart:NO ofMenu:parentIdentifier];
}

- (void)insertElements:(NSArray<UIMenuElement *> *)childElements atStartOfMenuForIdentifier:(UIMenuIdentifier)parentIdentifier
{
    [self revenant_insert:childElements atStart:YES ofMenu:parentIdentifier];
}

- (void)insertElements:(NSArray<UIMenuElement *> *)childElements atEndOfMenuForIdentifier:(UIMenuIdentifier)parentIdentifier
{
    [self revenant_insert:childElements atStart:NO ofMenu:parentIdentifier];
}

- (void)removeMenuForIdentifier:(UIMenuIdentifier)removedIdentifier
{
    [self replaceMenuForIdentifier:removedIdentifier withElements:@[]];
}

- (void)removeActionForIdentifier:(UIActionIdentifier)removedIdentifier
{
    [self replaceActionForIdentifier:removedIdentifier withElements:@[]];
}

- (void)removeCommandForAction:(SEL)removedAction propertyList:(id)removedPropertyList
{
    [self replaceCommandForAction:removedAction propertyList:removedPropertyList withElements:@[]];
}

@end
