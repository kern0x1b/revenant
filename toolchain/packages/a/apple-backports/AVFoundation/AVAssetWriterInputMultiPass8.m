#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static const char charon_multipass_setting;
static const char charon_multipass_writing;
static const char charon_multipass_description;
static const char charon_multipass_callback;
static const char charon_multipass_queue;
static const char charon_export_multipass;
static const char charon_export_started;

static NSString *const charon_current_pass_key = @"currentPassDescription";

static AVAssetWriterInputPassDescription *charon_first_pass_description(void)
{
    AVAssetWriterInputPassDescription *description = class_createInstance([AVAssetWriterInputPassDescription class], 0);
    static NSArray *ranges;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ranges = @[[NSValue valueWithCMTimeRange:CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)]];
    });
    objc_setAssociatedObject(description, &charon_multipass_description, ranges, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return description;
}

static void charon_will_change_pass(AVAssetWriterInput *input)
{
    [input willChangeValueForKey:charon_current_pass_key];
}

static void charon_did_change_pass(AVAssetWriterInput *input)
{
    [input didChangeValueForKey:charon_current_pass_key];
}

static void charon_begin_pass(AVAssetWriterInput *input)
{
    if (objc_getAssociatedObject(input, &charon_multipass_writing))
        return;
    objc_setAssociatedObject(input, &charon_multipass_writing, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_will_change_pass(input);
    objc_setAssociatedObject(input, &charon_multipass_description, charon_first_pass_description(),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_did_change_pass(input);
}

static void charon_end_pass(AVAssetWriterInput *input)
{
    if (!objc_getAssociatedObject(input, &charon_multipass_description))
        return;
    charon_will_change_pass(input);
    objc_setAssociatedObject(input, &charon_multipass_description, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_did_change_pass(input);
}

static void charon_invoke_pass_callback(AVAssetWriterInput *input)
{
    dispatch_block_t callback = objc_getAssociatedObject(input, &charon_multipass_callback);
    if (callback)
        callback();
}

static void charon_raise(NSString *reason)
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:reason userInfo:nil];
}

@interface AVAssetWriterInput (CharonAVAssetWriterInputMultiPass8)
- (BOOL)performsMultiPassEncodingIfSupported;
- (void)setPerformsMultiPassEncodingIfSupported:(BOOL)performsMultiPassEncodingIfSupported;
- (BOOL)canPerformMultiplePasses;
- (AVAssetWriterInputPassDescription *)currentPassDescription;
- (void)respondToEachPassDescriptionOnQueue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block;
- (void)markCurrentPassAsFinished;
@end

@implementation AVAssetWriterInputPassDescription

- (NSArray *)sourceTimeRanges
{
    NSArray *ranges = objc_getAssociatedObject(self, &charon_multipass_description);
    return ranges ? [ranges copy] : @[];
}

@end

@implementation AVAssetWriterInput (CharonAVAssetWriterInputMultiPass8)

- (BOOL)performsMultiPassEncodingIfSupported
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_multipass_setting);
    return stored ? stored.boolValue : NO;
}

