#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

__attribute__((objc_runtime_name("AVMovie")))
@interface RevenantMovie : AVAsset
@end

__attribute__((objc_runtime_name("AVMovieTrack")))
@interface RevenantMovieTrack : AVAssetTrack
- (instancetype)initWithAssetTrack:(AVAssetTrack *)track movie:(RevenantMovie *)movie;
@end

@interface RevenantMovie ()
- (NSArray<AVAssetTrack *> *)revenantTracks;
- (NSURL *)revenantFileURL;
@end

#define REVENANT_FOURCC(a, b, c, d) (((uint32_t)(a) << 24) | ((uint32_t)(b) << 16) | ((uint32_t)(c) << 8) | (uint32_t)(d))

typedef struct {
    int32_t trackID;
    uint16_t alternateGroup;
    uint32_t timescale;
    int64_t decodeDuration;
    int64_t presentationStart;
    int64_t presentationEnd;
} RevenantTrackHeader;

static uint32_t revenantBE32(const uint8_t *p) { return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3]; }
static uint64_t revenantBE64(const uint8_t *p) { return ((uint64_t)revenantBE32(p) << 32) | revenantBE32(p + 4); }

static BOOL revenantBox(const uint8_t *base, uint64_t begin, uint64_t end, uint32_t *type, uint64_t *payload, uint64_t *payloadEnd, uint64_t *next)
{
    if (begin + 8 > end)
        return NO;
    uint64_t size = revenantBE32(base + begin), header = 8;
    if (size == 1) {
        if (begin + 16 > end)
            return NO;
        size = revenantBE64(base + begin + 8);
        header = 16;
    } else if (size == 0) {
        size = end - begin;
    }
    if (size < header || size > end - begin)
        return NO;
    *type = revenantBE32(base + begin + 4);
    *payload = begin + header;
    *payloadEnd = begin + size;
    *next = begin + size;
    return YES;
}

static BOOL revenantChild(const uint8_t *base, uint64_t begin, uint64_t end, uint32_t wanted, uint64_t *payload, uint64_t *payloadEnd)
{
    uint64_t at = begin;
    while (at < end) {
        uint32_t type;
        uint64_t next;
        if (!revenantBox(base, at, end, &type, payload, payloadEnd, &next))
            return NO;
        if (type == wanted)
            return YES;
        at = next;
    }
    return NO;
}

