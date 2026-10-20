#import <ReplayKit/ReplayKit.h>

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
