#import <Foundation/Foundation.h>
#import <Accounts/ACAccount.h>

@interface ACAccount (RevenantUserFullName)

@property (readonly, copy) NSString *userFullName;

@end

@implementation ACAccount (RevenantUserFullName)

@dynamic userFullName;

- (NSString *)userFullName
{
    return nil;
}

@end
