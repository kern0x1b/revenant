#import "RevenantMPS.h"


const MTLRegion MPSRectNoClip = {{0, 0, 0}, {-1, -1, -1}};
BOOL MPSSupportsMTLDevice(id<MTLDevice> device)
{
    return device != nil;
}

@implementation MPSKernel {
    id<MTLDevice> _device;
    MPSKernelOptions _options;
    NSString *_label;
}

@synthesize label;

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    if ((self = [super init])) {
        _device = device;
        _options = MPSKernelOptionsNone;
    }
    return self;
}

- (id<MTLDevice>)device
{
    return _device;
}

- (MPSKernelOptions)options
{
    return _options;
}

- (void)setOptions:(MPSKernelOptions)options
{
    _options = options;
}

- (NSString *)label
{
    return _label;
}

- (void)setLabel:(NSString *)name
{
    _label = [name copy];
}

- (instancetype)copyWithZone:(NSZone *)zone device:(id<MTLDevice>)device
{
    MPSKernel *copy = [[[self class] allocWithZone:zone] initWithDevice:device ? device : _device];
    copy->_options = _options;
    copy->_label = _label;
    return copy;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self copyWithZone:zone device:nil];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithCoder:aDecoder device:MTLCreateSystemDefaultDevice()];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder device:(id<MTLDevice>)device
{
    if ((self = [super init])) {
        _device = device;
        _options = MPSKernelOptionsNone;
        NSString *name = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"label"];
        if (name)
            _label = [name copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_label)
        [aCoder encodeObject:_label forKey:@"label"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
