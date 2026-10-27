#import <CoreImage/CoreImage.h>
#import "RevenantCIRenderDestination.h"

@implementation CIContext (RevenantRenderDestination)

- (CIRenderTask *)startTaskToRender:(CIImage *)image toDestination:(CIRenderDestination *)destination error:(NSError **)error
{
    return [destination revenant_renderImage:image context:self error:error];
}

- (CIRenderTask *)startTaskToRender:(CIImage *)image fromRect:(CGRect)rect toDestination:(CIRenderDestination *)destination atPoint:(CGPoint)point error:(NSError **)error
{
    return [destination revenant_renderImage:image fromRect:rect atPoint:point context:self error:error];
}

- (BOOL)prepareRender:(CIImage *)image fromRect:(CGRect)rect toDestination:(CIRenderDestination *)destination atPoint:(CGPoint)point error:(NSError **)error
{
    return [destination revenant_prepareRenderWithError:error];
}

@end
