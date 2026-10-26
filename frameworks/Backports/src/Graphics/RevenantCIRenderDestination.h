#import <CoreImage/CoreImage.h>

@interface CIRenderDestination (RevenantRender)

- (CIRenderTask *)revenant_renderImage:(CIImage *)image context:(CIContext *)context error:(NSError **)error;
- (CIRenderTask *)revenant_renderImage:(CIImage *)image fromRect:(CGRect)rect atPoint:(CGPoint)point context:(CIContext *)context error:(NSError **)error;
- (BOOL)revenant_prepareRenderWithError:(NSError **)error;

@end
