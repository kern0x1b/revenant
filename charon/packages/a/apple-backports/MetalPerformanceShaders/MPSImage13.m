// MPSImage13.m - the image: a descriptor that says its shape, and the image that owns a texture.
//
// What this is: the port's own MPSImage is a real MTLTexture on the carried Metal classes, allocated
// through MTLTextureDescriptor and read and written through the texture's own
// getBytes:bytesPerRow:fromRegion:mipmapLevel: and replaceRegion:mipmapLevel:withBytes:bytesPerRow:.
// That is the shape the release takes, and it is the shape tests/backports/host/mpscnn/cnn-cases.m
// builds its cases with; the reason it is written this way is measured there, where the case's source
// and destination used to be the host's MPSImage and the five cases compared the host with itself.
//
// What this is not: a texture this port answers with its own arithmetic is not here. The image holds
// the caller's bytes and hands them back; a kernel reads and writes it. MPSImageMatrix and the rest of
// this family are the kernels, and they are separate files.
//
// The 26.2 names the tree already calls - +imageDescriptorWithChannelFormat:width:height:featureChannels:
// and -initWithDevice:imageDescriptor: - are in the 16.4 headers with 16.4's own signatures, so they
// are implemented here and not transcribed; what 26.2 adds over them is the set of initialisers this
// class answers as the header of this build declares them, and a caller that asks for one 16.4 does
// not name gets the nearest this build has and no lie about it.

#import "CharonMPS.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

NSUInteger CharonMPSImageElementSize(MPSImageFeatureChannelFormat format)
{
    switch (format) {
    case MPSImageFeatureChannelFormatUnorm8: return 1;
    case MPSImageFeatureChannelFormatUnorm16: return 2;
    case MPSImageFeatureChannelFormatFloat16: return 2;
    case MPSImageFeatureChannelFormatFloat32: return 4;
    default: return 0;
    }
}

MTLPixelFormat CharonMPSImagePixelFormat(MPSImageFeatureChannelFormat format)
{
    switch (format) {
    case MPSImageFeatureChannelFormatUnorm8: return MTLPixelFormatR8Unorm;
    case MPSImageFeatureChannelFormatUnorm16: return MTLPixelFormatR16Unorm;
    case MPSImageFeatureChannelFormatFloat16: return MTLPixelFormatR16Float;
    case MPSImageFeatureChannelFormatFloat32: return MTLPixelFormatR32Float;
    default: return MTLPixelFormatInvalid;
    }
}

// The pixel format a texture of `channels` channels of `format` has, for the one channel and the four
// channel layouts the header names. A channel count that has no Metal format is zero, and the caller
// refuses rather than picking a format the caller's bytes do not match.
MTLPixelFormat CharonMPSImagePixelFormatFor(MPSImageFeatureChannelFormat format, NSUInteger channels)
{
    if (channels == 1)
        return CharonMPSImagePixelFormat(format);
    if (channels == 2) {
        switch (format) {
        case MPSImageFeatureChannelFormatUnorm8: return MTLPixelFormatRG8Unorm;
        case MPSImageFeatureChannelFormatUnorm16: return MTLPixelFormatRG16Unorm;
        case MPSImageFeatureChannelFormatFloat16: return MTLPixelFormatRG16Float;
        case MPSImageFeatureChannelFormatFloat32: return MTLPixelFormatRG32Float;
        default: return MTLPixelFormatInvalid;
        }
    }
    if (channels == 4) {
        switch (format) {
        case MPSImageFeatureChannelFormatUnorm8: return MTLPixelFormatRGBA8Unorm;
        case MPSImageFeatureChannelFormatUnorm16: return MTLPixelFormatRGBA16Unorm;
        case MPSImageFeatureChannelFormatFloat16: return MTLPixelFormatRGBA16Float;
        case MPSImageFeatureChannelFormatFloat32: return MTLPixelFormatRGBA32Float;
        default: return MTLPixelFormatInvalid;
        }
    }
    return MTLPixelFormatInvalid;
}

