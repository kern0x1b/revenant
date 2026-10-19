#import <CoreData/CoreData.h>
#import "CharonAbstract.h"

@implementation NSPersistentHistoryToken

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_abstract(self, _cmd);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    charon_abstract(self, _cmd);
    return nil;
}

@end
