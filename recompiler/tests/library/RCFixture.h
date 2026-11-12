#import <Foundation/Foundation.h>

@interface RCFToken : NSObject
@property (nonatomic, readonly) NSInteger value;
- (instancetype)initWithValue:(NSInteger)value;
@end

@interface RCFClient : NSObject
+ (RCFClient *)clientWithSeed:(NSInteger)seed;
- (NSInteger)bump;
- (NSInteger)seed;
- (NSInteger)describedLength;
- (NSObject *)hostBundle;
- (RCFToken *)tokenForAction:(NSInteger)action;
- (void)executeWithAction:(NSInteger)action completion:(void (^)(RCFToken *token, NSError *error))completion;
- (NSUInteger)threadNumber;
@end
