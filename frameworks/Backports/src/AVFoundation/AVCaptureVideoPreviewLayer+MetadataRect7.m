#import <AVFoundation/AVFoundation.h>

@implementation AVCaptureVideoPreviewLayer (RevenantMetadataRect)

- (CGRect)metadataOutputRectOfInterestForRect:(CGRect)rect
{
    return CGRectMake(0, 0, 1, 1);
}

@end
