#import <CoreImage/CoreImage.h>
#import "RevenantCIRenderDestination.h"

@implementation CIContext (RevenantRenderDestination)

- (CIRenderTask *)startTaskToRender:(CIImage *)image toDestination:(CIRenderDestination *)destination error:(NSError **)error
{
    return [destination revenant_renderImage:image context:self error:error];
}

@end