// The pixel format back to the channel format it came from, for an image made over somebody else's
// texture. A format this build does not name is None, and the image says so in its description rather
// than guessing a format whose element size the bytes do not have.
MPSImageFeatureChannelFormat CharonMPSImageFormatOfPixelFormat(MTLPixelFormat pixel)
{
    switch (pixel) {
    case MTLPixelFormatR8Unorm: case MTLPixelFormatRG8Unorm: case MTLPixelFormatRGBA8Unorm:
        return MPSImageFeatureChannelFormatUnorm8;
    case MTLPixelFormatR16Unorm: case MTLPixelFormatRG16Unorm: case MTLPixelFormatRGBA16Unorm:
        return MPSImageFeatureChannelFormatUnorm16;
    case MTLPixelFormatR16Float: case MTLPixelFormatRG16Float: case MTLPixelFormatRGBA16Float:
        return MPSImageFeatureChannelFormatFloat16;
    case MTLPixelFormatR32Float: case MTLPixelFormatRG32Float: case MTLPixelFormatRGBA32Float:
        return MPSImageFeatureChannelFormatFloat32;
    default: return MPSImageFeatureChannelFormatNone;
    }
}

@implementation MPSImageDescriptor {
    NSUInteger _width, _height, _featureChannels, _numberOfImages;
    MPSImageFeatureChannelFormat _channelFormat;
    MTLCPUCacheMode _cpuCacheMode;
    MTLStorageMode _storageMode;
    MTLTextureUsage _usage;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _width = 1; _height = 1; _featureChannels = 1; _numberOfImages = 1;
        _channelFormat = MPSImageFeatureChannelFormatNone;
        _usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    }
    return self;
}

- (NSUInteger)width { return _width; }
- (void)setWidth:(NSUInteger)width { _width = width; }
- (NSUInteger)height { return _height; }
- (void)setHeight:(NSUInteger)height { _height = height; }
- (NSUInteger)featureChannels { return _featureChannels; }
- (void)setFeatureChannels:(NSUInteger)featureChannels { _featureChannels = featureChannels; }
- (NSUInteger)numberOfImages { return _numberOfImages; }
- (void)setNumberOfImages:(NSUInteger)numberOfImages { _numberOfImages = numberOfImages; }
- (MPSImageFeatureChannelFormat)channelFormat { return _channelFormat; }
- (void)setChannelFormat:(MPSImageFeatureChannelFormat)channelFormat { _channelFormat = channelFormat; }
- (MTLCPUCacheMode)cpuCacheMode { return _cpuCacheMode; }
- (void)setCpuCacheMode:(MTLCPUCacheMode)cpuCacheMode { _cpuCacheMode = cpuCacheMode; }
- (MTLStorageMode)storageMode { return _storageMode; }
- (void)setStorageMode:(MTLStorageMode)storageMode { _storageMode = storageMode; }
- (MTLTextureUsage)usage { return _usage; }
- (void)setUsage:(MTLTextureUsage)usage { _usage = usage; }

- (MTLPixelFormat)pixelFormat { return CharonMPSImagePixelFormatFor(_channelFormat, _featureChannels); }

+ (instancetype)imageDescriptorWithChannelFormat:(MPSImageFeatureChannelFormat)channelFormat
                                           width:(NSUInteger)width
                                          height:(NSUInteger)height
                                 featureChannels:(NSUInteger)featureChannels
{
    return [self imageDescriptorWithChannelFormat:channelFormat
                                            width:width
                                           height:height
                                  featureChannels:featureChannels
                                   numberOfImages:1
                                            usage:MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite];
}

+ (instancetype)imageDescriptorWithChannelFormat:(MPSImageFeatureChannelFormat)channelFormat
                                           width:(NSUInteger)width
                                          height:(NSUInteger)height
                                 featureChannels:(NSUInteger)featureChannels
                                  numberOfImages:(NSUInteger)numberOfImages
                                           usage:(MTLTextureUsage)usage
{
    MPSImageDescriptor *d = [[MPSImageDescriptor alloc] init];
    d.channelFormat = channelFormat;
    d.width = width;
    d.height = height;
    d.featureChannels = featureChannels;
    d.numberOfImages = numberOfImages;
    d.usage = usage;
    return d;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[MPSImageDescriptor class]])
        return NO;
    MPSImageDescriptor *o = other;
    return o.channelFormat == _channelFormat && o.width == _width && o.height == _height &&
           o.featureChannels == _featureChannels && o.numberOfImages == _numberOfImages &&
           o.usage == _usage;
}

