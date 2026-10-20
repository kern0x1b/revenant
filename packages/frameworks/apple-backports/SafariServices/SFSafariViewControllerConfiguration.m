#import <SafariServices/SafariServices.h>

@implementation SFSafariViewControllerConfiguration

- (instancetype)init
{
    self = [super init];
    if (self)
        _barCollapsingEnabled = YES;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    SFSafariViewControllerConfiguration *copy = [[[self class] allocWithZone:zone] init];
    copy.entersReaderIfAvailable = _entersReaderIfAvailable;
    copy.barCollapsingEnabled = _barCollapsingEnabled;
    copy.activityButton = _activityButton;
    copy.eventAttribution = _eventAttribution;
    return copy;
}

- (void)setActivityButton:(SFSafariViewControllerActivityButton *)activityButton
{
    _activityButton = [activityButton copy];
}

- (void)setEventAttribution:(UIEventAttribution *)eventAttribution
{
    _eventAttribution = [(id)eventAttribution copy];
}

@end
