#import <UIKit/UIKit.h>

@implementation UIScreen (CharonNativeBounds)

- (CGRect)nativeBounds
{
    CGFloat scale = self.scale;
    CGSize size = self.bounds.size;
    return CGRectMake(0, 0, size.width * scale, size.height * scale);
}

- (CGFloat)nativeScale
{
    return self.scale;
}

@end
