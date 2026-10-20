#import <ReplayKit/ReplayKit.h>

@implementation RPBroadcastConfiguration

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _clipDuration = [coder decodeDoubleForKey:@"clipDuration"];
        NSSet *classes = [NSSet setWithObjects:[NSDictionary class], [NSString class], [NSNumber class], nil];
        _videoCompressionProperties = [coder decodeObjectOfClasses:classes forKey:@"videoCompressionProperties"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_clipDuration forKey:@"clipDuration"];
    [coder encodeObject:_videoCompressionProperties forKey:@"videoCompressionProperties"];
}

@end
