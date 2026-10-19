#import "CharonMetal.h"


@implementation MTLBlitPassSampleBufferAttachmentDescriptor

- (instancetype)init
{
    if ((self = [super init])) {
        self.startOfEncoderSampleIndex = MTLCounterDontSample;
        self.endOfEncoderSampleIndex = MTLCounterDontSample;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLBlitPassSampleBufferAttachmentDescriptor *copy = [[MTLBlitPassSampleBufferAttachmentDescriptor alloc] init];
    copy.sampleBuffer = self.sampleBuffer;
    copy.startOfEncoderSampleIndex = self.startOfEncoderSampleIndex;
    copy.endOfEncoderSampleIndex = self.endOfEncoderSampleIndex;
    return copy;
}

@end

@implementation MTLBlitPassSampleBufferAttachmentDescriptorArray
{
    NSMutableDictionary<NSNumber *, MTLBlitPassSampleBufferAttachmentDescriptor *> *_attachments;
}

- (instancetype)init
{
    if ((self = [super init]))
        _attachments = [NSMutableDictionary dictionary];
    return self;
}

- (MTLBlitPassSampleBufferAttachmentDescriptor *)objectAtIndexedSubscript:(NSUInteger)attachmentIndex
{
    return _attachments[@(attachmentIndex)] ?: [[MTLBlitPassSampleBufferAttachmentDescriptor alloc] init];
}

- (void)setObject:(MTLBlitPassSampleBufferAttachmentDescriptor *)attachment atIndexedSubscript:(NSUInteger)attachmentIndex
{
    if (attachment)
        _attachments[@(attachmentIndex)] = [attachment copy];
    else
        [_attachments removeObjectForKey:@(attachmentIndex)];
}

@end

@implementation MTLBlitPassDescriptor

+ (MTLBlitPassDescriptor *)blitPassDescriptor
{
    return [[self alloc] init];
}

- (instancetype)init
{
    if ((self = [super init]))
        _sampleBufferAttachments = [[MTLBlitPassSampleBufferAttachmentDescriptorArray alloc] init];
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTLBlitPassDescriptor *copy = [[MTLBlitPassDescriptor alloc] init];
    for (NSUInteger index = 0; index < 4; index++)
        copy.sampleBufferAttachments[index] = self.sampleBufferAttachments[index];
    return copy;
}

@end
