#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

#define REVENANT_ANIMATION_PARAM_ERR (-50)

extern CFStringRef const kCGImageAnimationStartIndex;
extern CFStringRef const kCGImageAnimationDelayTime;
extern CFStringRef const kCGImageAnimationLoopCount;

@interface RevenantImageAnimation : NSObject
- (instancetype)initWithSource:(CGImageSourceRef)source block:(CGImageSourceAnimationBlock)block;
- (OSStatus)runWithOptions:(CFDictionaryRef)options;
@end

@implementation RevenantImageAnimation {
@private
    CGImageSourceRef _source;
    CGImageSourceAnimationBlock _block;
    NSTimer *_timer;
    size_t _count;
    size_t _index;
    size_t _loops;
    size_t _loopsDone;
}

- (instancetype)initWithSource:(CGImageSourceRef)source block:(CGImageSourceAnimationBlock)block
{
    if ((self = [super init])) {
        _source = (CGImageSourceRef)CFRetain(source);
        _block = [block copy];
    }
    return self;
}

- (void)dealloc
{
    if (_source)
        CFRelease(_source);
}

static double revenant_frame_delay(CGImageSourceRef source, size_t index)
{
    NSDictionary *properties =
        (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, index, NULL);
    NSDictionary *gif = properties[(__bridge NSString *)kCGImagePropertyGIFDictionary];
    NSNumber *delay = gif[(__bridge NSString *)kCGImagePropertyGIFDelayTime];
    return delay ? [delay doubleValue] : 0.1;
}

static BOOL revenant_is_animation(CGImageSourceRef source)
{
    if (!source || CGImageSourceGetCount(source) == 0)
        return NO;
    NSDictionary *properties =
        (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    NSDictionary *gif = properties[(__bridge NSString *)kCGImagePropertyGIFDictionary];
    return [gif isKindOfClass:[NSDictionary class]];
}

- (void)drawFrameAtIndex:(size_t)index
{
    CGImageRef image = CGImageSourceCreateImageAtIndex(_source, index, NULL);
    double delay = revenant_frame_delay(_source, index);
    if (!image) {
        [self stop];
        return;
    }
    bool stop = false;
    _block(index, image, &stop);
    CGImageRelease(image);
    if (stop) {
        [self stop];
        return;
    }
    _index = index + 1;
    if (_index >= _count) {
        _index = 0;
        _loopsDone++;
        if (_loops && _loopsDone >= _loops) {
            [self stop];
            return;
        }
    }
    [self armAfter:delay];
}

- (void)step:(NSTimer *)timer
{
    RevenantImageAnimation *alive = self;
    [self drawFrameAtIndex:_index];
    (void)alive;
}

- (void)armAfter:(double)delay
{
    _timer = [NSTimer timerWithTimeInterval:delay target:self selector:@selector(step:) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
}

- (void)stop
{
    [_timer invalidate];
    _timer = nil;
    _block = nil;
    if (_source) {
        CFRelease(_source);
        _source = NULL;
    }
}

- (OSStatus)runWithOptions:(CFDictionaryRef)options
{
    if (!revenant_is_animation(_source))
        return kCGImageAnimationStatus_CorruptInputImage;
    _count = CGImageSourceGetCount(_source);

    NSDictionary *given = (__bridge NSDictionary *)options;
    NSNumber *start = given[(__bridge NSString *)kCGImageAnimationStartIndex];
    NSNumber *loops = given[(__bridge NSString *)kCGImageAnimationLoopCount];
    _index = start ? (size_t)MAX((long)0, [start integerValue]) : 0;
    _loops = loops ? (size_t)MAX((long)0, [loops integerValue]) : 0;
    _loopsDone = 0;

    if (_index >= _count)
        return 0;

    if (_count == 1) {
        _loops = 1;
        [self drawFrameAtIndex:_index];
        return 0;
    }

    [self armAfter:0];
    return 0;
}

@end

static OSStatus revenant_animate(CGImageSourceRef source, CFDictionaryRef options, CGImageSourceAnimationBlock block)
{
    if (!source)
        return REVENANT_ANIMATION_PARAM_ERR;
    if (!block) {
        CFRelease(source);
        return 0;
    }
    RevenantImageAnimation *animation = [[RevenantImageAnimation alloc] initWithSource:source block:block];
    CFRelease(source);
    return [animation runWithOptions:options];
}

OSStatus CGAnimateImageAtURLWithBlock(CFURLRef url, CFDictionaryRef options, CGImageSourceAnimationBlock block)
{
    if (!url)
        return REVENANT_ANIMATION_PARAM_ERR;
    return revenant_animate(CGImageSourceCreateWithURL(url, NULL), options, block);
}

OSStatus CGAnimateImageDataWithBlock(CFDataRef data, CFDictionaryRef options, CGImageSourceAnimationBlock block)
{
    if (!data)
        return REVENANT_ANIMATION_PARAM_ERR;
    return revenant_animate(CGImageSourceCreateWithData(data, NULL), options, block);
}
