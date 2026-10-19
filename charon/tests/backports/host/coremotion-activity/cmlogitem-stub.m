// The superclass of CMMotionActivity for the port's side of the differential only. CMLogItem is the release's own class,
// and it cannot be linked on this side: its image would carry CMMotionActivity too, and the two would be one class in one
// process. This stub answers for the things the port's subclass calls on it - the timestamp, and the copy
// and coding of that timestamp - and nothing else. It is not part of the library and is not shipped.
#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>

@implementation CMLogItem {
    NSTimeInterval _timestamp;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (NSTimeInterval)timestamp
{
    return _timestamp;
}

- (id)copyWithZone:(NSZone *)zone
{
    CMLogItem *copy = [[[self class] allocWithZone:zone] init];
    copy->_timestamp = _timestamp;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init]))
        _timestamp = [coder decodeDoubleForKey:@"timestamp"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_timestamp forKey:@"timestamp"];
}

@end
