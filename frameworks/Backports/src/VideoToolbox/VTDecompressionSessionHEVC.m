#import "VTDecompressionSessionHEVC.h"

#import <Foundation/Foundation.h>

#import "VTConvertBiPlanar.h"
#import "VTDecodeHEVC.h"
#import "VTInterleave.h"

static NSHashTable *RevenantVTSessionRegistry(void)
{
    static NSHashTable *registry;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        registry = [NSHashTable hashTableWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality];
    });
    return registry;
}

static BOOL RevenantVTRequiresHardware(CFDictionaryRef specification)
{
    if (!specification)
        return NO;
    NSNumber *required = ((__bridge NSDictionary *)specification)[(__bridge NSString *)kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder];
    return [required isKindOfClass:[NSNumber class]] && [required boolValue];
}

static NSData *RevenantVTConfiguration(CMFormatDescriptionRef format)
{
    NSDictionary *atoms = (__bridge NSDictionary *)CMFormatDescriptionGetExtension(format, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms);
    NSData *configuration = atoms[@"hvcC"];
    return [configuration isKindOfClass:[NSData class]] ? configuration : nil;
}

static OSStatus RevenantVTConfigurationStatus(NSData *configuration)
{
    if (configuration.length < 23)
        return kVTVideoDecoderBadDataErr;
    const uint8_t *bytes = configuration.bytes;
    if (bytes[0] != 1)
        return kVTVideoDecoderBadDataErr;
    if ((bytes[16] & 3) != 1 || (bytes[17] & 7) != 0 || (bytes[18] & 7) != 0)
        return kVTVideoDecoderUnsupportedDataFormatErr;
    return noErr;
}

static OSStatus RevenantVTStatusOf(RevenantVTHEVCResult result)
{
    switch (result) {
    case RevenantVTHEVCOK:
        return noErr;
    case RevenantVTHEVCNoDecoder:
        return kVTCouldNotFindVideoDecoderErr;
    case RevenantVTHEVCBadData:
        return kVTVideoDecoderBadDataErr;
    case RevenantVTHEVCUnsupportedFormat:
        return kVTVideoDecoderUnsupportedDataFormatErr;
    case RevenantVTHEVCOutOfMemory:
        return kVTAllocationFailedErr;
    case RevenantVTHEVCBusy:
        return kVTVideoDecoderNotAvailableNowErr;
    case RevenantVTHEVCMalfunction:
        break;
    }
    return kVTVideoDecoderMalfunctionErr;
}

static BOOL RevenantVTIsSupportedPixelFormat(OSType format)
{
    return format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || format == kCVPixelFormatType_32BGRA;
}

