#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface SCDict : NSMutableDictionary
@end

@interface SCFixture : NSObject
+ (NSArray *)run;
@end
