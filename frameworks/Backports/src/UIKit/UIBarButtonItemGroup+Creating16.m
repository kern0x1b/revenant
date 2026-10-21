#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantGroupKindKey;
static const char RevenantGroupIdentifierKey;
static const char RevenantGroupDefaultKey;
static const char RevenantItemMenuKey;
static const char RevenantItemOrderKey;
static const char RevenantButtonOrderKey;

static UIBarButtonItemGroup *revenant_group(NSInteger kind, NSString *identifier, BOOL inDefault, UIBarButtonItem *representative, NSArray<UIBarButtonItem *> *items)
{
    UIBarButtonItemGroup *group = [[UIBarButtonItemGroup alloc] initWithBarButtonItems:items representativeItem:representative];
    objc_setAssociatedObject(group, &RevenantGroupKindKey, @(kind), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(group, &RevenantGroupIdentifierKey, [identifier copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(group, &RevenantGroupDefaultKey, @(inDefault), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return group;
}

@implementation UIBarButtonItemGroup (RevenantCreating16)

+ (UIBarButtonItemGroup *)fixedGroupWithRepresentativeItem:(UIBarButtonItem *)representativeItem items:(NSArray<UIBarButtonItem *> *)items
{
    return revenant_group(0, nil, YES, representativeItem, items);
}

+ (UIBarButtonItemGroup *)movableGroupWithCustomizationIdentifier:(NSString *)customizationIdentifier representativeItem:(UIBarButtonItem *)representativeItem items:(NSArray<UIBarButtonItem *> *)items
{
    return revenant_group(1, customizationIdentifier, YES, representativeItem, items);
}

+ (UIBarButtonItemGroup *)optionalGroupWithCustomizationIdentifier:(NSString *)customizationIdentifier inDefaultCustomization:(BOOL)inDefaultCustomization representativeItem:(UIBarButtonItem *)representativeItem items:(NSArray<UIBarButtonItem *> *)items
{
    return revenant_group(2, customizationIdentifier, inDefaultCustomization, representativeItem, items);
}

@end

@implementation UIBarButtonItem (RevenantGroups16)

- (UIBarButtonItemGroup *)creatingFixedGroup
{
    return [UIBarButtonItemGroup fixedGroupWithRepresentativeItem:nil items:@[self]];
}

- (UIBarButtonItemGroup *)creatingMovableGroupWithCustomizationIdentifier:(NSString *)customizationIdentifier
{
    return [UIBarButtonItemGroup movableGroupWithCustomizationIdentifier:customizationIdentifier representativeItem:nil items:@[self]];
}

- (UIBarButtonItemGroup *)creatingOptionalGroupWithCustomizationIdentifier:(NSString *)customizationIdentifier inDefaultCustomization:(BOOL)inDefaultCustomization
{
    return [UIBarButtonItemGroup optionalGroupWithCustomizationIdentifier:customizationIdentifier inDefaultCustomization:inDefaultCustomization representativeItem:nil items:@[self]];
}

- (UIMenuElement *)menuRepresentation
{
    return objc_getAssociatedObject(self, &RevenantItemMenuKey);
}

- (void)setMenuRepresentation:(UIMenuElement *)menuRepresentation
{
    objc_setAssociatedObject(self, &RevenantItemMenuKey, menuRepresentation, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (UIContextMenuConfigurationElementOrder)preferredMenuElementOrder
{
    return (UIContextMenuConfigurationElementOrder)[objc_getAssociatedObject(self, &RevenantItemOrderKey) integerValue];
}

- (void)setPreferredMenuElementOrder:(UIContextMenuConfigurationElementOrder)preferredMenuElementOrder
{
    objc_setAssociatedObject(self, &RevenantItemOrderKey, @(preferredMenuElementOrder), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIButton (RevenantMenuOrder16)

- (UIContextMenuConfigurationElementOrder)preferredMenuElementOrder
{
    return (UIContextMenuConfigurationElementOrder)[objc_getAssociatedObject(self, &RevenantButtonOrderKey) integerValue];
}

- (void)setPreferredMenuElementOrder:(UIContextMenuConfigurationElementOrder)preferredMenuElementOrder
{
    objc_setAssociatedObject(self, &RevenantButtonOrderKey, @(preferredMenuElementOrder), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
