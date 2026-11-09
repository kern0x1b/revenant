#import <UIKit/UIKit.h>
#import "RevenantVisionKit.h"
#import "check.h"

static void expect(BOOL ok, const char *name, NSString *seen)
{
    revenant_check(ok != revenant_negative, name, seen);
}

static NSData *swatch(size_t width, size_t height)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, (CGBitmapInfo)kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(space);
    CGContextSetRGBFillColor(context, 0.9, 0.8, 0.2, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGImageRef cg = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *image = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return UIImageJPEGRepresentation(image, 0.9);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        Class controllerClass = NSClassFromString(@"VNDocumentCameraViewController");
        Class scanClass = NSClassFromString(@"VNDocumentCameraScan");
        expect(controllerClass != Nil && scanClass != Nil, "the library defines the controller and the scan", @"");
        expect([controllerClass isSubclassOfClass:[UIViewController class]], "the controller is a view controller", @"");
        expect([VNDocumentCameraViewController isSupported], "a device with a camera is supported", @"");

        NSData *page = swatch(120, 80);
        expect(page.length > 0, "a page image was encoded", @"");
        VNDocumentCameraScan *scan = [[VNDocumentCameraScan alloc] initWithRevenantPages:@[ page, page ] title:@"Scan"];
        expect(scan.pageCount == 2, "the scan has its two pages", [NSString stringWithFormat:@"%lu", (unsigned long)scan.pageCount]);
        expect([scan.title isEqualToString:@"Scan"], "the scan has its title", scan.title);
        UIImage *image = [scan imageOfPageAtIndex:1];
        expect(image != nil && image.size.width == 120 && image.size.height == 80, "a page reads back at its size", NSStringFromCGSize(image.size));
        expect([scan imageOfPageAtIndex:2] == nil, "a page beyond the count is nil", @"");

        VNDocumentCameraViewController *controller = [[VNDocumentCameraViewController alloc] init];
        expect(controller != nil && controller.delegate == nil, "a new controller has no delegate", @"");
        expect(controller.modalPresentationStyle == UIModalPresentationFullScreen, "the controller presents full screen", @"");
    }
    return revenant_finish();
}