static OSStatus RevenantVTPixelFormatOf(CFDictionaryRef attributes, CMVideoDimensions dimensions, OSType *formatOut)
{
    *formatOut = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    if (!attributes)
        return noErr;
    NSDictionary *destination = (__bridge NSDictionary *)attributes;
    NSNumber *width = destination[(__bridge NSString *)kCVPixelBufferWidthKey];
    NSNumber *height = destination[(__bridge NSString *)kCVPixelBufferHeightKey];
    if ((width && width.intValue != dimensions.width) || (height && height.intValue != dimensions.height))
        return kVTPixelTransferNotSupportedErr;
    id requested = destination[(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey];
    if (!requested)
        return noErr;
    NSArray *candidates = [requested isKindOfClass:[NSArray class]] ? requested : @[requested];
    for (id candidate in candidates) {
        if (![candidate isKindOfClass:[NSNumber class]])
            continue;
        const OSType format = (OSType)[candidate unsignedIntValue];
        if (RevenantVTIsSupportedPixelFormat(format)) {
            *formatOut = format;
            return noErr;
        }
    }
    return kVTPixelTransferNotSupportedErr;
}

static BOOL RevenantVTIsSupportedProperty(CFStringRef key)
{
    return CFEqual(key, kVTDecompressionPropertyKey_RealTime) || CFEqual(key, kVTDecompressionPropertyKey_MaximizePowerEfficiency);
}

@interface RevenantVTPendingFrame : NSObject
@property (nonatomic) CMTime presentationTimeStamp;
@property (nonatomic) CMTime presentationDuration;
@property (nonatomic) void *sourceFrameRefCon;
@property (nonatomic) BOOL suppressed;
@property (nonatomic, copy) RevenantVTDecodeOutput output;
@end

@implementation RevenantVTPendingFrame
@end

static void RevenantVTSoftwareEmit(void *context, const RevenantVTHEVCPicture *picture);

@interface RevenantVTSoftwareSession : NSObject
- (instancetype)initWithDecoder:(RevenantVTHEVCDecoder *)decoder dimensions:(CMVideoDimensions)dimensions pixelFormat:(OSType)pixelFormat output:(RevenantVTDecodeOutput)output;
- (OSStatus)decodeSample:(CMSampleBufferRef)sample flags:(VTDecodeFrameFlags)flags refcon:(void *)refcon output:(RevenantVTDecodeOutput)output infoFlags:(VTDecodeInfoFlags *)infoFlagsOut;
- (OSStatus)finish;
- (void)invalidate;
- (BOOL)canAcceptFormat:(CMFormatDescriptionRef)format;
- (OSStatus)setProperty:(CFStringRef)key value:(CFTypeRef)value;
- (OSStatus)copyProperty:(CFStringRef)key allocator:(CFAllocatorRef)allocator valueOut:(CFTypeRef *)valueOut;
- (void)emitPicture:(const RevenantVTHEVCPicture *)picture;
@end

@implementation RevenantVTSoftwareSession {
    RevenantVTHEVCDecoder *_decoder;
    CMVideoDimensions _dimensions;
    OSType _pixelFormat;
    RevenantVTDecodeOutput _output;
    CVPixelBufferPoolRef _pool;
    size_t _poolWidth;
    size_t _poolHeight;
    uint8_t *_scratch;
    size_t _scratchSize;
    NSMutableDictionary<NSNumber *, RevenantVTPendingFrame *> *_pending;
    NSMutableDictionary<NSString *, id> *_properties;
    int64_t _nextSequence;
    OSStatus _emitStatus;
    BOOL _invalidated;
}

- (instancetype)initWithDecoder:(RevenantVTHEVCDecoder *)decoder dimensions:(CMVideoDimensions)dimensions pixelFormat:(OSType)pixelFormat output:(RevenantVTDecodeOutput)output
{
    self = [super init];
    if (self) {
        _decoder = decoder;
        _dimensions = dimensions;
        _pixelFormat = pixelFormat;
        _output = [output copy];
        _pending = [NSMutableDictionary dictionary];
        _properties = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc
{
    @synchronized (RevenantVTSessionRegistry()) {
        [RevenantVTSessionRegistry() removeObject:(__bridge id)(__bridge void *)self];
    }
    RevenantVTHEVCDecoderDestroy(_decoder);
    if (_pool)
        CVPixelBufferPoolRelease(_pool);
    free(_scratch);
}

- (OSStatus)decodeSample:(CMSampleBufferRef)sample flags:(VTDecodeFrameFlags)flags refcon:(void *)refcon output:(RevenantVTDecodeOutput)output infoFlags:(VTDecodeInfoFlags *)infoFlagsOut
{
    __attribute__((objc_precise_lifetime)) RevenantVTSoftwareSession *lifetime = self;
    @synchronized (self) {
        if (_invalidated)
            return kVTInvalidSessionErr;
        RevenantVTDecodeOutput handler = output ?: _output;
        if (!sample || !handler)
            return kVTParameterErr;
        CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sample);
        if (!block)
            return kVTParameterErr;
        const size_t length = CMBlockBufferGetDataLength(block);
        char *contiguous = NULL;
        size_t contiguousLength = 0;
        size_t totalLength = 0;
        __attribute__((objc_precise_lifetime)) NSMutableData *copy = nil;
        const uint8_t *bytes = NULL;
        if (CMBlockBufferGetDataPointer(block, 0, &contiguousLength, &totalLength, &contiguous) == kCMBlockBufferNoErr && contiguousLength == length) {
            bytes = (const uint8_t *)contiguous;
        } else {
            copy = [NSMutableData dataWithLength:length];
            if (CMBlockBufferCopyDataBytes(block, 0, length, copy.mutableBytes) != kCMBlockBufferNoErr)
                return kVTVideoDecoderBadDataErr;
            bytes = copy.bytes;
        }

        RevenantVTPendingFrame *frame = [[RevenantVTPendingFrame alloc] init];
        frame.presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sample);
        frame.presentationDuration = CMSampleBufferGetDuration(sample);
        frame.sourceFrameRefCon = refcon;
        frame.suppressed = (flags & kVTDecodeFrame_DoNotOutputFrame) != 0;
        frame.output = handler;
        const int64_t sequence = _nextSequence++;
        _pending[@(sequence)] = frame;
        _emitStatus = noErr;
        const RevenantVTHEVCResult result = RevenantVTHEVCDecoderDecode(_decoder, bytes, length, sequence, RevenantVTSoftwareEmit, (__bridge void *)self);
        if (infoFlagsOut)
            *infoFlagsOut = 0;
        if (result != RevenantVTHEVCOK) {
            [_pending removeObjectForKey:@(sequence)];
            return RevenantVTStatusOf(result);
        }
        return _emitStatus;
    }
}

- (OSStatus)finish
{
    __attribute__((objc_precise_lifetime)) RevenantVTSoftwareSession *lifetime = self;
    @synchronized (self) {
        if (_invalidated)
            return kVTInvalidSessionErr;
        _emitStatus = noErr;
        const RevenantVTHEVCResult result = RevenantVTHEVCDecoderFinish(_decoder, RevenantVTSoftwareEmit, (__bridge void *)self);
        if (result == RevenantVTHEVCBusy)
            return RevenantVTStatusOf(result);
        [_pending removeAllObjects];
        if (result != RevenantVTHEVCOK)
            return RevenantVTStatusOf(result);
        return _emitStatus;
    }
}

- (void)invalidate
{
    __attribute__((objc_precise_lifetime)) RevenantVTSoftwareSession *lifetime = self;
    @synchronized (self) {
        if (_invalidated)
            return;
        (void)[self finish];
        _invalidated = YES;
        RevenantVTHEVCDecoderDestroy(_decoder);
        _decoder = NULL;
    }
}

- (BOOL)canAcceptFormat:(CMFormatDescriptionRef)format
{
    if (!format || CMFormatDescriptionGetMediaSubType(format) != kCMVideoCodecType_HEVC)
        return NO;
    const CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format);
    return dimensions.width == _dimensions.width && dimensions.height == _dimensions.height && RevenantVTConfigurationStatus(RevenantVTConfiguration(format)) == noErr;
}

