#import <Foundation/Foundation.h>

@protocol RCSNamed <NSObject>
- (NSString *)rcsName;
@property (nonatomic, readonly) NSInteger rcsValue;
@end

@interface RCSThing : NSObject <RCSNamed>
@end
