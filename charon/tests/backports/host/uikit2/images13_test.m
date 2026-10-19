#import "images13_scenario.h"

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        ur_img_port_mode = YES;
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
        ur_agree(@"image members", images_scenario(make_bundle(), NSClassFromString(@"CharonHostUIImageSymbolConfiguration"), NSClassFromString(@"CharonHostUIImageConfiguration")), [expected componentsSeparatedByString:@"\n"]);
        UIImage *check = ur_img0([UIImage class], "checkmarkImage");
        charon_check(check == ur_img0([UIImage class], "checkmarkImage") && check.renderingMode == UIImageRenderingModeAlwaysTemplate && CGSizeEqualToSize(check.size, CGSizeMake(20, 20)), "a system image is one template image of 20 points", @"it is not");
        for (UIImage *glyph in @[ur_img0([UIImage class], "checkmarkImage"), ur_img0([UIImage class], "strokedCheckmarkImage"), ur_img0([UIImage class], "addImage"), ur_img0([UIImage class], "removeImage"), ur_img0([UIImage class], "actionsImage")]) {
            NSString *pixels = pixels_of(glyph);
            charon_check([[pixels componentsSeparatedByString:@" "].lastObject integerValue] > 0, "a system image draws something", pixels);
        }
    }
}