- (OSStatus)setProperty:(CFStringRef)key value:(CFTypeRef)value
{
    if (!RevenantVTIsSupportedProperty(key))
        return kVTPropertyNotSupportedErr;
    if (!value || CFGetTypeID(value) != CFBooleanGetTypeID())
        return kVTParameterErr;
    @synchronized (self) {
        _properties[(__bridge NSString *)key] = (__bridge id)value;
    }
    return noErr;
}

- (OSStatus)copyProperty:(CFStringRef)key allocator:(CFAllocatorRef)allocator valueOut:(CFTypeRef *)valueOut
{
    if (!valueOut || !RevenantVTIsSupportedProperty(key))
        return kVTPropertyNotSupportedErr;
    @synchronized (self) {
        id value = _properties[(__bridge NSString *)key] ?: @NO;
        *valueOut = CFBridgingRetain(value);
    }
    return noErr;
}

static void RevenantVTInterleaveChroma(uint8_t *out, size_t outStride, const uint8_t *blue, size_t blueStride, const uint8_t *red, size_t redStride, size_t width, size_t height)
{
#if defined(__ARM_NEON)
    RevenantVTInterleaveChromaNEON(out, outStride, blue, blueStride, red, redStride, width, height);
#else
    RevenantVTInterleaveChromaScalar(out, outStride, blue, blueStride, red, redStride, width, height);
#endif
}

