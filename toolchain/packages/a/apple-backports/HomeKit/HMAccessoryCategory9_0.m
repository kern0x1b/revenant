#import "CharonHomeKitInternal.h"

@implementation HMAccessoryCategory

@synthesize charon_categoryType = _charon_categoryType;

- (instancetype)init
{
    self = [super init];
    return self;
}

- (NSString *)categoryType
{
    return [self.charon_categoryType copy];
}

@end

HMAccessoryCategory *CharonHomeKitAccessoryCategory(NSString *categoryType)
{
    HMAccessoryCategory *category = [[HMAccessoryCategory alloc] init];
    category.charon_categoryType = categoryType;
    return category;
}
