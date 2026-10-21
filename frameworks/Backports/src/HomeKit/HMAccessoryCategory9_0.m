#import "RevenantHomeKitInternal.h"

@implementation HMAccessoryCategory

@synthesize revenant_categoryType = _revenant_categoryType;

- (instancetype)init
{
    self = [super init];
    return self;
}

- (NSString *)categoryType
{
    return [self.revenant_categoryType copy];
}

@end

HMAccessoryCategory *RevenantHomeKitAccessoryCategory(NSString *categoryType)
{
    HMAccessoryCategory *category = [HMAccessoryCategory alloc];
    category.revenant_categoryType = categoryType;
    return category;
}
