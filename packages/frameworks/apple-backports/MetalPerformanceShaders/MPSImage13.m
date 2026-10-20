#import "RevenantMPS.h"

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

NSUInteger RevenantMPSImageElementSize(MPSImageFeatureChannelFormat format)
{
    switch (format) {
    case MPSImageFeatureChannelFormatUnorm8: return 1;
    case MPSImageFeatureChannelFormatUnorm16: return 2;
    case MPSImageFeatureChannelFormatFloat16: return 2;
    case MPSImageFeatureChannelFormatFloat32: return 4;
    default: return 0;
    }
}

MTLPixelFormat RevenantMPSImagePixelFormat(MPSImageFeatureChannelFormat format)
{
    switch (format) {
    case MPSImageFeatureChannelFormatUnorm8: return MTLPixelFormatR8Unorm;
    case MPSImageFeatureChannelFormatUnorm16: return MTLPixelFormatR16Unorm;
    case MPSImageFeatureChannelFormatFloat16: return MTLPixelFormatR16Float;
    case MPSImageFeatureChannelFormatFloat32: return MTLPixelFormatR32Float;
    default: return MTLPixelFormatInvalid;
    }
}

MTLPixelFormat RevenantMPSImagePixelFormatFor(MPSImageFeatureChannelFormat format, NSUInteger channels)
{
    if (channels == 1)
        return RevenantMPSImagePixelFormat(format);
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

MPSImageFeatureChannelFormat RevenantMPSImageFormatOfPixelFormat(MTLPixelFormat pixel)
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

- (MTLPixelFormat)pixelFormat { return RevenantMPSImagePixelFormatFor(_channelFormat, _featureChannels); }

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
    if ((self = [super init])) {
        _device = device;
        _featureChannels = 1;
        _numberOfImages = 1;
        _channelFormat = MPSImageFeatureChannelFormatNone;
        RevenantMPSRefuse(@"MPSImage: -initWithDevice: names no shape. Build an MPSImageDescriptor and use "
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
        NSUInteger element = RevenantMPSImageElementSize(descriptor.channelFormat);
        if (!element || !descriptor.width || !descriptor.height || !descriptor.featureChannels) {
            RevenantMPSRefuse(@"MPSImage: a descriptor of channel format %lu with %lux%lu and %lu feature channels "
                            "names no storage this port can hold",
                            (unsigned long)descriptor.channelFormat, (unsigned long)descriptor.width,
                            (unsigned long)descriptor.height, (unsigned long)descriptor.featureChannels);
            return self;
        }
        MTLPixelFormat pixel = descriptor.pixelFormat;
        if (pixel == MTLPixelFormatInvalid) {
            RevenantMPSRefuse(@"MPSImage: channel format %lu with %lu feature channels has no Metal pixel format, "
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
            RevenantMPSRefuse(@"MPSImage: the carried Metal classes made no texture for %lux%lu of format %d, "
                            "so this image holds nothing",
                            (unsigned long)descriptor.width, (unsigned long)descriptor.height, (int)pixel);
            return self;
        }
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
        _channelFormat = RevenantMPSImageFormatOfPixelFormat(texture.pixelFormat);
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
    return (size_t)RevenantMPSImageElementSize(_channelFormat) * _featureChannels;
}
- (NSUInteger)precision { return (NSUInteger)RevenantMPSImageElementSize(_channelFormat) * 8; }
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
        RevenantMPSRefuse(@"MPSImage: -readBytes: was given no buffer or this image holds no texture, so nothing was read");
        return;
    }
    if (imageIndex >= _numberOfImages) {
        RevenantMPSRefuse(@"MPSImage: -readBytes: was given image index %lu of %lu, so nothing was read",
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
        RevenantMPSRefuse(@"MPSImage: -writeBytes: was given no buffer or this image holds no texture, so nothing was written");
        return;
    }
    if (imageIndex >= _numberOfImages) {
        RevenantMPSRefuse(@"MPSImage: -writeBytes: was given image index %lu of %lu, so nothing was written",
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
