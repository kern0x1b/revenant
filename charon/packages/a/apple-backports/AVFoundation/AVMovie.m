#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

__attribute__((objc_runtime_name("AVMovie")))
@interface CharonMovie : AVAsset
@end

__attribute__((objc_runtime_name("AVMovieTrack")))
@interface CharonMovieTrack : AVAssetTrack
- (instancetype)initWithAssetTrack:(AVAssetTrack *)track movie:(CharonMovie *)movie;
@end

@interface CharonMovie ()
- (NSArray<AVAssetTrack *> *)charonTracks;
- (NSURL *)charonFileURL;
@end

#define CHARON_FOURCC(a, b, c, d) (((uint32_t)(a) << 24) | ((uint32_t)(b) << 16) | ((uint32_t)(c) << 8) | (uint32_t)(d))

typedef struct {
    int32_t trackID;
    uint16_t alternateGroup;
    uint32_t timescale;
    int64_t decodeDuration;
    int64_t presentationStart;
    int64_t presentationEnd;
} CharonTrackHeader;

static uint32_t charonBE32(const uint8_t *p) { return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3]; }
static uint64_t charonBE64(const uint8_t *p) { return ((uint64_t)charonBE32(p) << 32) | charonBE32(p + 4); }

static BOOL charonBox(const uint8_t *base, uint64_t begin, uint64_t end, uint32_t *type, uint64_t *payload, uint64_t *payloadEnd, uint64_t *next)
{
    if (begin + 8 > end)
        return NO;
    uint64_t size = charonBE32(base + begin), header = 8;
    if (size == 1) {
        if (begin + 16 > end)
            return NO;
        size = charonBE64(base + begin + 8);
        header = 16;
    } else if (size == 0) {
        size = end - begin;
    }
    if (size < header || size > end - begin)
        return NO;
    *type = charonBE32(base + begin + 4);
    *payload = begin + header;
    *payloadEnd = begin + size;
    *next = begin + size;
    return YES;
}

static BOOL charonChild(const uint8_t *base, uint64_t begin, uint64_t end, uint32_t wanted, uint64_t *payload, uint64_t *payloadEnd)
{
    uint64_t at = begin;
    while (at < end) {
        uint32_t type;
        uint64_t next;
        if (!charonBox(base, at, end, &type, payload, payloadEnd, &next))
            return NO;
        if (type == wanted)
            return YES;
        at = next;
    }
    return NO;
}

