#import "../Foundation/check.h"
#import <CoreText/CoreText.h>

CFArrayRef revenant_CTFontManagerCreateFontDescriptorsFromURL(CFURLRef url);

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 12.0, NULL);
    NSURL *url = font ? (__bridge_transfer NSURL *)CTFontCopyAttribute(font, kCTFontURLAttribute) : nil;
    if (font) {
        CFRelease(font);
    }
    CFArrayRef descriptors = url ? revenant_CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url) : NULL;
    NSArray *list = (__bridge NSArray *)descriptors;
    revenant_check(list.count == 1 && !revenant_negative, "the file of a font gives one descriptor, for its first font",
                   [NSString stringWithFormat:@"%lu descriptors", (unsigned long)list.count]);
    NSString *name = list.count == 1 ? (__bridge_transfer NSString *)CTFontDescriptorCopyAttribute((__bridge CTFontDescriptorRef)list[0], kCTFontNameAttribute) : nil;
    revenant_check(name.length > 0 && !revenant_negative, "the descriptor names its font", @"no font name");
    if (descriptors) {
        CFRelease(descriptors);
    }
    CFArrayRef missing = revenant_CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)[NSURL fileURLWithPath:@"/nonexistent/revenant-missing.ttf"]);
    revenant_check(missing == NULL && !revenant_negative, "a missing file gives no descriptors", @"descriptors for a missing file");
    if (missing) {
        CFRelease(missing);
    }
    return revenant_finish();
}
