#import <CoreImage/CoreImage.h>

@interface CIRenderDestination (RevenantRender)

- (CIRenderTask *)revenant_renderImage:(CIImage *)image context:(CIContext *)context error:(NSError **)error;

@end
