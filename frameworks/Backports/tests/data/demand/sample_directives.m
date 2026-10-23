#import <UIKit/UIKit.h>
#pragma mark - Scrubber Handle
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#warning Platform-specific code runs here
@interface Bar : UIView
- (void)copy:(id)sender;
@end
@implementation Bar
- (void)copy:(id)sender {
    [super copy:sender];
}
- (void)shade {
    [self.item.avAsset copy:nil];
}
@end
