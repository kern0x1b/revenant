#import "RevenantMenus.h"

@implementation UIContextMenuConfiguration {
@private
    id<NSCopying> _identifier;
    UIContextMenuContentPreviewProvider _previewProvider;
    UIContextMenuActionProvider _actionProvider;
    NSSet<NSString *> *_secondaryItemIdentifiers;
    NSInteger _badgeCount;
    UIContextMenuConfigurationElementOrder _preferredMenuElementOrder;
}

+ (instancetype)configurationWithIdentifier:(id<NSCopying>)identifier previewProvider:(UIContextMenuContentPreviewProvider)previewProvider
                             actionProvider:(UIContextMenuActionProvider)actionProvider
{
    UIContextMenuConfiguration *configuration = [[self alloc] init];
    if (identifier)
        configuration->_identifier = [(id)identifier copy];
    configuration->_previewProvider = [previewProvider copy];
    configuration->_actionProvider = [actionProvider copy];
    return configuration;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _identifier = [NSUUID UUID];
        _badgeCount = NSIntegerMax;
    }
    return self;
}

- (NSSet<NSString *> *)secondaryItemIdentifiers
{
    return _secondaryItemIdentifiers;
}

- (void)setSecondaryItemIdentifiers:(NSSet<NSString *> *)secondaryItemIdentifiers
{
    _secondaryItemIdentifiers = [secondaryItemIdentifiers copy];
}

- (NSInteger)badgeCount
{
    return _badgeCount;
}

- (void)setBadgeCount:(NSInteger)badgeCount
{
    _badgeCount = badgeCount;
}

- (UIContextMenuConfigurationElementOrder)preferredMenuElementOrder
{
    return _preferredMenuElementOrder;
}

- (void)setPreferredMenuElementOrder:(UIContextMenuConfigurationElementOrder)preferredMenuElementOrder
{
    _preferredMenuElementOrder = preferredMenuElementOrder;
}

- (id<NSCopying>)identifier
{
    return _identifier;
}

- (UIContextMenuActionProvider)revenant_actionProvider
{
    return _actionProvider;
}

@end
