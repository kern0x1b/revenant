#import "RevenantMetalBinaryArchive.h"

#pragma clang diagnostic ignored "-Wprotocol"

static NSString *const RevenantMetalBinaryArchiveFormat = @"RevenantMetalBinaryArchive";
static NSInteger const RevenantMetalBinaryArchiveVersion = 1;

static NSError *RevenantMetalBinaryArchiveError(MTLBinaryArchiveError code, NSString *message, NSError *underlying)
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
    if (underlying) {
        userInfo[NSUnderlyingErrorKey] = underlying;
    }
    return [NSError errorWithDomain:MTLBinaryArchiveDomain code:code userInfo:userInfo];
}

@implementation RevenantMetalBinaryArchive {
    id<MTLDevice> _device;
    NSString *_label;
    NSMutableOrderedSet<NSDictionary *> *_pipelines;
}

@synthesize label = _label;

- (instancetype)initWithDevice:(id<MTLDevice>)device descriptor:(MTLBinaryArchiveDescriptor *)descriptor error:(NSError **)error
{
    if ((self = [super init])) {
        _device = device;
        _pipelines = [NSMutableOrderedSet orderedSet];
        if (descriptor.url && ![self loadFromURL:descriptor.url error:error]) {
            return nil;
        }
    }
    return self;
}

- (id<MTLDevice>)device
{
    return _device;
}

- (BOOL)loadFromURL:(NSURL *)url error:(NSError **)error
{
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&readError];
    if (!data) {
        if (error)
            *error = RevenantMetalBinaryArchiveError(MTLBinaryArchiveErrorInvalidFile, @"Invalid URL", readError);
        return NO;
    }
    id document = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
    if (![document isKindOfClass:[NSDictionary class]]) {
        document = nil;
    }
    NSArray *pipelines = document[@"pipelines"];
    if (!document ||
        ![document[@"format"] isEqual:RevenantMetalBinaryArchiveFormat] ||
        [document[@"version"] integerValue] != RevenantMetalBinaryArchiveVersion ||
        ![pipelines isKindOfClass:[NSArray class]]) {
        if (error)
            *error = RevenantMetalBinaryArchiveError(MTLBinaryArchiveErrorInvalidFile, [NSString stringWithFormat:@"The file %@ has an invalid format.", url], nil);
        return NO;
    }
    for (NSDictionary *pipeline in pipelines) {
        if (![pipeline isKindOfClass:[NSDictionary class]]) {
            if (error)
                *error = RevenantMetalBinaryArchiveError(MTLBinaryArchiveErrorUnexpectedElement, [NSString stringWithFormat:@"The file %@ holds an element that is not a pipeline.", url], nil);
            return NO;
        }
        [_pipelines addObject:pipeline];
    }
    return YES;
}

- (BOOL)addPipeline:(NSDictionary *)pipeline error:(NSError **)error
{
    [_pipelines addObject:pipeline];
    return YES;
}

- (BOOL)addComputePipelineFunctionsWithDescriptor:(MTLComputePipelineDescriptor *)descriptor error:(NSError **)error
{
    if (!descriptor.computeFunction) {
        if (error)
            *error = RevenantMetalBinaryArchiveError(MTLBinaryArchiveErrorUnexpectedElement, @"The compute pipeline descriptor has no compute function.", nil);
        return NO;
    }
    return [self addPipeline:@{@"kind": @"compute", @"compute": descriptor.computeFunction.name} error:error];
}

- (BOOL)addRenderPipelineFunctionsWithDescriptor:(MTLRenderPipelineDescriptor *)descriptor error:(NSError **)error
{
    if (!descriptor.vertexFunction) {
        if (error)
            *error = RevenantMetalBinaryArchiveError(MTLBinaryArchiveErrorUnexpectedElement, @"The render pipeline descriptor has no vertex function.", nil);
        return NO;
    }
    NSMutableDictionary *pipeline = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"render", @"kind", descriptor.vertexFunction.name, @"vertex", nil];
    if (descriptor.fragmentFunction) {
        pipeline[@"fragment"] = descriptor.fragmentFunction.name;
    }
    return [self addPipeline:pipeline error:error];
}

- (BOOL)serializeToURL:(NSURL *)url error:(NSError **)error
{
    NSDictionary *document = @{@"format": RevenantMetalBinaryArchiveFormat,
                               @"version": @(RevenantMetalBinaryArchiveVersion),
                               @"pipelines": _pipelines.array};
    NSError *serializeError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:document format:NSPropertyListBinaryFormat_v1_0 options:0 error:&serializeError];
    if (!data) {
        if (error)
            *error = RevenantMetalBinaryArchiveError(MTLBinaryArchiveErrorInternalError, @"The archive could not be encoded.", serializeError);
        return NO;
    }
    NSError *writeError = nil;
    if (![data writeToURL:url options:NSDataWritingAtomic error:&writeError]) {
        if (error)
            *error = RevenantMetalBinaryArchiveError(MTLBinaryArchiveErrorInvalidFile, @"Invalid URL", writeError);
        return NO;
    }
    return YES;
}

@end