- (OSStatus)fillBuffer:(CVPixelBufferRef)buffer fromPicture:(const RevenantVTHEVCPicture *)picture
{
    const size_t width = (size_t)picture->width;
    const size_t height = (size_t)picture->height;
    const size_t chromaWidth = (width + 1) / 2;
    const size_t chromaHeight = (height + 1) / 2;
    if (_pixelFormat == kCVPixelFormatType_32BGRA) {
        const size_t stride = chromaWidth * 2;
        const size_t needed = stride * chromaHeight;
        if (needed > _scratchSize) {
            free(_scratch);
            _scratch = malloc(needed);
            _scratchSize = _scratch ? needed : 0;
            if (!_scratch)
                return kVTAllocationFailedErr;
        }
        RevenantVTInterleaveChroma(_scratch, stride, picture->chromaBlue, picture->chromaBlueStride, picture->chromaRed, picture->chromaRedStride, chromaWidth, chromaHeight);
        const bool bt709 = picture->matrix == RevenantVTHEVCMatrixBT709;
        uint8_t *out = CVPixelBufferGetBaseAddress(buffer);
        const size_t rowBytes = CVPixelBufferGetBytesPerRow(buffer);
#if defined(__ARM_NEON)
        RevenantVTConvertBiPlanarNEON(out, rowBytes, picture->luma, picture->lumaStride, _scratch, stride, width, height, picture->fullRange, bt709);
#else
        RevenantVTConvertBiPlanarScalar(out, rowBytes, picture->luma, picture->lumaStride, _scratch, stride, width, height, picture->fullRange, bt709);
#endif
        return noErr;
    }
    RevenantVTCopyPlane(CVPixelBufferGetBaseAddressOfPlane(buffer, 0), CVPixelBufferGetBytesPerRowOfPlane(buffer, 0), picture->luma, picture->lumaStride, width, height);
    RevenantVTInterleaveChroma(CVPixelBufferGetBaseAddressOfPlane(buffer, 1), CVPixelBufferGetBytesPerRowOfPlane(buffer, 1), picture->chromaBlue, picture->chromaBlueStride, picture->chromaRed, picture->chromaRedStride, chromaWidth, chromaHeight);
    return noErr;
}

- (CVPixelBufferRef)pixelBufferForPicture:(const RevenantVTHEVCPicture *)picture status:(OSStatus *)status
{
    const size_t width = (size_t)picture->width;
    const size_t height = (size_t)picture->height;
    if (!_pool || _poolWidth != width || _poolHeight != height) {
        if (_pool)
            CVPixelBufferPoolRelease(_pool);
        _pool = NULL;
        NSDictionary *attributes = @{(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(_pixelFormat),
                                     (__bridge NSString *)kCVPixelBufferWidthKey: @(width),
                                     (__bridge NSString *)kCVPixelBufferHeightKey: @(height)};
        if (CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)attributes, &_pool) != kCVReturnSuccess) {
            _pool = NULL;
            *status = kVTAllocationFailedErr;
            return NULL;
        }
        _poolWidth = width;
        _poolHeight = height;
    }
    CVPixelBufferRef buffer = NULL;
    if (CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _pool, &buffer) != kCVReturnSuccess) {
        *status = kVTAllocationFailedErr;
        return NULL;
    }
    CVPixelBufferLockBaseAddress(buffer, 0);
    *status = [self fillBuffer:buffer fromPicture:picture];
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    if (*status != noErr) {
        CVPixelBufferRelease(buffer);
        return NULL;
    }
    if (picture->matrix == RevenantVTHEVCMatrixBT709)
        CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
    else if (picture->matrix == RevenantVTHEVCMatrixBT601)
        CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_601_4, kCVAttachmentMode_ShouldPropagate);
    return buffer;
}

- (void)emitPicture:(const RevenantVTHEVCPicture *)picture
{
    if (_invalidated)
        return;
    NSNumber *key = @(picture->sequence);
    RevenantVTPendingFrame *frame = _pending[key];
    if (!frame) {
        _emitStatus = kVTVideoDecoderMalfunctionErr;
        return;
    }
    [_pending removeObjectForKey:key];
    if (frame.suppressed) {
        frame.output(frame.sourceFrameRefCon, noErr, 0, NULL, frame.presentationTimeStamp, frame.presentationDuration);
        return;
    }
    OSStatus status = noErr;
    CVPixelBufferRef buffer = [self pixelBufferForPicture:picture status:&status];
    if (status != noErr) {
        _emitStatus = status;
        frame.output(frame.sourceFrameRefCon, status, 0, NULL, frame.presentationTimeStamp, frame.presentationDuration);
        return;
    }
    frame.output(frame.sourceFrameRefCon, noErr, 0, buffer, frame.presentationTimeStamp, frame.presentationDuration);
    CVPixelBufferRelease(buffer);
}

@end

static void RevenantVTSoftwareEmit(void *context, const RevenantVTHEVCPicture *picture)
{
    [(__bridge RevenantVTSoftwareSession *)context emitPicture:picture];
}

