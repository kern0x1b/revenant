#import "CharonLists.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation UICollectionViewCell (CharonUpdateHandler15)

- (UICollectionViewCellConfigurationUpdateHandler)configurationUpdateHandler
{
    return charon_host_update_handler(self);
}

- (void)setConfigurationUpdateHandler:(UICollectionViewCellConfigurationUpdateHandler)configurationUpdateHandler
{
    charon_host_set_update_handler(self, configurationUpdateHandler);
}

@end

@implementation UITableViewCell (CharonUpdateHandler15)

- (UITableViewCellConfigurationUpdateHandler)configurationUpdateHandler
{
    return charon_host_update_handler(self);
}

- (void)setConfigurationUpdateHandler:(UITableViewCellConfigurationUpdateHandler)configurationUpdateHandler
{
    charon_host_set_update_handler(self, configurationUpdateHandler);
}

@end

@implementation UITableViewHeaderFooterView (CharonUpdateHandler15)

- (UITableViewHeaderFooterViewConfigurationUpdateHandler)configurationUpdateHandler
{
    return charon_host_update_handler(self);
}

- (void)setConfigurationUpdateHandler:(UITableViewHeaderFooterViewConfigurationUpdateHandler)configurationUpdateHandler
{
    charon_host_set_update_handler(self, configurationUpdateHandler);
}

@end
