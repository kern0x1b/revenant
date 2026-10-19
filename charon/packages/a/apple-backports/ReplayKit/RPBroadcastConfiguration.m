#import <ReplayKit/ReplayKit.h>

// The configuration of the clips a broadcast makes. A fresh one has no clip duration (0.0) and no compression properties,
// which is what the host gives. It is secure coding and nothing more: the host has no NSCopying, and a copy crashes there, so
// the port has none either (facts/ReplayKit/RPBroadcastConfiguration.md).
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