static BOOL charonReadTrackHeader(NSData *data, int32_t trackID, CharonTrackHeader *out)
{
    const uint8_t *base = data.bytes;
    uint64_t moov, moovEnd;
    if (!charonChild(base, 0, data.length, CHARON_FOURCC('m', 'o', 'o', 'v'), &moov, &moovEnd))
        return NO;
    uint64_t at = moov;
    while (at < moovEnd) {
        uint32_t type;
        uint64_t trak, trakEnd, next;
        if (!charonBox(base, at, moovEnd, &type, &trak, &trakEnd, &next))
            return NO;
        at = next;
        if (type != CHARON_FOURCC('t', 'r', 'a', 'k'))
            continue;
        uint64_t tkhd, tkhdEnd;
        if (!charonChild(base, trak, trakEnd, CHARON_FOURCC('t', 'k', 'h', 'd'), &tkhd, &tkhdEnd) || tkhd + 4 > tkhdEnd)
            continue;
        BOOL v1 = base[tkhd] == 1;
        uint64_t idAt = tkhd + (v1 ? 20 : 12);
        if (idAt + 4 > tkhdEnd || (int32_t)charonBE32(base + idAt) != trackID)
            continue;
        uint64_t altAt = tkhd + (v1 ? 46 : 34);
        if (altAt + 2 > tkhdEnd)
            return NO;
        out->trackID = trackID;
        out->alternateGroup = (uint16_t)((base[altAt] << 8) | base[altAt + 1]);

        uint64_t mdia, mdiaEnd, mdhd, mdhdEnd, minf, minfEnd, stbl, stblEnd, stts, sttsEnd;
        if (!charonChild(base, trak, trakEnd, CHARON_FOURCC('m', 'd', 'i', 'a'), &mdia, &mdiaEnd) ||
            !charonChild(base, mdia, mdiaEnd, CHARON_FOURCC('m', 'd', 'h', 'd'), &mdhd, &mdhdEnd) ||
            !charonChild(base, mdia, mdiaEnd, CHARON_FOURCC('m', 'i', 'n', 'f'), &minf, &minfEnd) ||
            !charonChild(base, minf, minfEnd, CHARON_FOURCC('s', 't', 'b', 'l'), &stbl, &stblEnd) ||
            !charonChild(base, stbl, stblEnd, CHARON_FOURCC('s', 't', 't', 's'), &stts, &sttsEnd))
            return NO;
        if (mdhd + 4 > mdhdEnd)
            return NO;
        uint64_t tsAt = mdhd + (base[mdhd] == 1 ? 20 : 12);
        if (tsAt + 4 > mdhdEnd)
            return NO;
        out->timescale = charonBE32(base + tsAt);

        if (stts + 8 > sttsEnd)
            return NO;
        uint32_t entries = charonBE32(base + stts + 4);
        if (stts + 8 + 8ull * entries > sttsEnd)
            return NO;

        uint64_t ctts = 0, cttsEnd = 0;
        BOOL hasCtts = charonChild(base, stbl, stblEnd, CHARON_FOURCC('c', 't', 't', 's'), &ctts, &cttsEnd);
        uint32_t ctsEntries = 0;
        if (hasCtts) {
            if (ctts + 8 > cttsEnd)
                return NO;
            ctsEntries = charonBE32(base + ctts + 4);
            if (ctts + 8 + 8ull * ctsEntries > cttsEnd)
                return NO;
        }
        int64_t decode = 0, presentationStart = INT64_MAX, presentationEnd = INT64_MIN;
        uint32_t run = 0;
        uint32_t left = ctsEntries ? charonBE32(base + ctts + 8) : 0;
        int64_t offset = ctsEntries ? (int32_t)charonBE32(base + ctts + 12) : 0;
        for (uint32_t i = 0; i < entries; i++) {
            uint32_t count = charonBE32(base + stts + 8 + 8ull * i);
            int64_t delta = charonBE32(base + stts + 12 + 8ull * i);
            for (uint32_t s = 0; s < count; s++) {
                if (hasCtts) {
                    while (left == 0 && run + 1 < ctsEntries) {
                        run++;
                        left = charonBE32(base + ctts + 8 + 8ull * run);
                        offset = (int32_t)charonBE32(base + ctts + 12 + 8ull * run);
                    }
                    if (left > 0)
                        left--;
                }
                int64_t shown = decode + (hasCtts ? offset : 0);
                if (shown < presentationStart)
                    presentationStart = shown;
                if (shown + delta > presentationEnd)
                    presentationEnd = shown + delta;
                decode += delta;
            }
        }
        out->decodeDuration = decode;
        out->presentationStart = decode > 0 ? presentationStart : 0;
        out->presentationEnd = decode > 0 ? presentationEnd : 0;
        return YES;
    }
    return NO;
}

@implementation CharonMovie
{
    NSURL *_charonURL;
    NSData *_charonData;
    NSURL *_charonTemporaryURL;
    AVURLAsset *_charonAsset;
    NSArray<AVAssetTrack *> *_charonTracks;
}

+ (NSArray<AVFileType> *)movieTypes
{
    return @[@"com.apple.m4a-audio", @"com.apple.m4v-video", @"com.apple.quicktime-audio", @"com.apple.quicktime-movie",
             @"public.3gpp", @"public.mpeg-4"];
}

+ (instancetype)movieWithURL:(NSURL *)URL options:(NSDictionary<NSString *, id> *)options
{
    return [[self alloc] initWithURL:URL options:options];
}

+ (instancetype)movieWithData:(NSData *)data options:(NSDictionary<NSString *, id> *)options
{
    return [[self alloc] initWithData:data options:options];
}

