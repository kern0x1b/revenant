#import <Foundation/Foundation.h>
#import <Accounts/ACAccount.h>

// ACAccount of the release carries -identifier, -accountType and -username and no full name: the
// account store it reads has one kind of account, Sina Weibo, whose record holds a handle and a
// name and nothing that names the owner. The header itself says the property is there "for accounts
// that support it (currently only Facebook accounts)", and an account of the release does not, so
// the answer is the documented nil rather than a name made up (facts/Accounts/ACAccount.md).

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