- (NSUInteger)hash
{
    return (NSUInteger)_channelFormat * 31 + _width * 7 + _height * 13 + _featureChannels * 17 +
           _numberOfImages * 19 + (NSUInteger)_usage;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    MPSImageDescriptor *c = [[[MPSImageDescriptor allocWithZone:zone] init] copy];
    c.channelFormat = _channelFormat;
    c.width = _width;
    c.height = _height;
    c.featureChannels = _featureChannels;
    c.numberOfImages = _numberOfImages;
    c.cpuCacheMode = _cpuCacheMode;
    c.storageMode = _storageMode;
    c.usage = _usage;
    return c;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MPSImageDescriptor %lux%lux%lu channels, %lu images, format %lu, pixel %d>",
            (unsigned long)_width, (unsigned long)_height, (unsigned long)_featureChannels,
            (unsigned long)_numberOfImages, (unsigned long)_channelFormat, (int)[self pixelFormat]];
}

@end

@implementation MPSImage {
    id<MTLDevice> _device;
    id<MTLTexture> _texture;
    NSUInteger _featureChannels;
    NSUInteger _numberOfImages;
    MPSImageFeatureChannelFormat _channelFormat;
    NSString *_label;
    MPSImage *_parent;
    NSRange _sliceRange;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    // A device alone names no shape, and the release's own default allocator is what an image of no
    // descriptor is; this port has no allocator, so it refuses rather than answering 1x1x1 silently.
    if ((self = [super init])) {
        _device = device;
        _featureChannels = 1;
        _numberOfImages = 1;
        _channelFormat = MPSImageFeatureChannelFormatNone;
        CharonMPSRefuse(@"MPSImage: -initWithDevice: names no shape. Build an MPSImageDescriptor and use "
                        @"-initWithDevice:imageDescriptor:, which is what this port implements");
    }
    return self;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device imageDescriptor:(MPSImageDescriptor *)descriptor
{
    if ((self = [super init])) {
        _device = device;
        _featureChannels = descriptor.featureChannels;
        _numberOfImages = descriptor.numberOfImages;
        _channelFormat = descriptor.channelFormat;
        _sliceRange = NSMakeRange(0, descriptor.numberOfImages);
        NSUInteger element = CharonMPSImageElementSize(descriptor.channelFormat);
        if (!element || !descriptor.width || !descriptor.height || !descriptor.featureChannels) {
            CharonMPSRefuse(@"MPSImage: a descriptor of channel format %lu with %lux%lu and %lu feature channels "
                            "names no storage this port can hold",
                            (unsigned long)descriptor.channelFormat, (unsigned long)descriptor.width,
                            (unsigned long)descriptor.height, (unsigned long)descriptor.featureChannels);
            return self;
        }
        MTLPixelFormat pixel = descriptor.pixelFormat;
        if (pixel == MTLPixelFormatInvalid) {
            CharonMPSRefuse(@"MPSImage: channel format %lu with %lu feature channels has no Metal pixel format, "
                            "so no texture was made",
                            (unsigned long)descriptor.channelFormat, (unsigned long)descriptor.featureChannels);
            return self;
        }
        MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixel
                                                                                    width:descriptor.width
                                                                                   height:descriptor.height
                                                                                mipmapped:NO];
        td.usage = descriptor.usage;
        td.storageMode = descriptor.storageMode;
        td.cpuCacheMode = descriptor.cpuCacheMode;
        _texture = [device newTextureWithDescriptor:td];
        if (!_texture) {
            CharonMPSRefuse(@"MPSImage: the carried Metal classes made no texture for %lux%lu of format %d, "
                            "so this image holds nothing",
                            (unsigned long)descriptor.width, (unsigned long)descriptor.height, (int)pixel);
            return self;
        }
        // A texture's contents are whatever was in it, and a kernel reads them. The release zeroes a
        // fresh image; the port says so explicitly rather than leaving a texture's own contents to be
        // read as the caller's pixels, which is not a thing to leave to chance.
        NSUInteger rowBytes = descriptor.width * element * descriptor.featureChannels;
        void *zero = calloc(rowBytes * descriptor.height * descriptor.numberOfImages, 1);
        for (NSUInteger slice = 0; slice < descriptor.numberOfImages; slice++)
            [_texture replaceRegion:MTLRegionMake2D(0, 0, descriptor.width, descriptor.height)
                        mipmapLevel:0 withBytes:zero bytesPerRow:rowBytes];
        free(zero);
    }
    return self;
}