- (instancetype)initWithURL:(NSURL *)URL options:(NSDictionary<NSString *, id> *)options
{
    if (!URL)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"AVMovie: a movie opened from a URL needs that URL, and it is nil" userInfo:nil];
    if ((self = [super init])) {
        _charonURL = URL;
        _charonAsset = [[AVURLAsset alloc] initWithURL:URL options:options];
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data options:(NSDictionary<NSString *, id> *)options
{
    if (!data || data.length == 0)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"AVMovie: a movie opened from data needs that data, and it is nil or empty" userInfo:nil];
    if ((self = [super init])) {
        NSString *name = [NSString stringWithFormat:@"charon-movie-%@.mov", [[NSUUID UUID] UUIDString]];
        NSURL *URL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
        NSError *error = nil;
        if (![data writeToURL:URL options:NSDataWritingAtomic error:&error]) {
            NSLog(@"AVMovie: the movie data could not be written to %@: %@", URL.path, error);
            return nil;
        }
        _charonData = data;
        _charonTemporaryURL = URL;
        _charonAsset = [[AVURLAsset alloc] initWithURL:URL options:options];
    }
    return self;
}

- (void)dealloc
{
    if (_charonTemporaryURL)
        [[NSFileManager defaultManager] removeItemAtURL:_charonTemporaryURL error:nil];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSURL *)URL
{
    return _charonURL;
}

- (NSData *)data
{
    return _charonData;
}

- (NSURL *)charonFileURL
{
    return _charonURL ?: _charonTemporaryURL;
}

- (AVMediaDataStorage *)defaultMediaDataStorage
{
    return nil;
}

- (BOOL)canContainMovieFragments
{
    return NO;
}

- (BOOL)containsMovieFragments
{
    return NO;
}

- (BOOL)isCompatibleWithFileType:(AVFileType)fileType
{
    static NSSet<AVFileType> *types;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        types = [NSSet setWithObjects:AVFileTypeQuickTimeMovie, AVFileTypeMPEG4, @"com.apple.m4v-video", @"public.3gpp",
                                      @"com.apple.quicktime-audio", nil];
    });
    return [types containsObject:fileType];
}

- (NSArray<AVAssetTrack *> *)charonTracks
{
    if (!_charonTracks) {
        NSMutableArray<AVAssetTrack *> *tracks = [NSMutableArray array];
        for (AVAssetTrack *track in _charonAsset.tracks)
            [tracks addObject:[[CharonMovieTrack alloc] initWithAssetTrack:track movie:self]];
        _charonTracks = [tracks copy];
    }
    return _charonTracks;
}

- (NSArray<AVAssetTrack *> *)tracks
{
    return [self charonTracks];
}

- (AVAssetTrack *)trackWithTrackID:(CMPersistentTrackID)trackID
{
    for (AVAssetTrack *track in [self charonTracks])
        if (track.trackID == trackID)
            return track;
    return nil;
}

- (NSArray<AVAssetTrack *> *)tracksWithMediaType:(AVMediaType)mediaType
{
    NSMutableArray<AVAssetTrack *> *tracks = [NSMutableArray array];
    for (AVAssetTrack *track in [self charonTracks])
        if ([track.mediaType isEqualToString:mediaType])
            [tracks addObject:track];
    return tracks;
}

- (NSArray<AVAssetTrack *> *)tracksWithMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic
{
    NSMutableArray<AVAssetTrack *> *tracks = [NSMutableArray array];
    for (AVAssetTrack *track in [self charonTracks])
        if ([track hasMediaCharacteristic:mediaCharacteristic])
            [tracks addObject:track];
    return tracks;
}

- (CMTime)duration
{
    return _charonAsset ? _charonAsset.duration : CMTimeMake(0, 600);
}

- (float)preferredRate
{
    return _charonAsset.preferredRate;
}

- (float)preferredVolume
{
    return _charonAsset.preferredVolume;
}

- (CGAffineTransform)preferredTransform
{
    return _charonAsset.preferredTransform;
}

- (CGSize)naturalSize
{
    return _charonAsset.naturalSize;
}

- (BOOL)providesPreciseDurationAndTiming
{
    return _charonAsset.providesPreciseDurationAndTiming;
}