- (void)setPerformsMultiPassEncodingIfSupported:(BOOL)performsMultiPassEncodingIfSupported
{
    if (objc_getAssociatedObject(self, &charon_multipass_writing))
        charon_raise(@"-[AVAssetWriterInput setPerformsMultiPassEncodingIfSupported:] cannot be called after the input's asset writer has started writing");
    objc_setAssociatedObject(self, &charon_multipass_setting, @(performsMultiPassEncodingIfSupported),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)canPerformMultiplePasses
{
    return NO;
}

- (AVAssetWriterInputPassDescription *)currentPassDescription
{
    return objc_getAssociatedObject(self, &charon_multipass_description);
}

- (void)respondToEachPassDescriptionOnQueue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block
{
    if (!objc_getAssociatedObject(self, &charon_multipass_writing))
        charon_raise(@"-[AVAssetWriterInput respondToEachPassDescriptionOnQueue:usingBlock:] cannot be called before the input's asset writer has started writing");
    if (objc_getAssociatedObject(self, &charon_multipass_callback))
        charon_raise(@"-[AVAssetWriterInput respondToEachPassDescriptionOnQueue:usingBlock:] cannot be called more than once on the same input");
    objc_setAssociatedObject(self, &charon_multipass_callback, [block copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &charon_multipass_queue, queue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_async(queue, ^{
        charon_invoke_pass_callback(self);
    });
}

- (void)markCurrentPassAsFinished
{
    if (!objc_getAssociatedObject(self, &charon_multipass_writing))
        charon_raise(@"-[AVAssetWriterInput markCurrentPassAsFinished] cannot be called before the input's asset writer has started writing");
    if (!objc_getAssociatedObject(self, &charon_multipass_description))
        charon_raise(@"-[AVAssetWriterInput markCurrentPassAsFinished] cannot be called when there is no current pass to mark finished");
    charon_end_pass(self);
    dispatch_queue_t queue = objc_getAssociatedObject(self, &charon_multipass_queue);
    if (queue) {
        dispatch_async(queue, ^{
            charon_invoke_pass_callback(self);
        });
    }
}

@end

@interface AVAssetExportSession (CharonAVAssetExportSessionMultipass8)
- (BOOL)canPerformMultiplePassesOverSourceMediaData;
- (void)setCanPerformMultiplePassesOverSourceMediaData:(BOOL)flag;
@end

@implementation AVAssetExportSession (CharonAVAssetExportSessionMultipass8)

- (BOOL)canPerformMultiplePassesOverSourceMediaData
{
    NSNumber *stored = objc_getAssociatedObject(self, &charon_export_multipass);
    return stored ? stored.boolValue : NO;
}

- (void)setCanPerformMultiplePassesOverSourceMediaData:(BOOL)flag
{
    if (objc_getAssociatedObject(self, &charon_export_started))
        charon_raise(@"-[AVAssetExportSession setCanPerformMultiplePassesOverSourceMediaData:] cannot be called after the export has started");
    objc_setAssociatedObject(self, &charon_export_multipass, @(flag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@interface CharonAVAssetWriterInputMultiPass8Installer : NSObject
@end

@implementation CharonAVAssetWriterInputMultiPass8Installer

+ (void)load
{
    Class input = [AVAssetWriterInput class];
    if (class_getInstanceMethod(input, @selector(preferredMediaChunkDuration)))
        return;

    Class writer = [AVAssetWriter class];
    IMP startWriting = class_getMethodImplementation(writer, @selector(startWriting));
    if (startWriting)
        class_replaceMethod(writer, @selector(startWriting),
                            imp_implementationWithBlock(^BOOL(AVAssetWriter *self_) {
            if (!((BOOL (*)(id, SEL))startWriting)(self_, @selector(startWriting)))
                return NO;
            for (AVAssetWriterInput *each in self_.inputs)
                charon_begin_pass(each);
            return YES;
        }), "ccharon_startWriting");

    IMP markAsFinished = class_getMethodImplementation(input, @selector(markAsFinished));
    if (markAsFinished)
        class_replaceMethod(input, @selector(markAsFinished),
                            imp_implementationWithBlock(^(AVAssetWriterInput *self_) {
            ((void (*)(id, SEL))markAsFinished)(self_, @selector(markAsFinished));
            charon_end_pass(self_);
        }), "ccharon_markAsFinished");

    Class session = [AVAssetExportSession class];
    IMP exportAsynchronously = class_getMethodImplementation(session,
                                                             @selector(exportAsynchronouslyWithCompletionHandler:));
    if (exportAsynchronously)
        class_replaceMethod(session, @selector(exportAsynchronouslyWithCompletionHandler:),
                            imp_implementationWithBlock(^(AVAssetExportSession *self_, dispatch_block_t handler) {
            objc_setAssociatedObject(self_, &charon_export_started, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            ((void (*)(id, SEL, id))exportAsynchronously)(self_, @selector(exportAsynchronouslyWithCompletionHandler:), handler);
        }), "ccharon_exportAsynchronouslyWithCompletionHandler");
}

@end