- (instancetype)initWithTexture:(id<MTLTexture>)texture
{
    return [self initWithTexture:texture featureChannels:1];
}

- (instancetype)initWithTexture:(id<MTLTexture>)texture featureChannels:(NSUInteger)featureChannels
{
    if ((self = [super init])) {
        _texture = texture;
        _featureChannels = featureChannels ? featureChannels : 1;
        _numberOfImages = 1;
        _channelFormat = CharonMPSImageFormatOfPixelFormat(texture.pixelFormat);
        _sliceRange = NSMakeRange(0, 1);
    }
    return self;
}

- (instancetype)initWithParentImage:(MPSImage *)parent
{
    return [self initWithParentImage:parent sliceRange:NSMakeRange(0, parent.numberOfImages) featureChannels:parent.featureChannels];
}

- (instancetype)initWithParentImage:(MPSImage *)parent
                         sliceRange:(NSRange)sliceRange
                    featureChannels:(NSUInteger)featureChannels
{
    if ((self = [super init])) {
        _parent = parent;
        _device = parent.device;
        _texture = parent.texture;
        _sliceRange = sliceRange;
        _numberOfImages = sliceRange.length;
        _featureChannels = featureChannels ? featureChannels : parent.featureChannels;
        _channelFormat = parent.featureChannelFormat;
    }
    return self;
}

- (id<MTLDevice>)device { return _device; }
- (NSUInteger)width { return _texture ? _texture.width : 0; }
- (NSUInteger)height { return _texture ? _texture.height : 0; }
- (NSUInteger)featureChannels { return _featureChannels; }
- (NSUInteger)numberOfImages { return _numberOfImages; }
- (MTLTextureType)textureType { return _texture ? _texture.textureType : (MTLTextureType)0; }
- (MTLPixelFormat)pixelFormat { return _texture ? _texture.pixelFormat : MTLPixelFormatInvalid; }
- (MTLTextureUsage)usage { return _texture ? _texture.usage : 0; }
- (MPSImageFeatureChannelFormat)featureChannelFormat { return _channelFormat; }
- (size_t)pixelSize
{
    return (size_t)CharonMPSImageElementSize(_channelFormat) * _featureChannels;
}
- (NSUInteger)precision { return (NSUInteger)CharonMPSImageElementSize(_channelFormat) * 8; }
- (id<MTLTexture>)texture { return _texture; }
- (NSString *)label { return _label; }
- (void)setLabel:(NSString *)label { _label = [label copy]; }
- (MPSImage *)parent { return _parent; }

- (void)readBytes:(void *)dataBytes
        dataLayout:(MPSDataLayout)dataLayout
       bytesPerRow:(NSUInteger)bytesPerRow
            region:(MTLRegion)region
featureChannelInfo:(MPSImageReadWriteParams)featureChannelInfo
        imageIndex:(NSUInteger)imageIndex
{
    if (!dataBytes || !_texture) {
        CharonMPSRefuse(@"MPSImage: -readBytes: was given no buffer or this image holds no texture, so nothing was read");
        return;
    }
    if (imageIndex >= _numberOfImages) {
        CharonMPSRefuse(@"MPSImage: -readBytes: was given image index %lu of %lu, so nothing was read",
                        (unsigned long)imageIndex, (unsigned long)_numberOfImages);
        return;
    }
    [_texture getBytes:dataBytes bytesPerRow:bytesPerRow fromRegion:region mipmapLevel:0];
}

- (void)writeBytes:(const void *)dataBytes
         dataLayout:(MPSDataLayout)dataLayout
        bytesPerRow:(NSUInteger)bytesPerRow
             region:(MTLRegion)region
