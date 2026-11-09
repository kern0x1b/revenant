#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static NSArray<NSNumber *> *revenant_audio_file_types(AudioFilePropertyID property, NSString *specifier)
{
    if (!specifier.length)
        return @[];
    CFStringRef text = (__bridge CFStringRef)specifier;
    UInt32 size = 0;
    if (AudioFileGetGlobalInfoSize(property, sizeof(text), &text, &size) != noErr || size == 0)
        return @[];
    UInt32 *types = malloc(size);
    NSMutableArray<NSNumber *> *found = [NSMutableArray array];
    if (AudioFileGetGlobalInfo(property, sizeof(text), &text, &size, types) == noErr) {
        for (UInt32 index = 0; index < size / sizeof(UInt32); index++)
            [found addObject:@(types[index])];
    }
    free(types);
    return found;
}

static BOOL revenant_hint_overrides_extension(NSURL *url, NSString *hint)
{
    if (!url.isFileURL)
        return NO;
    NSArray<NSNumber *> *hinted = revenant_audio_file_types(kAudioFileGlobalInfo_TypesForUTI, hint);
    NSArray<NSNumber *> *named = revenant_audio_file_types(kAudioFileGlobalInfo_TypesForExtension, url.pathExtension);
    if (hinted.count == 0 || named.count == 0)
        return NO;
    for (NSNumber *type in named) {
        if ([hinted containsObject:type])
            return NO;
    }
    return YES;
}

@implementation AVAudioPlayer (RevenantFileTypeHint7)

- (instancetype)initWithContentsOfURL:(NSURL *)url fileTypeHint:(NSString *)utiString error:(NSError **)outError
{
    if (revenant_hint_overrides_extension(url, utiString)) {
        NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:NULL];
        if (data)
            return [self initWithData:data error:outError];
    }
    return [self initWithContentsOfURL:url error:outError];
}

- (instancetype)initWithData:(NSData *)data fileTypeHint:(NSString *)utiString error:(NSError **)outError
{
    return [self initWithData:data error:outError];
}

@end
