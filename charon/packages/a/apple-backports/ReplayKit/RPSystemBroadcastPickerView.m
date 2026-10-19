#import <ReplayKit/ReplayKit.h>

// The button that starts a system broadcast. The host's view holds a button with no title and an image view inside the button,
// and the port builds the same tree. Nothing the port draws comes from the choices set on it: a picker with no extension to
// start shows the button and nothing else, so the port keeps the two choices as the application set them.
@implementation RPSystemBroadcastPickerView {
    BOOL _showsMicrophoneButton;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        [self setUpPicker];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self setUpPicker];
    }
    return self;
}

- (void)setUpPicker
{
    _showsMicrophoneButton = YES;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = self.bounds;
    button.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [button addSubview:[[UIImageView alloc] initWithFrame:button.bounds]];
    [self addSubview:button];
}

@end