static BOOL revenantReadTrackHeader(NSData *data, int32_t trackID, RevenantTrackHeader *out)
{
    const uint8_t *base = data.bytes;
    uint64_t moov, moovEnd;
    if (!revenantChild(base, 0, data.length, REVENANT_FOURCC('m', 'o', 'o', 'v'), &moov, &moovEnd))
        return NO;
    uint64_t at = moov;
    while (at < moovEnd) {
        uint32_t type;
        uint64_t trak, trakEnd, next;
        if (!revenantBox(base, at, moovEnd, &type, &trak, &trakEnd, &next))
            return NO;
        at = next;
        if (type != REVENANT_FOURCC('t', 'r', 'a', 'k'))
            continue;
        uint64_t tkhd, tkhdEnd;
        if (!revenantChild(base, trak, trakEnd, REVENANT_FOURCC('t', 'k', 'h', 'd'), &tkhd, &tkhdEnd) || tkhd + 4 > tkhdEnd)
            continue;
        BOOL v1 = base[tkhd] == 1;
        uint64_t idAt = tkhd + (v1 ? 20 : 12);
        if (idAt + 4 > tkhdEnd || (int32_t)revenantBE32(base + idAt) != trackID)
            continue;
        uint64_t altAt = tkhd + (v1 ? 46 : 34);
        if (altAt + 2 > tkhdEnd)
            return NO;
        out->trackID = trackID;
        out->alternateGroup = (uint16_t)((base[altAt] << 8) | base[altAt + 1]);

        uint64_t mdia, mdiaEnd, mdhd, mdhdEnd, minf, minfEnd, stbl, stblEnd, stts, sttsEnd;
        if (!revenantChild(base, trak, trakEnd, REVENANT_FOURCC('m', 'd', 'i', 'a'), &mdia, &mdiaEnd) ||
            !revenantChild(base, mdia, mdiaEnd, REVENANT_FOURCC('m', 'd', 'h', 'd'), &mdhd, &mdhdEnd) ||
            !revenantChild(base, mdia, mdiaEnd, REVENANT_FOURCC('m', 'i', 'n', 'f'), &minf, &minfEnd) ||
            !revenantChild(base, minf, minfEnd, REVENANT_FOURCC('s', 't', 'b', 'l'), &stbl, &stblEnd) ||
            !revenantChild(base, stbl, stblEnd, REVENANT_FOURCC('s', 't', 't', 's'), &stts, &sttsEnd))
            return NO;
        if (mdhd + 4 > mdhdEnd)
            return NO;
        uint64_t tsAt = mdhd + (base[mdhd] == 1 ? 20 : 12);
        if (tsAt + 4 > mdhdEnd)
            return NO;
        out->timescale = revenantBE32(base + tsAt);

        if (stts + 8 > sttsEnd)
            return NO;
        uint32_t entries = revenantBE32(base + stts + 4);
        if (stts + 8 + 8ull * entries > sttsEnd)
            return NO;

        uint64_t ctts = 0, cttsEnd = 0;
        BOOL hasCtts = revenantChild(base, stbl, stblEnd, REVENANT_FOURCC('c', 't', 't', 's'), &ctts, &cttsEnd);
        uint32_t ctsEntries = 0;
        if (hasCtts) {
            if (ctts + 8 > cttsEnd)
                return NO;
            ctsEntries = revenantBE32(base + ctts + 4);
            if (ctts + 8 + 8ull * ctsEntries > cttsEnd)
                return NO;
        }
        int64_t decode = 0, presentationStart = INT64_MAX, presentationEnd = INT64_MIN;
        uint32_t run = 0;
        uint32_t left = ctsEntries ? revenantBE32(base + ctts + 8) : 0;
        int64_t offset = ctsEntries ? (int32_t)revenantBE32(base + ctts + 12) : 0;
        for (uint32_t i = 0; i < entries; i++) {
            uint32_t count = revenantBE32(base + stts + 8 + 8ull * i);
            int64_t delta = revenantBE32(base + stts + 12 + 8ull * i);
            for (uint32_t s = 0; s < count; s++) {
                if (hasCtts) {
                    while (left == 0 && run + 1 < ctsEntries) {
                        run++;
                        left = revenantBE32(base + ctts + 8 + 8ull * run);
                        offset = (int32_t)revenantBE32(base + ctts + 12 + 8ull * run);
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

@implementation RevenantMovie
{
    NSURL *_revenantURL;
    NSData *_revenantData;
    NSURL *_revenantTemporaryURL;
    AVURLAsset *_revenantAsset;
    NSArray<AVAssetTrack *> *_revenantTracks;
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
        _revenantURL = URL;
        _revenantAsset = [[AVURLAsset alloc] initWithURL:URL options:options];
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data options:(NSDictionary<NSString *, id> *)options
{
    if (!data || data.length == 0)
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"AVMovie: a movie opened from data needs that data, and it is nil or empty" userInfo:nil];
    if ((self = [super init])) {
        NSString *name = [NSString stringWithFormat:@"revenant-movie-%@.mov", [[NSUUID UUID] UUIDString]];
        NSURL *URL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
        NSError *error = nil;
        if (![data writeToURL:URL options:NSDataWritingAtomic error:&error]) {
            NSLog(@"AVMovie: the movie data could not be written to %@: %@", URL.path, error);
            return nil;
        }
        _revenantData = data;
        _revenantTemporaryURL = URL;
        _revenantAsset = [[AVURLAsset alloc] initWithURL:URL options:options];
    }
    return self;
}

- (void)dealloc
{
    if (_revenantTemporaryURL)
        [[NSFileManager defaultManager] removeItemAtURL:_revenantTemporaryURL error:nil];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSURL *)URL
{
    return _revenantURL;
}

- (NSData *)data
{
    return _revenantData;
}

- (NSURL *)revenantFileURL
{
    return _revenantURL ?: _revenantTemporaryURL;
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

- (NSArray<AVAssetTrack *> *)revenantTracks
{
    if (!_revenantTracks) {
        NSMutableArray<AVAssetTrack *> *tracks = [NSMutableArray array];
        for (AVAssetTrack *track in _revenantAsset.tracks)
            [tracks addObject:[[RevenantMovieTrack alloc] initWithAssetTrack:track movie:self]];
        _revenantTracks = [tracks copy];
    }
    return _revenantTracks;
}

- (NSArray<AVAssetTrack *> *)tracks
{
    return [self revenantTracks];
}

- (AVAssetTrack *)trackWithTrackID:(CMPersistentTrackID)trackID
{
    for (AVAssetTrack *track in [self revenantTracks])
        if (track.trackID == trackID)
            return track;
    return nil;
}

- (NSArray<AVAssetTrack *> *)tracksWithMediaType:(AVMediaType)mediaType
{
    NSMutableArray<AVAssetTrack *> *tracks = [NSMutableArray array];
    for (AVAssetTrack *track in [self revenantTracks])
        if ([track.mediaType isEqualToString:mediaType])
            [tracks addObject:track];
    return tracks;
}

- (NSArray<AVAssetTrack *> *)tracksWithMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic
{
    NSMutableArray<AVAssetTrack *> *tracks = [NSMutableArray array];
    for (AVAssetTrack *track in [self revenantTracks])
        if ([track hasMediaCharacteristic:mediaCharacteristic])
            [tracks addObject:track];
    return tracks;
}

- (CMTime)duration
{
    return _revenantAsset ? _revenantAsset.duration : CMTimeMake(0, 600);
}

- (float)preferredRate
{
    return _revenantAsset.preferredRate;
}

- (float)preferredVolume
{
    return _revenantAsset.preferredVolume;
}

- (CGAffineTransform)preferredTransform
{
    return _revenantAsset.preferredTransform;
}

- (CGSize)naturalSize
{
    return _revenantAsset.naturalSize;
}

- (BOOL)providesPreciseDurationAndTiming
{
    return _revenantAsset.providesPreciseDurationAndTiming;
}

- (AVAssetReferenceRestrictions)referenceRestrictions
{
    return AVAssetReferenceRestrictionForbidLocalReferenceToRemote;
}


- (void)cancelLoading
{
    [_revenantAsset cancelLoading];
}

- (NSArray<AVAssetTrackGroup *> *)trackGroups
{
    return _revenantAsset.trackGroups ?: @[];
}

- (AVMetadataItem *)creationDate
{
    return _revenantAsset.creationDate;
}

- (NSString *)lyrics
{
    return _revenantAsset.lyrics;
}

- (NSArray<AVMetadataItem *> *)commonMetadata
{
    return _revenantAsset.commonMetadata ?: @[];
}

- (NSArray<AVMetadataFormat> *)availableMetadataFormats
{
    return _revenantAsset.availableMetadataFormats ?: @[];
}

- (NSArray<AVMetadataItem *> *)metadataForFormat:(AVMetadataFormat)format
{
    return [_revenantAsset metadataForFormat:format] ?: @[];
}

- (NSArray<NSLocale *> *)availableChapterLocales
{
    return _revenantAsset.availableChapterLocales ?: @[];
}

- (NSArray<AVTimedMetadataGroup *> *)chapterMetadataGroupsWithTitleLocale:(NSLocale *)locale containingItemsWithCommonKeys:(NSArray<AVMetadataKey> *)commonKeys
{
    return [_revenantAsset chapterMetadataGroupsWithTitleLocale:locale containingItemsWithCommonKeys:commonKeys] ?: @[];
}

- (NSArray<AVTimedMetadataGroup *> *)chapterMetadataGroupsBestMatchingPreferredLanguages:(NSArray<NSString *> *)preferredLanguages
{
    return [_revenantAsset chapterMetadataGroupsBestMatchingPreferredLanguages:preferredLanguages] ?: @[];
}

- (NSArray<AVMediaCharacteristic> *)availableMediaCharacteristicsWithMediaSelectionOptions
{
    return _revenantAsset.availableMediaCharacteristicsWithMediaSelectionOptions ?: @[];
}

- (AVMediaSelectionGroup *)mediaSelectionGroupForMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic
{
    return [_revenantAsset mediaSelectionGroupForMediaCharacteristic:mediaCharacteristic];
}

- (BOOL)hasProtectedContent
{
    return _revenantAsset.hasProtectedContent;
}

- (BOOL)isPlayable
{
    return _revenantAsset.playable;
}

- (BOOL)isExportable
{
    return _revenantAsset.exportable;
}

- (BOOL)isReadable
{
    return _revenantAsset.readable;
}

- (BOOL)isComposable
{
    return _revenantAsset.composable;
}

- (BOOL)isCompatibleWithSavedPhotosAlbum
{
    return _revenantAsset.compatibleWithSavedPhotosAlbum;
}

- (AVKeyValueStatus)statusOfValueForKey:(NSString *)key error:(NSError * _Nullable __autoreleasing *)outError
{
    return [_revenantAsset statusOfValueForKey:key error:outError];
}

- (void)loadValuesAsynchronouslyForKeys:(NSArray<NSString *> *)keys completionHandler:(void (^)(void))handler
{
    if (_revenantAsset) {
        [_revenantAsset loadValuesAsynchronouslyForKeys:keys completionHandler:handler];
        return;
    }
    if (handler)
        dispatch_async(dispatch_get_main_queue(), handler);
}

@end

@implementation RevenantMovieTrack
{
    AVAssetTrack *_revenantTrack;
    __weak RevenantMovie *_revenantMovie;
    RevenantTrackHeader _revenantHeader;
    BOOL _revenantHasHeader;
}

- (instancetype)initWithAssetTrack:(AVAssetTrack *)track movie:(RevenantMovie *)movie
{
    struct objc_super parent = {self, [NSObject class]};
    if ((self = ((id (*)(struct objc_super *, SEL))objc_msgSendSuper)(&parent, @selector(init)))) {
        _revenantTrack = track;
        _revenantMovie = movie;
        NSURL *file = [movie revenantFileURL];
        if (file.isFileURL) {
            NSData *data = [NSData dataWithContentsOfURL:file options:NSDataReadingMappedIfSafe error:nil];
            _revenantHasHeader = data && revenantReadTrackHeader(data, track.trackID, &_revenantHeader);
        }
    }
    return self;
}

- (AVAsset *)asset
{
    return _revenantMovie;
}

- (NSArray<AVMetadataItem *> *)commonMetadata
{
    return _revenantTrack.commonMetadata;
}

- (NSArray<AVMetadataFormat> *)availableMetadataFormats
{
    return _revenantTrack.availableMetadataFormats;
}

- (NSArray<AVMetadataItem *> *)metadataForFormat:(AVMetadataFormat)format
{
    return [_revenantTrack metadataForFormat:format];
}

- (float)estimatedDataRate
{
    return _revenantTrack.estimatedDataRate;
}

- (NSString *)extendedLanguageTag
{
    return _revenantTrack.extendedLanguageTag;
}

- (NSArray *)formatDescriptions
{
    return _revenantTrack.formatDescriptions;
}

- (BOOL)hasMediaCharacteristic:(AVMediaCharacteristic)mediaCharacteristic
{
    return [_revenantTrack hasMediaCharacteristic:mediaCharacteristic];
}

- (BOOL)isEnabled
{
    return _revenantTrack.enabled;
}

- (BOOL)isPlayable
{
    return _revenantTrack.playable;
}

- (BOOL)isSelfContained
{
    return _revenantTrack.selfContained;
}

- (NSString *)languageCode
{
    return _revenantTrack.languageCode;
}

- (AVMediaType)mediaType
{
    return _revenantTrack.mediaType;
}

- (CGSize)naturalSize
{
    return _revenantTrack.naturalSize;
}

- (CMTimeScale)naturalTimeScale
{
    return _revenantTrack.naturalTimeScale;
}

- (float)nominalFrameRate
{
    return _revenantTrack.nominalFrameRate;
}

- (CGAffineTransform)preferredTransform
{
    return _revenantTrack.preferredTransform;
}

- (float)preferredVolume
{
    return _revenantTrack.preferredVolume;
}

- (CMTime)samplePresentationTimeForTrackTime:(CMTime)trackTime
{
    return [_revenantTrack samplePresentationTimeForTrackTime:trackTime];
}

- (AVAssetTrackSegment *)segmentForTrackTime:(CMTime)trackTime
{
    return [_revenantTrack segmentForTrackTime:trackTime];
}

- (NSArray<AVAssetTrackSegment *> *)segments
{
    return _revenantTrack.segments;
}

- (AVKeyValueStatus)statusOfValueForKey:(NSString *)key error:(NSError * _Nullable __autoreleasing *)outError
{
    return [_revenantTrack statusOfValueForKey:key error:outError];
}

- (void)loadValuesAsynchronouslyForKeys:(NSArray<NSString *> *)keys completionHandler:(void (^)(void))handler
{
    [_revenantTrack loadValuesAsynchronouslyForKeys:keys completionHandler:handler];
}

- (CMTimeRange)timeRange
{
    return _revenantTrack.timeRange;
}

- (long long)totalSampleDataLength
{
    return _revenantTrack.totalSampleDataLength;
}

- (CMPersistentTrackID)trackID
{
    return _revenantTrack.trackID;
}

- (BOOL)revenantHeader:(RevenantTrackHeader *)header
{
    if (!_revenantHasHeader)
        return NO;
    *header = _revenantHeader;
    return YES;
}

- (CMTimeRange)mediaPresentationTimeRange
{
    RevenantTrackHeader header;
    if (![self revenantHeader:&header] || header.timescale == 0)
        return kCMTimeRangeInvalid;
    return CMTimeRangeMake(CMTimeMake(header.presentationStart, header.timescale),
                           CMTimeMake(header.presentationEnd - header.presentationStart, header.timescale));
}

- (CMTimeRange)mediaDecodeTimeRange
{
    RevenantTrackHeader header;
    if (![self revenantHeader:&header] || header.timescale == 0)
        return kCMTimeRangeInvalid;
    return CMTimeRangeMake(CMTimeMake(0, header.timescale), CMTimeMake(header.decodeDuration, header.timescale));
}

- (NSInteger)alternateGroupID
{
    RevenantTrackHeader header;
    return [self revenantHeader:&header] ? header.alternateGroup : 0;
}

- (AVMediaDataStorage *)mediaDataStorage
{
    return nil;
}

@end
