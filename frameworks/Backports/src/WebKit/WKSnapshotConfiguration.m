#if defined(REVENANT_HOST_BUILD)
#define WKSnapshotConfiguration WKSnapshotConfigurationRevenant
#endif

#import <WebKit/WebKit.h>

@implementation WKSnapshotConfiguration {
    CGRect _rect;
    NSNumber *_snapshotWidth;
    BOOL _afterScreenUpdates;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _rect = CGRectNull;
        _afterScreenUpdates = YES;
    }
    return self;
}

- (CGRect)rect
{
    return _rect;
}

- (void)setRect:(CGRect)rect
{
    _rect = rect;
}

- (NSNumber *)snapshotWidth
{
    return _snapshotWidth;
}

- (void)setSnapshotWidth:(NSNumber *)snapshotWidth
{
    _snapshotWidth = [snapshotWidth copy];
}

- (BOOL)afterScreenUpdates
{
    return _afterScreenUpdates;
}

- (void)setAfterScreenUpdates:(BOOL)afterScreenUpdates
{
    _afterScreenUpdates = afterScreenUpdates;
}

- (id)copyWithZone:(NSZone *)zone
{
    WKSnapshotConfiguration *copy = [[[self class] allocWithZone:zone] init];
    copy->_rect = _rect;
    copy->_snapshotWidth = [_snapshotWidth copy];
    copy->_afterScreenUpdates = _afterScreenUpdates;
    return copy;
}

@end