- (AVAssetReferenceRestrictions)referenceRestrictions
{
    return AVAssetReferenceRestrictionForbidLocalReferenceToRemote;
}


- (void)cancelLoading
{
    [_charonAsset cancelLoading];
}

- (NSArray<AVAssetTrackGroup *> *)trackGroups
{
    return _charonAsset.trackGroups ?: @[];
}

- (AVMetadataItem *)creationDate
{
    return _charonAsset.creationDate;
}

- (NSString *)lyrics
{
    return _charonAsset.lyrics;
}

- (NSArray<AVMetadataItem *> *)commonMetadata
{
    return _charonAsset.commonMetadata ?: @[];
}

- (NSArray<AVMetadataFormat> *)availableMetadataFormats
{
    return _charonAsset.availableMetadataFormats ?: @[];
}

- (NSArray<AVMetadataItem *> *)metadataForFormat:(AVMetadataFormat)format
{
    return [_charonAsset metadataForFormat:format] ?: @[];
}

- (NSArray<NSLocale *> *)availableChapterLocales
{
    return _charonAsset.availableChapterLocales ?: @[];
}

- (NSArray<AVTimedMetadataGroup *> *)chapterMetadataGroupsWithTitleLocale:(NSLocale *)locale containingItemsWithCommonKeys:(NSArray<AVMetadataKey> *)commonKeys
{
    return [_charonAsset chapterMetadataGroupsWithTitleLocale:locale containingItemsWithCommonKeys:commonKeys] ?: @[];
}

- (NSArray<AVTimedMetadataGroup *> *)chapterMetadataGroupsBestMatchingPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
{
    return [_charonAsset chapterMetadataGroupsBestMatchingPreferredLanguages:preferredLanguages] ?: @[];
}

- (NSArray<AVMediaCharacteristic> *)availableMediaCharacteristicsWithMediaSelectionOptions
{
    return _charonAsset.availableMediaCharacteristicsWithMediaSelectionOptions ?: @[];
}

- (AVMediaSelectionGroup *)mediaSelectionGroupForMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic
{
    return [_charonAsset mediaSelectionGroupForMediaCharacteristic:mediaCharacteristic];
}

- (BOOL)hasProtectedContent
{
    return _charonAsset.hasProtectedContent;
}

- (BOOL)isPlayable
{
    return _charonAsset.playable;
}

- (BOOL)isExportable
{
    return _charonAsset.exportable;
}

- (BOOL)isReadable
{
    return _charonAsset.readable;
}

- (BOOL)isComposable
{
    return _charonAsset.composable;
}

- (BOOL)isCompatibleWithSavedPhotosAlbum
{
    return _charonAsset.compatibleWithSavedPhotosAlbum;
}

- (AVKeyValueStatus)statusOfValueForKey:(NSString *)key error:(NSError * _Nullable __autoreleasing *)outError
{
    return [_charonAsset statusOfValueForKey:key error:outError];
}

- (void)loadValuesAsynchronouslyForKeys:(NSArray<NSString *> *)keys completionHandler:(void (^)(void))handler
{
    if (_charonAsset) {
        [_charonAsset loadValuesAsynchronouslyForKeys:keys completionHandler:handler];
        return;
    }
    if (handler)
        dispatch_async(dispatch_get_main_queue(), handler);
}

@end

@implementation CharonMovieTrack
{
    AVAssetTrack *_charonTrack;
    __weak CharonMovie *_charonMovie;
    CharonTrackHeader _charonHeader;
    BOOL _charonHasHeader;
}

- (instancetype)initWithAssetTrack:(AVAssetTrack *)track movie:(CharonMovie *)movie
{
    struct objc_super parent = {self, [NSObject class]};
    if ((self = ((id (*)(struct objc_super *, SEL))objc_msgSendSuper)(&parent, @selector(init)))) {
        _charonTrack = track;
        _charonMovie = movie;
        NSURL *file = [movie charonFileURL];
        if (file.isFileURL) {
            NSData *data = [NSData dataWithContentsOfURL:file options:NSDataReadingMappedIfSafe error:nil];
            _charonHasHeader = data && charonReadTrackHeader(data, track.trackID, &_charonHeader);
        }
    }
    return self;
}

