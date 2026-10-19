#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *CharonButtonGroupKey = &CharonButtonGroupKey;

@interface CharonWeakGroup : NSObject
@property (nonatomic, weak) UIBarButtonItemGroup *group;
@end

@implementation CharonWeakGroup
@synthesize group = _group;
@end

@implementation UIBarButtonItem (CharonButtonGroup)

- (UIBarButtonItemGroup *)buttonGroup
{
    return [(CharonWeakGroup *)objc_getAssociatedObject(self, CharonButtonGroupKey) group];
}

- (void)charon_setButtonGroup:(UIBarButtonItemGroup *)group
{
    CharonWeakGroup *box = [[CharonWeakGroup alloc] init];
    box.group = group;
    objc_setAssociatedObject(self, CharonButtonGroupKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIBarButtonItemGroup {
    NSArray<UIBarButtonItem *> *_barButtonItems;
    UIBarButtonItem *_representativeItem;
    BOOL _alwaysAvailable;
    UIMenuElement *_menuRepresentation;
    BOOL _hidden;
}

- (BOOL)alwaysAvailable
{
    return _alwaysAvailable;
}

- (void)setAlwaysAvailable:(BOOL)alwaysAvailable
{
    _alwaysAvailable = alwaysAvailable;
}

- (UIMenuElement *)menuRepresentation
{
    return _menuRepresentation;
}

- (void)setMenuRepresentation:(UIMenuElement *)menuRepresentation
{
    _menuRepresentation = [menuRepresentation copy];
}

- (BOOL)isHidden
{
    return _hidden;
}

- (void)setHidden:(BOOL)hidden
{
    _hidden = hidden;
}

- (instancetype)initWithBarButtonItems:(NSArray<UIBarButtonItem *> *)barButtonItems representativeItem:(UIBarButtonItem *)representativeItem
{
    self = [super init];
    if (self) {
        _representativeItem = representativeItem;
        [self setBarButtonItems:barButtonItems];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithBarButtonItems:[coder decodeObjectForKey:@"UIBarButtonItemGroupItems"] ?: @[] representativeItem:[coder decodeObjectForKey:@"UIBarButtonItemGroupRepresentativeItem"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_barButtonItems forKey:@"UIBarButtonItemGroupItems"];
    [coder encodeObject:_representativeItem forKey:@"UIBarButtonItemGroupRepresentativeItem"];
}

- (NSArray<UIBarButtonItem *> *)barButtonItems
{
    return _barButtonItems;
}

- (void)setBarButtonItems:(NSArray<UIBarButtonItem *> *)items
{
    _barButtonItems = [items copy];
    for (UIBarButtonItem *item in _barButtonItems)
        [item charon_setButtonGroup:self];
}

- (UIBarButtonItem *)representativeItem
{
    return _representativeItem;
}

- (void)setRepresentativeItem:(UIBarButtonItem *)item
{
    _representativeItem = item;
}

- (BOOL)isDisplayingRepresentativeItem
{
    return NO;
}

@end
