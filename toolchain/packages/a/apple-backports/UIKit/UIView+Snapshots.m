#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface CharonSnapshotView : UIView
@end

@implementation CharonSnapshotView
@end

static void charon_draw(UIView *view, CGContextRef context, CGRect source, CGRect destination, CGFloat alpha)
{
    if (alpha <= 0 || CGRectIsEmpty(source) || CGRectIsEmpty(destination))
        return;
    CGContextSaveGState(context);
    CGContextSetAlpha(context, alpha);
    CGContextClipToRect(context, destination);
    CGContextTranslateCTM(context, destination.origin.x, destination.origin.y);
    CGContextScaleCTM(context, destination.size.width / source.size.width, destination.size.height / source.size.height);
    CGContextTranslateCTM(context, -source.origin.x, -source.origin.y);
    [view.layer renderInContext:context];
    CGContextRestoreGState(context);
}

static void charon_settle(UIView *view, BOOL afterUpdates)
{
    if (!afterUpdates)
        return;
    [view layoutIfNeeded];
    [CATransaction flush];
}

static void charon_axis(CGFloat position, CGFloat before, CGFloat after, CGFloat length, CGFloat *origin, CGFloat *extent)
{
    if (position == 0 && before == 0 && after == 0) {
        *origin = 0;
        *extent = 1;
        return;
    }
    CGFloat inner = length - before - after - 2;
    *origin = (position + before + 1) / length;
    *extent = inner / length;
    if (inner < 0.04) {
        *origin -= 0.02 / length;
        *extent = 0.04 / length;
    }
}

@implementation UIView (CharonSnapshots)

- (BOOL)drawViewHierarchyInRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context)
        return NO;
    if (CGRectIsEmpty(self.bounds))
        return YES;
    if (!self.window)
        return NO;
    charon_settle(self, afterUpdates);
    BOOL shown = YES;
    for (UIView *current = self; current; current = current.superview)
        shown = shown && !current.hidden;
    if (shown)
        charon_draw(self, context, self.bounds, rect, self.alpha);
    return YES;
}

- (UIView *)resizableSnapshotViewFromRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates withCapInsets:(UIEdgeInsets)capInsets
{
    CGSize size = CGRectIsNull(rect) ? CGSizeZero : CGSizeMake(MAX(0, rect.size.width), MAX(0, rect.size.height));
    CGPoint origin = rect.origin;
    CharonSnapshotView *snapshot = [[CharonSnapshotView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    snapshot.autoresizingMask = UIViewAutoresizingNone;
    CGFloat scale = [UIScreen mainScreen].scale;
    snapshot.layer.contentsScale = scale;
    snapshot.layer.contentsGravity = kCAGravityResize;
    if (capInsets.top != 0 || capInsets.left != 0 || capInsets.bottom != 0 || capInsets.right != 0) {
        CGFloat x, width, y, height;
        charon_axis(origin.x * scale, capInsets.left * scale, capInsets.right * scale, size.width * scale, &x, &width);
        charon_axis(origin.y * scale, capInsets.top * scale, capInsets.bottom * scale, size.height * scale, &y, &height);
        snapshot.layer.contentsCenter = CGRectMake(x, y, width, height);
    }
    if (size.width <= 0 || size.height <= 0)
        return snapshot;
    charon_settle(self, afterUpdates);
    UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    CGFloat alpha = self.hidden ? 0 : self.alpha;
    charon_draw(self, UIGraphicsGetCurrentContext(), rect, CGRectMake(0, 0, size.width, size.height), alpha);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    snapshot.layer.contents = (__bridge id)image.CGImage;
    return snapshot;
}

- (UIView *)snapshotViewAfterScreenUpdates:(BOOL)afterUpdates
{
    return [self resizableSnapshotViewFromRect:self.bounds afterScreenUpdates:afterUpdates withCapInsets:UIEdgeInsetsZero];
}

@end