- (AVAsset *)asset
{
    return _charonMovie;
}

- (NSArray<AVMetadataItem *> *)commonMetadata
{
    return _charonTrack.commonMetadata;
}

- (NSArray<AVMetadataFormat> *)availableMetadataFormats
{
    return _charonTrack.availableMetadataFormats;
}

- (NSArray<AVMetadataItem *> *)metadataForFormat:(AVMetadataFormat)format
{
    return [_charonTrack metadataForFormat:format];
}

- (float)estimatedDataRate
{
    return _charonTrack.estimatedDataRate;
}

- (NSString *)extendedLanguageTag
{
    return _charonTrack.extendedLanguageTag;
}

- (NSArray *)formatDescriptions
{
    return _charonTrack.formatDescriptions;
}

- (BOOL)hasMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic
{
    return [_charonTrack hasMediaCharacteristic:mediaCharacteristic];
}

- (BOOL)isEnabled
{
    return _charonTrack.enabled;
}

- (BOOL)isPlayable
{
    return _charonTrack.playable;
}

- (BOOL)isSelfContained
{
    return _charonTrack.selfContained;
}

- (NSString *)languageCode
{
    return _charonTrack.languageCode;
}

- (AVMediaType)mediaType
{
    return _charonTrack.mediaType;
}

- (CGSize)naturalSize
{
    return _charonTrack.naturalSize;
}

- (CMTimeScale)naturalTimeScale
{
    return _charonTrack.naturalTimeScale;
}

- (float)nominalFrameRate
{
    return _charonTrack.nominalFrameRate;
}

- (CGAffineTransform)preferredTransform
{
    return _charonTrack.preferredTransform;
}

- (float)preferredVolume
{
    return _charonTrack.preferredVolume;
}

- (CMTime)samplePresentationTimeForTrackTime:(CMTime)trackTime
{
    return [_charonTrack samplePresentationTimeForTrackTime:trackTime];
}

- (AVAssetTrackSegment *)segmentForTrackTime:(CMTime)trackTime
{
    return [_charonTrack segmentForTrackTime:trackTime];
}

- (NSArray<AVAssetTrackSegment *> *)segments
{
    return _charonTrack.segments;
}

- (AVKeyValueStatus)statusOfValueForKey:(NSString *)key error:(NSError * _Nullable __autoreleasing *)outError
{
    return [_charonTrack statusOfValueForKey:key error:outError];
}

- (void)loadValuesAsynchronouslyForKeys:(NSArray<NSString *> *)keys completionHandler:(void (^)(void))handler
{
    [_charonTrack loadValuesAsynchronouslyForKeys:keys completionHandler:handler];
}

- (CMTimeRange)timeRange
{
    return _charonTrack.timeRange;
}

- (long long)totalSampleDataLength
{
    return _charonTrack.totalSampleDataLength;
}

- (CMPersistentTrackID)trackID
{
    return _charonTrack.trackID;
}

- (BOOL)charonHeader:(CharonTrackHeader *)header
{
    if (!_charonHasHeader)
        return NO;
    *header = _charonHeader;
    return YES;
}

- (CMTimeRange)mediaPresentationTimeRange
{
    CharonTrackHeader header;
    if (![self charonHeader:&header] || header.timescale == 0)
        return kCMTimeRangeInvalid;
    return CMTimeRangeMake(CMTimeMake(header.presentationStart, header.timescale),
                           CMTimeMake(header.presentationEnd - header.presentationStart, header.timescale));
}

- (CMTimeRange)mediaDecodeTimeRange
{
    CharonTrackHeader header;
    if (![self charonHeader:&header] || header.timescale == 0)
        return kCMTimeRangeInvalid;
    return CMTimeRangeMake(CMTimeMake(0, header.timescale), CMTimeMake(header.decodeDuration, header.timescale));
}

- (NSInteger)alternateGroupID
{
    CharonTrackHeader header;
    return [self charonHeader:&header] ? header.alternateGroup : 0;
}

- (AVMediaDataStorage *)mediaDataStorage
{
    return nil;
}

@end
