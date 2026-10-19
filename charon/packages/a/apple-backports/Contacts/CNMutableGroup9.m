#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation CNMutableGroup

@dynamic name;

- (void)setName:(NSString *)name
{
    [self charon_setIdentifier:nil name:name];
}

@end
