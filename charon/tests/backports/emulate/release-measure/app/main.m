// The 6.1.3 release's own answers, read at run time. Nothing here names a class the release may lack at link time: each class
// is looked up by name, each selector is asked of the class, and each conversion step is called through objc_msgSend, so a
// missing class or selector is a measured answer, not a failed load.
#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <stdio.h>

static void Info(NSString *name, NSString *detail)
{
    printf("info %s %s\n", name.UTF8String, detail.UTF8String);
    fflush(stdout);
}

// The name of the exception the block raises, or nil when it returns.
static NSString *RaisedBy(void (^block)(void))
{
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception.name;
    }
}

static void SelectorMeasurements(void)
{
    Class device = NSClassFromString(@"AVCaptureDevice");
    Info(@"class-AVCaptureDevice", device ? @"present" : @"absent");
    if (!device)
        return;
    NSArray<NSString *> *selectors = @[@"setExposureDuration:", @"exposureDuration", @"setExposureGain:", @"exposureGain",
                                       @"setExposureMode:", @"exposureMode", @"setManualExposureSupportEnabled:",
                                       @"isManualExposureSupportEnabled", @"setAutoExposureBias:", @"autoExposureBias",
                                       @"setExposureTargetBias:completionHandler:", @"setExposureTargetBias:",
                                       @"setExposureModeCustomWithDuration:ISO:completionHandler:", @"deviceType",
                                       @"lockForConfiguration:"];
    for (NSString *name in selectors) {
        SEL sel = NSSelectorFromString(name);
        if (![device instancesRespondToSelector:sel]) {
            Info(name, @"instances no");
            continue;
        }
        NSMethodSignature *signature = [device instanceMethodSignatureForSelector:sel];
        NSMutableString *args = [NSMutableString string];
        for (NSUInteger i = 2; i < signature.numberOfArguments; i++)
            [args appendFormat:@" %s", [signature getArgumentTypeAtIndex:i]];
        Info(name, [NSString stringWithFormat:@"instances yes returns %s args%@", signature.methodReturnType, args]);
    }
    Info(@"class-AVCapturePhotoOutput", NSClassFromString(@"AVCapturePhotoOutput") ? @"present" : @"absent");
    Info(@"class-AVCapturePhotoBracketSettings", NSClassFromString(@"AVCapturePhotoBracketSettings") ? @"present" : @"absent");
    Info(@"class-AVCaptureStillImageOutput", NSClassFromString(@"AVCaptureStillImageOutput") ? @"present" : @"absent");
}