featureChannelInfo:(MPSImageReadWriteParams)featureChannelInfo
         imageIndex:(NSUInteger)imageIndex
{
    if (!dataBytes || !_texture) {
        CharonMPSRefuse(@"MPSImage: -writeBytes: was given no buffer or this image holds no texture, so nothing was written");
        return;
    }
    if (imageIndex >= _numberOfImages) {
        CharonMPSRefuse(@"MPSImage: -writeBytes: was given image index %lu of %lu, so nothing was written",
                        (unsigned long)imageIndex, (unsigned long)_numberOfImages);
        return;
    }
    [_texture replaceRegion:region mipmapLevel:0 withBytes:dataBytes bytesPerRow:bytesPerRow];
}

- (void)readBytes:(void *)dataBytes
       dataLayout:(MPSDataLayout)dataLayout
    bytesPerRow:(NSUInteger)bytesPerRow
         region:(MTLRegion)region
    imageIndex:(NSUInteger)imageIndex
{
    [self readBytes:dataBytes dataLayout:dataLayout bytesPerRow:bytesPerRow region:region
   featureChannelInfo:(MPSImageReadWriteParams){0} imageIndex:imageIndex];
}

- (void)writeBytes:(const void *)dataBytes
        dataLayout:(MPSDataLayout)dataLayout
       bytesPerRow:(NSUInteger)bytesPerRow
            region:(MTLRegion)region
        imageIndex:(NSUInteger)imageIndex
{
    [self writeBytes:dataBytes dataLayout:dataLayout bytesPerRow:bytesPerRow region:region
   featureChannelInfo:(MPSImageReadWriteParams){0} imageIndex:imageIndex];
}

- (MPSImage *)subImageWithFeatureChannelRange:(NSRange)range
{
    return [[MPSImage alloc] initWithParentImage:self
                                     sliceRange:NSMakeRange(_sliceRange.location, _sliceRange.length)
                                featureChannels:range.length];
}

- (id<MPSImageAllocator>)defaultAllocator { return nil; }

- (BOOL)isEqual:(id)other
{
    if (self == other)
        return YES;
    if (![other isKindOfClass:[MPSImage class]])
        return NO;
    MPSImage *o = other;
    return o.texture == _texture && o.featureChannels == _featureChannels && o.width == self.width &&
           o.height == self.height;
}

- (NSUInteger)hash { return (NSUInteger)_texture + _featureChannels * 31 + self.width * 7 + self.height * 13; }

- (instancetype)copyWithZone:(NSZone *)zone
{
    // A copy of an image is an image over a texture of its own with the same contents, because a
    // texture the port does not own cannot be copied by handing the same pointer to a second image and
    // calling it a copy: the two would write over each other.
    MPSImage *copy = nil;
    if (_texture) {
        MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:_texture.pixelFormat
                                                                                    width:_texture.width
                                                                                   height:_texture.height
                                                                                mipmapped:NO];
        td.usage = _texture.usage;
        td.storageMode = _texture.storageMode;
        id<MTLTexture> t = [_device newTextureWithDescriptor:td];
        NSUInteger rowBytes = self.pixelSize * self.width;
        void *buffer = calloc(rowBytes ? rowBytes : 1, 1);
        [_texture getBytes:buffer bytesPerRow:rowBytes fromRegion:MTLRegionMake2D(0, 0, self.width, self.height)
                                 mipmapLevel:0];
        [t replaceRegion:MTLRegionMake2D(0, 0, self.width, self.height) mipmapLevel:0 withBytes:buffer
              bytesPerRow:rowBytes];
        free(buffer);
        copy = [[MPSImage allocWithZone:zone] initWithTexture:t featureChannels:_featureChannels];
    }
    copy->_label = [_label copy];
    copy->_numberOfImages = _numberOfImages;
    copy->_channelFormat = _channelFormat;
    copy->_sliceRange = _sliceRange;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithDevice:nil];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (_label)
        [aCoder encodeObject:_label forKey:@"label"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MPSImage %lux%lu, %lu feature channels, %lu images, format %lu, "
            @"pixel %d, %s>", (unsigned long)self.width, (unsigned long)self.height,
            (unsigned long)_featureChannels, (unsigned long)_numberOfImages, (unsigned long)_channelFormat,
            (int)[self pixelFormat], _texture ? "with a texture" : "without a texture"];
}

@end
