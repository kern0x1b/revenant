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
