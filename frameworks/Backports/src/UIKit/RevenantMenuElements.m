#import "RevenantMenuElements.h"

BOOL revenant_menu_leaf(UIMenuElement *element)
{
    return [element isKindOfClass:[UIAction class]] || [element isKindOfClass:[UICommand class]];
}

UIMenuElementAttributes revenant_menu_attributes(UIMenuElement *element)
{
    return [element isKindOfClass:[UIAction class]] ? ((UIAction *)element).attributes : ((UICommand *)element).attributes;
}

UIMenuElementState revenant_menu_state(UIMenuElement *element)
{
    return [element isKindOfClass:[UIAction class]] ? ((UIAction *)element).state : ((UICommand *)element).state;
}

void revenant_menu_collect_deferred(NSArray *elements, NSMutableArray *found)
{
    for (UIMenuElement *element in elements) {
        if ([element isKindOfClass:[UIDeferredMenuElement class]])
            [found addObject:element];
        else if ([element isKindOfClass:[UIMenu class]] && (((UIMenu *)element).options & UIMenuOptionsDisplayInline))
            revenant_menu_collect_deferred(((UIMenu *)element).children, found);
    }
}

BOOL revenant_menu_has_content(UIMenu *menu, NSDictionary *resolved)
{
    for (UIMenuElement *child in menu.children) {
        if (revenant_menu_leaf(child)) {
            if (!(revenant_menu_attributes(child) & (UIMenuElementAttributesDisabled | UIMenuElementAttributesHidden)))
                return YES;
        } else if ([child isKindOfClass:[UIMenu class]]) {
            if (revenant_menu_has_content((UIMenu *)child, resolved))
                return YES;
        } else if ([child isKindOfClass:[UIDeferredMenuElement class]]) {
            if ([resolved[child] count])
                return YES;
        }
    }
    return NO;
}

void revenant_menu_flatten(NSArray *elements, NSDictionary *resolved, NSMutableArray *out)
{
    for (UIMenuElement *element in elements) {
        if (revenant_menu_leaf(element)) {
            if (!(revenant_menu_attributes(element) & (UIMenuElementAttributesDisabled | UIMenuElementAttributesHidden)))
                [out addObject:element];
        } else if ([element isKindOfClass:[UIMenu class]]) {
            UIMenu *menu = (UIMenu *)element;
            if (menu.options & UIMenuOptionsDisplayInline)
                revenant_menu_flatten(menu.children, resolved, out);
            else if (revenant_menu_has_content(menu, resolved))
                [out addObject:menu];
        } else if ([element isKindOfClass:[UIDeferredMenuElement class]]) {
            NSArray *items = resolved[element];
            NSMutableArray *plain = [NSMutableArray array];
            for (UIMenuElement *item in items) {
                if (![item isKindOfClass:[UIDeferredMenuElement class]])
                    [plain addObject:item];
            }
            revenant_menu_flatten(plain, resolved, out);
        }
    }
}

NSString *revenant_menu_button_title(UIMenuElement *element)
{
    NSString *title = element.title;
    if (!title.length && [element isKindOfClass:[UIAction class]])
        title = ((UIAction *)element).discoverabilityTitle;
    if (!title.length)
        return nil;
    if ([element isKindOfClass:[UIMenu class]])
        return [title stringByAppendingString:@" ›"];
    UIMenuElementState state = revenant_menu_state(element);
    if (state == UIMenuElementStateOn)
        return [@"✓ " stringByAppendingString:title];
    if (state == UIMenuElementStateMixed)
        return [@"– " stringByAppendingString:title];
    return title;
}

BOOL revenant_menu_destructive(UIMenuElement *element)
{
    if ([element isKindOfClass:[UIMenu class]])
        return (((UIMenu *)element).options & UIMenuOptionsDestructive) != 0;
    return (revenant_menu_attributes(element) & UIMenuElementAttributesDestructive) != 0;
}
