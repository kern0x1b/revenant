#import "RevenantContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNMutableGroup

@dynamic name;

- (void)setName:(NSString *)name
{
    [self revenant_setIdentifier:nil name:name];
}

@end
