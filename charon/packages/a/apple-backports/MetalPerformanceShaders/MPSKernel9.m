// MPSKernel, from the header of the SDK of iOS 16.4. One object per release: the band machinery keeps an
// object whole or drops it whole, so a file here carries the API of exactly one release.

#import "CharonMPS.h"


const MTLRegion MPSRectNoClip = {{0, 0, 0}, {-1, -1, -1}};
BOOL MPSSupportsMTLDevice(id<MTLDevice> device)
{
    // The release answers YES for a device whose hardware it can run its kernels on. Every MTLDevice
    // this port has is its own OpenGL ES 2.0 bridge, and every kernel in this framework runs on it,
    // so the answer is the same question the release asks - can this device run an MPS kernel - and
    // the port's answer is yes. nil is not a device and is refused as the release refuses it.
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
    // A kernel of this port is a description of work, not a compiled pipeline, and what the archive
    // carries is the device, the options and the label. Nothing here encodes a subclass's own state,
    // and nothing here can: the release's keys for it are in no header, and an invented key would
    // write an archive the release cannot read. So -initWithCoder:device: on a subclass answers this
    // implementation, and the two random generators are recorded as owed in
    // facts/MetalPerformanceShaders/Random.md rather than described as round-tripping.
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
