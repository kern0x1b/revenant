#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

CG_EXTERN size_t CGBitmapGetAlignedBytesPerRow(size_t bytesPerRow);
CG_EXTERN CGBlendMode CGContextGetBlendMode(CGContextRef context);
CG_EXTERN CGFloat CGContextGetLineWidth(CGContextRef context);

@interface UIGraphicsRendererFormat (CharonRenderer)
- (void)_setBounds:(CGRect)bounds;
@end

@interface UIGraphicsRenderer (CharonRenderer)
// The release's own variant, which takes the format to draw with: a renderer that writes somewhere
// names the destination on that format and runs the drawing through this one, so the copy the
// renderer keeps is the one that carries it. The two context members are what a subclass pushes and
// pops with, and what it calls back into around its own page bookkeeping.
- (BOOL)runDrawingActions:(NS_NOESCAPE UIGraphicsDrawingActions)drawingActions
         completionActions:(NS_NOESCAPE UIGraphicsDrawingActions)completionActions
                    format:(UIGraphicsRendererFormat *)format
                     error:(NSError **)error;
- (void)pushContext:(UIGraphicsRendererContext *)context;
- (void)popContext:(UIGraphicsRendererContext *)context;
@end

@interface UIGraphicsRendererContext (CharonRenderer)
- (instancetype)initWithCGContext:(CGContextRef)context format:(UIGraphicsRendererFormat *)format;
@property (nonatomic) BOOL __createsImages;
@end

@interface UIGraphicsImageRendererFormat (CharonRenderer)
- (CGFloat)_contextScale;
@end
