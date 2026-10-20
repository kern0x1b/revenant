#import <CoreData/CoreData.h>
#import "RevenantAbstract.h"

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
    revenant_abstract(self, _cmd);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    revenant_abstract(self, _cmd);
    return nil;
}

@end
