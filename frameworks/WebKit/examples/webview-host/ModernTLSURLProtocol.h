#import <Foundation/Foundation.h>

@interface ModernTLSURLProtocol : NSURLProtocol
+ (BOOL)install;

+ (void)setShellCacheFirstEnabled:(BOOL)enabled forHosts:(NSArray *)hosts;
+ (BOOL)shellCacheFirstEnabled;

+ (void)declareShellURLs:(NSArray *)urls;

+ (void)precacheURLs:(NSArray *)urls;
@end
