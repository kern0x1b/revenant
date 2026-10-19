#import "RevenantLists.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UICollectionViewCell (RevenantUpdateHandler15)

- (UICollectionViewCellConfigurationUpdateHandler)configurationUpdateHandler
{
    return revenant_host_update_handler(self);
}

- (void)setConfigurationUpdateHandler:(UICollectionViewCellConfigurationUpdateHandler)configurationUpdateHandler
{
    revenant_host_set_update_handler(self, configurationUpdateHandler);
}

@end

@implementation UITableViewCell (RevenantUpdateHandler15)

- (UITableViewCellConfigurationUpdateHandler)configurationUpdateHandler
{
    return revenant_host_update_handler(self);
}

- (void)setConfigurationUpdateHandler:(UITableViewCellConfigurationUpdateHandler)configurationUpdateHandler
{
    revenant_host_set_update_handler(self, configurationUpdateHandler);
}

@end

@implementation UITableViewHeaderFooterView (RevenantUpdateHandler15)

- (UITableViewHeaderFooterViewConfigurationUpdateHandler)configurationUpdateHandler
{
    return revenant_host_update_handler(self);
}

- (void)setConfigurationUpdateHandler:(UITableViewHeaderFooterViewConfigurationUpdateHandler)configurationUpdateHandler
{
    revenant_host_set_update_handler(self, configurationUpdateHandler);
}

@end
