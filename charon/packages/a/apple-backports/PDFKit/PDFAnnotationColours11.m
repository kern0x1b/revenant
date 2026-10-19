#import "CharonPDFKit.h"

// PDFAnnotation's three colours and its font: four members, and each is ONE LINE over a derivation that
// lives in CharonPDFKitColours.h.
//
// WHY THE DERIVATION IS IN THE HEADER.  All four members return UIColor or UIFont, which are the classes
// the 26.2 header calls PDFKitPlatformColor and PDFKitPlatformFont, and there is no Foundation class for
// either on iOS - so this is the only object of the port that imports UIKit, and it is the only object
// the harness's Catalyst side links.  That is not the whole reason the derivation is out of here, though.
// The reason is measured: the Catalyst binary loads the platform's own PDFKit at run time, and a CATEGORY
// in a later image replaces one in an earlier, so the platform's PDFAnnotationUtilities answers these four
// SELECTORS there and a differential written against the selectors would compare Apple's PDFKit with
// Apple's PDFKit.  CharonPDFKitColours.h therefore holds the derivation as `static inline` functions over
// the annotation's CGPDFDictionary, which the harness calls DIRECTLY - no selector dispatch anywhere in
// the path, so nothing a later image loads can take it over, and each side wraps the CGColorRef in its own
// platform's colour class.  The header's own comment carries the measurement and the sentinel that shows
// it is the category and not this port.
//
// Nothing is memoised: a colour is a value of no identity and a font of none either, and the host builds a
// fresh one per call too.  What each member does is release the colour it was handed, which is the
// +1 CGColorRef the seam returns.
#import <UIKit/UIKit.h>
#import "CharonPDFKitColours.h"

@implementation PDFAnnotation (PDFAnnotationColours)
// All four are COMPUTED from the annotation dictionary on every call, so @dynamic says "not an ivar" and
// nothing else.
@dynamic backgroundColor;
@dynamic interiorColor;
@dynamic fontColor;
@dynamic font;

// A CGColorRef the seam hands over, as a UIColor, or nil when the seam found no colour.  Written once
// because all three colour members are this line with a different seam call, and three copies of a
// retain/release pair is three places for the release to be forgotten.
static UIColor *charon_annotation_colour(CGColorRef colour)
{
    if (colour == NULL)
        return nil;
    UIColor *answer = [UIColor colorWithCGColor:colour];
    CGColorRelease(colour);
    return answer;
}

- (UIColor *)backgroundColor
{
    return charon_annotation_colour(charon_annotation_background_colour([self charon_CGPDFDictionary]));
}

- (UIColor *)interiorColor
{
    return charon_annotation_colour(charon_annotation_interior_colour([self charon_CGPDFDictionary]));
}

- (UIColor *)fontColor
{
    return charon_annotation_colour(charon_annotation_font_colour([self charon_CGPDFDictionary]));
}

- (UIFont *)font
{
    // The name and the size are SEPARATE seam calls on purpose: they are read from the /DA independently,
    // which is what the fixtures measure - a name is no reason to lose a size, and font-unknown answers
    // Helvetica at 9 rather than at the default.
    NSString *name = charon_annotation_font_name([self charon_CGPDFDictionary]);
    CGFloat size = charon_annotation_font_size([self charon_CGPDFDictionary]);
    UIFont *answer = [UIFont fontWithName:name size:size];
    // charon_annotation_font_name never answers a name the platform lacks, because clause 1 tried it and
    // clause 3 is Helvetica - so this is unreachable and is here so that a member cannot answer nil where
    // the host answers an object.  Say so rather than pretend it is a rule.
    return answer != nil ? answer : [UIFont fontWithName:CHARON_ANNOTATION_FONT_DEFAULT_NAME
                                                    size:CHARON_ANNOTATION_FONT_DEFAULT_SIZE];
}

@end
