#import "CharonPDFKit.h"

#import <UIKit/UIKit.h>
#import "CharonPDFKitColours.h"

@implementation PDFAnnotation (PDFAnnotationColours)
@dynamic backgroundColor;
@dynamic interiorColor;
@dynamic fontColor;
@dynamic font;

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
    NSString *name = charon_annotation_font_name([self charon_CGPDFDictionary]);
    CGFloat size = charon_annotation_font_size([self charon_CGPDFDictionary]);
    UIFont *answer = [UIFont fontWithName:name size:size];
    return answer != nil ? answer : [UIFont fontWithName:CHARON_ANNOTATION_FONT_DEFAULT_NAME
                                                    size:CHARON_ANNOTATION_FONT_DEFAULT_SIZE];
}

@end
