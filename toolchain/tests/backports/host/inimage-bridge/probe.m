#import <objc/message.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Intents/Intents.h>
#import <IntentsUI/IntentsUI.h>

#ifdef PORT
#define BYTES_SELECTOR @"revenant_imageData"
#else
#define BYTES_SELECTOR @"imageData"
#endif

@interface ProbeResponse : NSObject
@end
@implementation ProbeResponse
@end

#ifdef PORT
static Class image_class(void) { return NSClassFromString(@"RevenantHostINImage"); }
#else
static Class image_class(void) { return NSClassFromString(@"INImage"); }
#endif

static BOOL loaded_from_system(Class c) {
    const char *image = class_getImageName(c);
    return image && strstr(image, "/Intents.framework/") != NULL;
}
static NSData *bytes_of(id image) {
    if (!image) return nil;
    return ((NSData * (*)(id, SEL))objc_msgSend)(image, NSSelectorFromString(BYTES_SELECTOR));
}

static CGImageRef red_image(void) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(10, 20), YES, 1);
    [[UIColor redColor] setFill];
    UIRectFill(CGRectMake(0, 0, 10, 20));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img.CGImage;
}

static void yes_no(const char *label, BOOL value) { printf("%s: %s\n", label, value ? "yes" : "no"); }

int main(void) {
    @autoreleasepool {
        Class c = image_class();
#ifdef PORT
        if (!c || loaded_from_system(c)) {
            printf("FAIL: the port build did not load the port's INImage\n");
            return 2;
        }
#else
        if (!c || !loaded_from_system(c)) {
            printf("FAIL: the host build did not load the system's INImage\n");
            return 2;
        }
#endif
        printf("INImage class: %s\n", c ? "yes" : "no");
        yes_no("responds imageWithUIImage:", [c respondsToSelector:NSSelectorFromString(@"imageWithUIImage:")]);
        yes_no("responds imageWithCGImage:", [c respondsToSelector:NSSelectorFromString(@"imageWithCGImage:")]);
        yes_no("responds imageSizeForIntentResponse:", [c respondsToSelector:NSSelectorFromString(@"imageSizeForIntentResponse:")]);
        yes_no("responds fetchUIImageWithCompletion:", [[c imageWithImageData:[NSData dataWithBytes:"x" length:1]] respondsToSelector:NSSelectorFromString(@"fetchUIImageWithCompletion:")]);

        SEL sizeSel = NSSelectorFromString(@"imageSizeForIntentResponse:");
        NSMethodSignature *sig = [c methodSignatureForSelector:sizeSel];
        id inputs[] = { nil, [NSObject new], [ProbeResponse new] };
        const char *names[] = { "nil", "NSObject", "ProbeResponse" };
        for (int i = 0; i < 3; i++) {
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setSelector:sizeSel]; [inv setTarget:c];
            id arg = inputs[i]; [inv setArgument:&arg atIndex:2];
            [inv invoke];
            CGSize size; [inv getReturnValue:&size];
            printf("imageSizeForIntentResponse(%s): %g x %g\n", names[i], size.width, size.height);
        }

        id nilUI = [c performSelector:NSSelectorFromString(@"imageWithUIImage:") withObject:nil];
        printf("imageWithUIImage:nil -> %s, bytes %s\n", nilUI ? "object" : "nil", bytes_of(nilUI) ? "present" : "nil");
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(10, 20), YES, 1);
        [[UIColor redColor] setFill];
        UIRectFill(CGRectMake(0, 0, 10, 20));
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        id fromUI = [c performSelector:NSSelectorFromString(@"imageWithUIImage:") withObject:img];
        NSData *png = UIImagePNGRepresentation(img);
        printf("imageWithUIImage:red -> bytes %lu, equal to its PNG: ", (unsigned long)bytes_of(fromUI).length);
        printf("%s\n", [bytes_of(fromUI) isEqualToData:png] ? "yes" : "no");

        id nilCG = [c performSelector:NSSelectorFromString(@"imageWithCGImage:") withObject:nil];
        printf("imageWithCGImage:nil -> %s, bytes %s\n", nilCG ? "object" : "nil", bytes_of(nilCG) ? "present" : "nil");
        CGImageRef cg = img.CGImage;
        id fromCG = [c performSelector:NSSelectorFromString(@"imageWithCGImage:") withObject:(__bridge id)cg];
        NSData *raw = (__bridge_transfer NSData *)CGDataProviderCopyData(CGImageGetDataProvider(cg));
        printf("imageWithCGImage:red -> bytes %lu, equal to the provider's raw bytes: ", (unsigned long)bytes_of(fromCG).length);
        printf("%s, equal to its PNG: %s\n", [bytes_of(fromCG) isEqualToData:raw] ? "yes" : "no", [bytes_of(fromCG) isEqualToData:png] ? "yes" : "no");

        NSArray *fetched = @[ fromUI, fromCG, nilUI ];
        const char *fetchNames[] = { "PNG-backed", "raw-backed", "nil-backed" };
        for (int i = 0; i < 3; i++) {
            __block UIImage *got = nil;
            __block BOOL ran = NO, onMain = NO;
            void (^done)(UIImage *) = ^(UIImage *i) { got = i; ran = YES; onMain = [NSThread isMainThread]; };
            ((void (*)(id, SEL, id))objc_msgSend)(fetched[i], NSSelectorFromString(@"fetchUIImageWithCompletion:"), done);
            printf("fetch %s: completion before return %s, image %s", fetchNames[i], ran ? "yes" : "no", got ? "yes" : "nil");
            if (got) printf(" %gx%g", got.size.width, got.size.height);
            printf(", main thread %s\n", onMain ? "yes" : "no");
        }
    }
    return 0;
}