// Why the CoreImage conversion of a BGRA buffer fails on this release: each step is measured, by class lookup and message send.
static void CoreImageMeasurements(void)
{
    Class ciImage = NSClassFromString(@"CIImage"), ciContext = NSClassFromString(@"CIContext");
    Info(@"class-CIImage", ciImage ? @"present" : @"absent");
    Info(@"class-CIContext", ciContext ? @"present" : @"absent");
    if (!ciImage || !ciContext)
        return;
    CVPixelBufferRef pixels = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA, NULL, &pixels);
    Info(@"coreimage-pixel-buffer", pixels ? @"made" : [NSString stringWithFormat:@"nil status %d", (int)status]);
    SEL imageSel = NSSelectorFromString(@"imageWithCVPixelBuffer:");
    SEL contextSel = NSSelectorFromString(@"contextWithOptions:");
    Info(@"coreimage-image-selector", [ciImage respondsToSelector:imageSel] ? @"responds" : @"no");
    Info(@"coreimage-context-selector", [ciContext respondsToSelector:contextSel] ? @"responds" : @"no");
    __block id image = nil;
    NSString *raised = RaisedBy(^{
        if ([ciImage respondsToSelector:imageSel])
            image = ((id (*)(id, SEL, CVPixelBufferRef))objc_msgSend)(ciImage, imageSel, pixels);
    });
    Info(@"coreimage-image", raised ? [NSString stringWithFormat:@"raised %@", raised] : (image ? @"made" : @"nil"));
    __block id context = nil;
    raised = RaisedBy(^{
        if ([ciContext respondsToSelector:contextSel])
            context = ((id (*)(id, SEL, id))objc_msgSend)(ciContext, contextSel, nil);
    });
    Info(@"coreimage-context", raised ? [NSString stringWithFormat:@"raised %@", raised] : (context ? @"made" : @"nil"));
    if (image && context) {
        SEL createSel = NSSelectorFromString(@"createCGImage:fromRect:");
        __block CGImageRef converted = NULL;
        raised = RaisedBy(^{
            if ([context respondsToSelector:createSel]) {
                // The buffer's own extent: the 64 by 48 buffer made above (a CIImage of a pixel buffer is the buffer's rect).
                CGRect extent = CGRectMake(0, 0, 64, 48);
                converted = ((CGImageRef (*)(id, SEL, id, CGRect))objc_msgSend)(context, createSel, image, extent);
            }
        });
        Info(@"coreimage-cgimage", raised ? [NSString stringWithFormat:@"raised %@", raised] : (converted ? @"made" : @"nil"));
        if (converted)
            CGImageRelease(converted);
    } else {
        Info(@"coreimage-cgimage", @"not attempted: no image or no context");
    }
    // Why the buffer's image is nil: the same selector on an IOSurface-backed buffer, and on a CGImage source.
    CVPixelBufferRef surfaced = NULL;
    NSDictionary *attributes = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{}};
    status = CVPixelBufferCreate(kCFAllocatorDefault, 64, 48, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)attributes, &surfaced);
    __block id surfacedImage = nil;
    raised = RaisedBy(^{
        if (surfaced && [ciImage respondsToSelector:imageSel])
            surfacedImage = ((id (*)(id, SEL, CVPixelBufferRef))objc_msgSend)(ciImage, imageSel, surfaced);
    });
    Info(@"coreimage-image-iosurface", raised ? [NSString stringWithFormat:@"raised %@", raised]
                                              : (surfaced ? (surfacedImage ? @"made" : @"nil") : [NSString stringWithFormat:@"buffer nil status %d", (int)status]));
    if (surfacedImage && context) {
        SEL createSel = NSSelectorFromString(@"createCGImage:fromRect:");
        __block CGImageRef surfacedConverted = NULL;
        raised = RaisedBy(^{
            if ([context respondsToSelector:createSel]) {
                CGRect extent = CGRectMake(0, 0, 64, 48);
                surfacedConverted = ((CGImageRef (*)(id, SEL, id, CGRect))objc_msgSend)(context, createSel, surfacedImage, extent);
            }
        });
        Info(@"coreimage-cgimage-iosurface", raised ? [NSString stringWithFormat:@"raised %@", raised]
                                                    : (surfacedConverted ? [NSString stringWithFormat:@"made %zux%zu", CGImageGetWidth(surfacedConverted), CGImageGetHeight(surfacedConverted)] : @"nil"));
        if (surfacedConverted)
            CGImageRelease(surfacedConverted);
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(NULL, 64, 48, 8, 0, space, kCGImageAlphaPremultipliedFirst);
    CGImageRef source = bitmap ? CGBitmapContextCreateImage(bitmap) : NULL;
    __block id sourceImage = nil;
    SEL imageCGSel = NSSelectorFromString(@"imageWithCGImage:");
    raised = RaisedBy(^{
        if (source && [ciImage respondsToSelector:imageCGSel])
            sourceImage = ((id (*)(id, SEL, CGImageRef))objc_msgSend)(ciImage, imageCGSel, source);
    });
    Info(@"coreimage-image-cgimage-source", raised ? [NSString stringWithFormat:@"raised %@", raised]
                                                   : (source ? (sourceImage ? @"made" : @"nil") : @"source nil"));
    if (source) CGImageRelease(source);
    if (bitmap) CGContextRelease(bitmap);
    CGColorSpaceRelease(space);
    if (surfaced)
        CVPixelBufferRelease(surfaced);
    if (pixels)
        CVPixelBufferRelease(pixels);
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        SelectorMeasurements();
        CoreImageMeasurements();
        printf("measure done\n");
        fflush(stdout);
    }
    return 0;
}
