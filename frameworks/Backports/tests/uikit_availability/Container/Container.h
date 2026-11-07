#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContainerNode : NSObject
@end

@interface ContainerNode (AccessibilityInternal)
- (NSArray *)accessibilityElements;
@end

NS_ASSUME_NONNULL_END
