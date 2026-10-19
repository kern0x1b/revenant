#import <Foundation/Foundation.h>
#import <Accounts/ACAccountType.h>

// iOS 6.1.3 carries the Sina Weibo and the Facebook account types and no Tencent Weibo one, so
// +[ACAccountStore accountTypeWithIdentifier:] answers nil for the identifier below and an
// application that stores the identifier in its own settings still loads. Both texts are the ones
// Accounts itself gives them, read from the arm64e shared cache of iOS 18.0 next to the Sina Weibo
// identifier as the control (facts/Accounts/Names.md).

NSString *const ACAccountTypeIdentifierTencentWeibo = @"com.apple.account.tencentweibo";
NSString *const ACTencentWeiboAppIdKey = @"ACTencentWeiboAppIdKey";
