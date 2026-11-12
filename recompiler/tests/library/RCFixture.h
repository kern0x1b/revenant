#import <Foundation/Foundation.h>

@interface RCFToken : NSObject
@property (nonatomic, copy, readonly) NSString *value;
- (instancetype)initWithValue:(NSString *)value;
@end

@interface RCFClient : NSObject
@property (nonatomic, readonly) NSInteger counter;
+ (RCFClient *)clientWithSiteKey:(NSString *)siteKey;
- (NSInteger)bump;
- (NSString *)siteKey;
- (NSObject *)hostBundle;
- (NSString *)bundleIdentifier;
- (RCFToken *)tokenForAction:(NSString *)action;
- (void)executeWithAction:(NSString *)action completion:(void (^)(RCFToken *token, NSError *error))completion;
- (NSUInteger)threadNumber;
@end
