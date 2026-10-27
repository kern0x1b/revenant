#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface RevenantMetadataObjectsFilter : NSObject <AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, weak) AVCaptureMetadataOutput *output;
@property (nonatomic, weak) id<AVCaptureMetadataOutputObjectsDelegate> target;
@end

typedef void (*SetMetadataDelegateIMP)(id, SEL, id, dispatch_queue_t);
static SetMetadataDelegateIMP native_set_metadata_delegate;

static const void *RectOfInterestKey = &RectOfInterestKey;

static CGRect revenant_rect_of_interest(AVCaptureMetadataOutput *output)
{
    NSValue *stored = objc_getAssociatedObject(output, RectOfInterestKey);
    return stored ? stored.CGRectValue : CGRectMake(0, 0, 1, 1);
}

@implementation RevenantMetadataObjectsFilter

@synthesize output = _output;
@synthesize target = _target;

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    id<AVCaptureMetadataOutputObjectsDelegate> target = self.target;
    if (![target respondsToSelector:@selector(captureOutput:didOutputMetadataObjects:fromConnection:)])
        return;
    CGRect rectOfInterest = self.output ? revenant_rect_of_interest(self.output) : CGRectMake(0, 0, 1, 1);
    NSMutableArray *kept = [NSMutableArray array];
    for (AVMetadataObject *object in metadataObjects)
        if (CGRectIntersectsRect(rectOfInterest, object.bounds))
            [kept addObject:object];
    if (kept.count || !metadataObjects.count)
        [target captureOutput:captureOutput didOutputMetadataObjects:kept fromConnection:connection];
}

@end

static void revenant_set_metadata_delegate(AVCaptureMetadataOutput *self, SEL selector, id<AVCaptureMetadataOutputObjectsDelegate> delegate, dispatch_queue_t queue)
{
    RevenantMetadataObjectsFilter *filter = nil;
    if (delegate) {
        filter = [[RevenantMetadataObjectsFilter alloc] init];
        filter.output = self;
        filter.target = delegate;
    }
    objc_setAssociatedObject(self, (__bridge const void *)[RevenantMetadataObjectsFilter class], filter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    native_set_metadata_delegate(self, selector, filter, queue);
}

@interface RevenantMetadataOutputInstall : NSObject
@end

@implementation RevenantMetadataOutputInstall

+ (void)load
{
    Method method = class_getInstanceMethod([AVCaptureMetadataOutput class], @selector(setMetadataObjectsDelegate:queue:));
    if (!method)
        return;
    native_set_metadata_delegate = (SetMetadataDelegateIMP)method_getImplementation(method);
    method_setImplementation(method, (IMP)revenant_set_metadata_delegate);
}

@end

@implementation AVCaptureMetadataOutput (RevenantRectOfInterest)

- (CGRect)rectOfInterest
{
    return revenant_rect_of_interest(self);
}

- (void)setRectOfInterest:(CGRect)rectOfInterest
{
    objc_setAssociatedObject(self, RectOfInterestKey, [NSValue valueWithCGRect:rectOfInterest], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id<AVCaptureMetadataOutputObjectsDelegate>)metadataObjectsDelegate
{
    return [(RevenantMetadataObjectsFilter *)objc_getAssociatedObject(self, (__bridge const void *)[RevenantMetadataObjectsFilter class]) target];
}

@end
