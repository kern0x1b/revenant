// The HEIC representation of an image, iOS 17 (facts/UIKit/UIImageHEICRepresentation.md).
//
// One object carries one release: the symbol here is first exported by iOS 17.0, so every band
// from 17.0 on re-exports the release's own and the bands below keep this one.

#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>

NSData *UIImageHEICRepresentation(UIImage *image)
{
    // A real encode through the release's own ImageIO, and the release's own answer when it has no
    // HEIC encoder: the destination is created for the HEIC type by uniform type identifier, and
    // ImageIO returns NULL for a type it cannot write. Every release this object is kept for has
    // none - iOS 6 to 10.3.6, measured on the 6.1.3 cache: it exports ImageIO's
    // CGImageDestinationCopyTypeIdentifiers, so it can name every type it writes, and the strings
    // it holds are public.jpeg, public.png, public.tiff and com.compuserve.gif, with no occurrence
    // of public.heic, public.heif, kUTTypeHEIC, kUTTypeHEIF, com.apple.heic or image/heic
    // (facts/UIKit/UIImageHEICRepresentation.md). The header's contract is "nil if the image cannot
    // be represented in HEIC", and a release that cannot write HEIC cannot represent anything in it.
    CGImageRef core = image.CGImage;
    if (!core)
        return nil;
    NSMutableData *written = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)written, CFSTR("public.heic"), 1, NULL);
    if (!destination)
        return nil;
    CGImageDestinationAddImage(destination, core, NULL);
    BOOL finished = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    return finished ? written : nil;
}