static RevenantVTSoftwareSession *RevenantVTSessionOf(VTDecompressionSessionRef session)
{
    return (__bridge RevenantVTSoftwareSession *)(void *)session;
}

BOOL RevenantVTSoftwareDecodes(CMFormatDescriptionRef format, CFDictionaryRef specification)
{
    return format && CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_HEVC && !RevenantVTRequiresHardware(specification);
}

OSStatus RevenantVTSoftwareSessionCreate(CMVideoFormatDescriptionRef format, CFDictionaryRef destinationAttributes, RevenantVTDecodeOutput output, VTDecompressionSessionRef *sessionOut)
{
    if (!format || !sessionOut)
        return kVTParameterErr;
    if (CMFormatDescriptionGetMediaSubType(format) != kCMVideoCodecType_HEVC)
        return kVTCouldNotFindVideoDecoderErr;
    NSData *configuration = RevenantVTConfiguration(format);
    if (!configuration)
        return kVTParameterErr;
    OSStatus status = RevenantVTConfigurationStatus(configuration);
    if (status != noErr)
        return status;
    const CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format);
    OSType pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    status = RevenantVTPixelFormatOf(destinationAttributes, dimensions, &pixelFormat);
    if (status != noErr)
        return status;
    RevenantVTHEVCResult result = RevenantVTHEVCOK;
    RevenantVTHEVCDecoder *decoder = RevenantVTHEVCDecoderCreate(configuration.bytes, configuration.length, 1, &result);
    if (!decoder)
        return RevenantVTStatusOf(result);
    RevenantVTSoftwareSession *session = [[RevenantVTSoftwareSession alloc] initWithDecoder:decoder dimensions:dimensions pixelFormat:pixelFormat output:output];
    @synchronized (RevenantVTSessionRegistry()) {
        [RevenantVTSessionRegistry() addObject:(__bridge id)(__bridge void *)session];
    }
    *sessionOut = (__bridge_retained VTDecompressionSessionRef)session;
    return noErr;
}

BOOL RevenantVTSoftwareSessionOwns(VTDecompressionSessionRef session)
{
    if (!session)
        return NO;
    @synchronized (RevenantVTSessionRegistry()) {
        return [RevenantVTSessionRegistry() containsObject:(__bridge id)(void *)session];
    }
}

OSStatus RevenantVTSoftwareSessionDecode(VTDecompressionSessionRef session, CMSampleBufferRef sampleBuffer, VTDecodeFrameFlags decodeFlags, void *sourceFrameRefCon, VTDecodeInfoFlags *infoFlagsOut, RevenantVTDecodeOutput output)
{
    return [RevenantVTSessionOf(session) decodeSample:sampleBuffer flags:decodeFlags refcon:sourceFrameRefCon output:output infoFlags:infoFlagsOut];
}

OSStatus RevenantVTSoftwareSessionFinish(VTDecompressionSessionRef session)
{
    return [RevenantVTSessionOf(session) finish];
}

void RevenantVTSoftwareSessionInvalidate(VTDecompressionSessionRef session)
{
    [RevenantVTSessionOf(session) invalidate];
}

BOOL RevenantVTSoftwareSessionCanAccept(VTDecompressionSessionRef session, CMFormatDescriptionRef format)
{
    return [RevenantVTSessionOf(session) canAcceptFormat:format];
}

OSStatus RevenantVTSoftwareSessionSetProperty(VTDecompressionSessionRef session, CFStringRef key, CFTypeRef value)
{
    return [RevenantVTSessionOf(session) setProperty:key value:value];
}

OSStatus RevenantVTSoftwareSessionCopyProperty(VTDecompressionSessionRef session, CFStringRef key, CFAllocatorRef allocator, CFTypeRef *valueOut)
{
    return [RevenantVTSessionOf(session) copyProperty:key allocator:allocator valueOut:valueOut];
}

CFDictionaryRef RevenantVTSoftwareSessionCopySupportedProperties(VTDecompressionSessionRef session)
{
    (void)session;
    NSDictionary *supported = @{(__bridge NSString *)kVTDecompressionPropertyKey_RealTime: @{},
                                (__bridge NSString *)kVTDecompressionPropertyKey_MaximizePowerEfficiency: @{}};
    return (CFDictionaryRef)CFBridgingRetain(supported);
}
