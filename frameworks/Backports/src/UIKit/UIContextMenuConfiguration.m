#import "RevenantMenus.h"

@implementation UIContextMenuConfiguration {
@private
    id<NSCopying> _identifier;
    UIContextMenuActionProvider _actionProvider;
}

+ (instancetype)configurationWithIdentifier:(id<NSCopying>)identifier previewProvider:(UIContextMenuContentPreviewProvider)previewProvider
                             actionProvider:(UIContextMenuActionProvider)actionProvider
{
    UIContextMenuConfiguration *configuration = [[self alloc] init];
    if (identifier)
        configuration->_identifier = [(id)identifier copy];
    configuration->_actionProvider = [actionProvider copy];
    return configuration;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _identifier = [NSUUID UUID];
    }
    return self;
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
