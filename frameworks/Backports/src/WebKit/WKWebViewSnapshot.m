#import "RevenantWebKit.h"

@implementation WKWebView (RevenantSnapshot)

- (void)takeSnapshotWithConfiguration:(WKSnapshotConfiguration *)snapshotConfiguration completionHandler:(void (^)(UIImage *, NSError *))completionHandler
{
    CGRect rect = snapshotConfiguration && !CGRectIsNull(snapshotConfiguration.rect) ? snapshotConfiguration.rect : self.bounds;
    CGSize size = rect.size;
    CGFloat contextScale = 1;
    NSNumber *width = snapshotConfiguration.snapshotWidth;
    if (width && size.width > 0) {
        contextScale = width.doubleValue / size.width;
        size = CGSizeMake(width.doubleValue, size.height * contextScale);
    }
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, contextScale, contextScale);
    CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);
    [self.layer renderInContext:context];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(image, nil);
    });
}

@end
