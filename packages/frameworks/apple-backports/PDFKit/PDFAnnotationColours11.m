#import "RevenantPDFKit.h"

#import <UIKit/UIKit.h>
#import "RevenantPDFKitColours.h"

@implementation PDFAnnotation (PDFAnnotationColours)
@dynamic backgroundColor;
@dynamic interiorColor;
@dynamic fontColor;
@dynamic font;

static UIColor *revenant_annotation_colour(CGColorRef colour)
{
    if (colour == NULL)
        return nil;
    UIColor *answer = [UIColor colorWithCGColor:colour];
    CGColorRelease(colour);
    return answer;
}

- (UIColor *)backgroundColor
{
    return revenant_annotation_colour(revenant_annotation_background_colour([self revenant_CGPDFDictionary]));
}

- (UIColor *)interiorColor
{
    return revenant_annotation_colour(revenant_annotation_interior_colour([self revenant_CGPDFDictionary]));
}

- (UIColor *)fontColor
{
    return revenant_annotation_colour(revenant_annotation_font_colour([self revenant_CGPDFDictionary]));
}

- (UIFont *)font
{
    NSString *name = revenant_annotation_font_name([self revenant_CGPDFDictionary]);
    CGFloat size = revenant_annotation_font_size([self revenant_CGPDFDictionary]);
    UIFont *answer = [UIFont fontWithName:name size:size];
    return answer != nil ? answer : [UIFont fontWithName:REVENANT_ANNOTATION_FONT_DEFAULT_NAME
                                                    size:REVENANT_ANNOTATION_FONT_DEFAULT_SIZE];
}

@end
