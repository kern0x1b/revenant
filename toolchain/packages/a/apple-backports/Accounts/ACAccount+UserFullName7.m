#import <Foundation/Foundation.h>
#import <Accounts/ACAccount.h>

@interface ACAccount (CharonUserFullName)

@property (readonly, copy) NSString *userFullName;

@end

@implementation ACAccount (CharonUserFullName)

@dynamic userFullName;

- (NSString *)userFullName
{
    return nil;
}

@end
