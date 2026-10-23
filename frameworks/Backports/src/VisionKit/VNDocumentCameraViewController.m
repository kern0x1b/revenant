#import <VisionKit/VisionKit.h>

@implementation VNDocumentCameraViewController

+ (BOOL)isSupported
{
    return NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (![[self class] isSupported]) {
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:nil];
        [self.delegate documentCameraViewController:self didFailWithError:error];
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}

@end
