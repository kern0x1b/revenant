#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

CG_EXTERN size_t CGBitmapGetAlignedBytesPerRow(size_t bytesPerRow);
CG_EXTERN CGBlendMode CGContextGetBlendMode(CGContextRef context);
CG_EXTERN CGFloat CGContextGetLineWidth(CGContextRef context);

@interface UIGraphicsRendererFormat (CharonRenderer)
- (void)_setBounds:(CGRect)bounds;
@end

@interface UIGraphicsRenderer (CharonRenderer)
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
