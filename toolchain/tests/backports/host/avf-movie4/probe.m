#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>

#if CHARON_PORT_BUILD
#define MOVIE_CLASS_NAME @"charon_host_AVMovie"
#else
#define MOVIE_CLASS_NAME @"AVMovie"
#endif
#define PORT_PREFIX @"charon_host_"

@protocol ProbeFactory
+ (id)movieWithURL:(NSURL *)URL options:(NSDictionary *)options;
+ (id)movieWithData:(NSData *)data options:(NSDictionary *)options;
+ (NSArray *)movieTypes;
@end

@protocol ProbeInit
- (id)init;
- (id)initWithURL:(NSURL *)URL options:(NSDictionary *)options;
- (id)initWithData:(NSData *)data options:(NSDictionary *)options;
@end

@protocol ProbeMovie
- (NSURL *)URL;
- (NSData *)data;
- (id)defaultMediaDataStorage;
- (BOOL)canContainMovieFragments;
- (BOOL)containsMovieFragments;
- (BOOL)isCompatibleWithFileType:(NSString *)fileType;
- (NSArray *)tracks;
- (id)trackWithTrackID:(CMPersistentTrackID)trackID;
- (NSArray *)tracksWithMediaType:(NSString *)mediaType;
- (NSArray *)tracksWithMediaCharacteristic:(NSString *)characteristic;
@end

#ifdef CHARON_AVMOVIE_APP
#define PROBE_MAIN charon_avmovie_probe_main
#else
#define PROBE_MAIN main
#endif

static int rowCount;

static void row(NSString *key, NSString *value)
{
    NSString *flat = [value stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    printf("%s = %s\n", key.UTF8String, flat.UTF8String);
    rowCount++;
}

static NSString *key(NSString *prefix, NSString *name)
{
    return [NSString stringWithFormat:@"%@ %@", prefix, name];
}

static NSString *className(id object)
{
    if (!object)
        return @"nil";
    NSString *name = NSStringFromClass([object class]);
    if ([name hasPrefix:PORT_PREFIX])
        name = [name substringFromIndex:PORT_PREFIX.length];
    return name;
}

static NSString *timeString(CMTime t)
{
    if (!CMTIME_IS_VALID(t))
        return @"invalid";
    if (t.value == 0)
        return @"0";
    return [NSString stringWithFormat:@"%lld/%d=%.6f", t.value, t.timescale, CMTimeGetSeconds(t)];
}

static NSString *rangeString(CMTimeRange r)
{
    return [NSString stringWithFormat:@"start=%@ duration=%@ valid=%@", timeString(r.start), timeString(r.duration),
                                      CMTIMERANGE_IS_VALID(r) ? @"YES" : @"NO"];
}

static NSString *sizeString(CGSize s)
{
    return [NSString stringWithFormat:@"%.3fx%.3f", s.width, s.height];
}

static NSString *transformString(CGAffineTransform t)
{
    return [NSString stringWithFormat:@"%.3f %.3f %.3f %.3f %.3f %.3f", t.a, t.b, t.c, t.d, t.tx, t.ty];
}

static NSString *yesNo(BOOL b)
{
    return b ? @"YES" : @"NO";
}

static NSString *countString(NSArray *array)
{
    return array ? [NSString stringWithFormat:@"%lu", (unsigned long)array.count] : @"nil";
}

static NSString *listString(NSArray *array)
{
    if (!array)
        return @"nil";
    NSArray *sorted = [array sortedArrayUsingSelector:@selector(compare:)];
    return [sorted componentsJoinedByString:@","];
}

static NSString *trackIDs(NSArray *tracks)
{
    if (!tracks)
        return @"nil";
    NSMutableArray *ids = [NSMutableArray array];
    for (AVAssetTrack *track in tracks)
        [ids addObject:[NSString stringWithFormat:@"%d", track.trackID]];
    return [ids componentsJoinedByString:@","];
}

static NSString *objectString(id object)
{
    return object ? className(object) : @"nil";
}

static void probeMovie(NSString *p, id<ProbeMovie> m)
{
    AVAsset *asset = (AVAsset *)m;
    row(key(p, @"class"), className(m));
    row(key(p, @"URL"), m.URL ? m.URL.lastPathComponent : @"nil");
    row(key(p, @"data"), m.data ? [NSString stringWithFormat:@"%lu bytes", (unsigned long)m.data.length] : @"nil");
    row(key(p, @"duration"), timeString(asset.duration));
    row(key(p, @"preferredRate"), [NSString stringWithFormat:@"%.3f", asset.preferredRate]);
    row(key(p, @"preferredVolume"), [NSString stringWithFormat:@"%.3f", asset.preferredVolume]);
    row(key(p, @"preferredTransform"), transformString(asset.preferredTransform));
    row(key(p, @"naturalSize"), sizeString(asset.naturalSize));
    row(key(p, @"providesPreciseDurationAndTiming"), yesNo(asset.providesPreciseDurationAndTiming));
    row(key(p, @"referenceRestrictions"), [NSString stringWithFormat:@"%lu", (unsigned long)asset.referenceRestrictions]);
    row(key(p, @"hasProtectedContent"), yesNo(asset.hasProtectedContent));
    row(key(p, @"playable"), yesNo(asset.playable));
    row(key(p, @"exportable"), yesNo(asset.exportable));
    row(key(p, @"readable"), yesNo(asset.readable));
    row(key(p, @"composable"), yesNo(asset.composable));
    row(key(p, @"creationDate"), objectString(asset.creationDate));
    row(key(p, @"lyrics"), asset.lyrics ?: @"nil");
    row(key(p, @"commonMetadata count"), countString(asset.commonMetadata));
    row(key(p, @"availableMetadataFormats"), listString(asset.availableMetadataFormats));
    row(key(p, @"trackGroups count"), countString(asset.trackGroups));
    row(key(p, @"availableChapterLocales count"), countString(asset.availableChapterLocales));
    row(key(p, @"availableMediaCharacteristicsWithMediaSelectionOptions"),
        listString(asset.availableMediaCharacteristicsWithMediaSelectionOptions));
    row(key(p, @"defaultMediaDataStorage"), objectString(m.defaultMediaDataStorage));
    row(key(p, @"canContainMovieFragments"), yesNo(m.canContainMovieFragments));
    row(key(p, @"containsMovieFragments"), yesNo(m.containsMovieFragments));
    NSError *error = nil;
    row(key(p, @"statusOfValueForKey:duration"),
        [NSString stringWithFormat:@"%ld", (long)[asset statusOfValueForKey:@"duration" error:&error]]);
    row(key(p, @"statusOfValueForKey:duration error"),
        error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code] : @"nil");

    NSArray *tracks = m.tracks;
    row(key(p, @"tracks count"), countString(tracks));
    row(key(p, @"tracks IDs"), trackIDs(tracks));
    for (NSUInteger i = 0; i < tracks.count; i++) {
        AVAssetTrack *t = tracks[i];
        AVMovieTrack *mt = (AVMovieTrack *)t;
        NSString *tp = [NSString stringWithFormat:@"%@ track[%lu]", p, (unsigned long)i];
        row(key(tp, @"class"), className(t));
        row(key(tp, @"trackID"), [NSString stringWithFormat:@"%d", t.trackID]);
        row(key(tp, @"mediaType"), t.mediaType);
        row(key(tp, @"timeRange"), rangeString(t.timeRange));
        row(key(tp, @"naturalSize"), sizeString(t.naturalSize));
        row(key(tp, @"naturalTimeScale"), [NSString stringWithFormat:@"%d", t.naturalTimeScale]);
        row(key(tp, @"nominalFrameRate"), [NSString stringWithFormat:@"%.2f", t.nominalFrameRate]);
        row(key(tp, @"estimatedDataRate"), [NSString stringWithFormat:@"%.0f", t.estimatedDataRate]);
        row(key(tp, @"preferredTransform"), transformString(t.preferredTransform));
        row(key(tp, @"preferredVolume"), [NSString stringWithFormat:@"%.3f", t.preferredVolume]);
        row(key(tp, @"languageCode"), t.languageCode ?: @"nil");
        row(key(tp, @"extendedLanguageTag"), t.extendedLanguageTag ?: @"nil");
        row(key(tp, @"enabled"), yesNo(t.enabled));
        row(key(tp, @"playable"), yesNo(t.playable));
        row(key(tp, @"selfContained"), yesNo(t.selfContained));
        row(key(tp, @"totalSampleDataLength"), [NSString stringWithFormat:@"%lld", t.totalSampleDataLength]);
        row(key(tp, @"segments count"), countString(t.segments));
        row(key(tp, @"formatDescriptions count"), countString(t.formatDescriptions));
        row(key(tp, @"asset"), objectString(t.asset));
        row(key(tp, @"mediaPresentationTimeRange"), rangeString(mt.mediaPresentationTimeRange));
        row(key(tp, @"mediaDecodeTimeRange"), rangeString(mt.mediaDecodeTimeRange));
        row(key(tp, @"alternateGroupID"), [NSString stringWithFormat:@"%ld", (long)mt.alternateGroupID]);
        row(key(tp, @"mediaDataStorage"), objectString(mt.mediaDataStorage));
    }

    AVAssetTrack *first = tracks.count ? tracks[0] : nil;
    AVAssetTrack *found = first ? (AVAssetTrack *)[m trackWithTrackID:first.trackID] : nil;
    row(key(p, @"trackWithTrackID present"),
        [NSString stringWithFormat:@"%@ id=%d", objectString(found), found ? found.trackID : -1]);
    row(key(p, @"trackWithTrackID absent 999"), objectString([m trackWithTrackID:999]));
    row(key(p, @"tracksWithMediaType vide"), trackIDs([m tracksWithMediaType:AVMediaTypeVideo]));
    row(key(p, @"tracksWithMediaType soun"), trackIDs([m tracksWithMediaType:AVMediaTypeAudio]));
    row(key(p, @"tracksWithMediaType none"), trackIDs([m tracksWithMediaType:@"nope"]));
    row(key(p, @"tracksWithMediaCharacteristic visual"),
        trackIDs([m tracksWithMediaCharacteristic:AVMediaCharacteristicVisual]));
    row(key(p, @"tracksWithMediaCharacteristic audible"),
        trackIDs([m tracksWithMediaCharacteristic:AVMediaCharacteristicAudible]));
}

static void attempt(NSString *name, id (^body)(void))
{
    @try {
        id result = body();
        if ([result isKindOfClass:[NSNumber class]])
            row(key(name, @"outcome"), [NSString stringWithFormat:@"returned %@", yesNo([result boolValue])]);
        else
            row(key(name, @"outcome"), result ? [NSString stringWithFormat:@"returned %@", className(result)] : @"returned nil");
    } @catch (NSException *e) {
        row(key(name, @"outcome"), [NSString stringWithFormat:@"raised %@", e.name]);
        row(key(name, @"reason"), e.reason ?: @"nil");
    }
}

int PROBE_MAIN(int argc, const char **argv)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        if (argc != 2) {
            fprintf(stderr, "usage: probe <movies directory>\n");
            return 2;
        }
        NSString *dir = [NSString stringWithUTF8String:argv[1]];
        Class<ProbeFactory> factory = (Class<ProbeFactory>)NSClassFromString(MOVIE_CLASS_NAME);
        if (!factory) {
            fprintf(stderr, "probe: %s is not a class in this build\n", MOVIE_CLASS_NAME.UTF8String);
            return 1;
        }

        row(@"class superclass", NSStringFromClass(class_getSuperclass((Class)factory)));
        row(@"movieTypes", listString([factory movieTypes]));
        row(@"movieTypes count", countString([factory movieTypes]));

        NSURL *urlA = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"movie-a.mov"]];
        NSURL *urlB = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"movie-b.mov"]];
        id<ProbeMovie> movieA = (id<ProbeMovie>)[factory movieWithURL:urlA options:nil];
        id<ProbeMovie> movieB = (id<ProbeMovie>)[factory movieWithURL:urlB options:nil];
        probeMovie(@"movie-a", movieA);
        probeMovie(@"movie-b", movieB);
        NSURL *urlC = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"movie-c.mov"]];
        probeMovie(@"movie-c", (id<ProbeMovie>)[factory movieWithURL:urlC options:nil]);

        for (NSString *type in @[AVFileTypeQuickTimeMovie, AVFileTypeMPEG4, AVFileTypeAppleM4A, AVFileTypeWAVE,
                                 @"com.apple.m4v-video", @"public.3gpp", @"com.apple.quicktime-audio"]) {
            NSString *name = [NSString stringWithFormat:@"movie-a isCompatibleWithFileType %@", type];
            attempt(name, ^id {
                return [NSNumber numberWithBool:[movieA isCompatibleWithFileType:type]];
            });
        }

        NSData *bytesB = [NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@"movie-b.mov"]];
        id<ProbeMovie> movieData = nil;
        @try {
            movieData = (id<ProbeMovie>)[factory movieWithData:bytesB options:nil];
        } @catch (NSException *e) {
            row(@"data-b movieWithData", [NSString stringWithFormat:@"raised %@: %@", e.name, e.reason]);
        }
        if (movieData)
            probeMovie(@"data-b", movieData);
        else
            row(@"data-b movieWithData", @"returned nil");

        Class movieClass = (Class)factory;
        attempt(@"init", ^id {
            id<ProbeInit> bare = [[movieClass alloc] init];
            if (bare) {
                row(@"init class", className(bare));
                row(@"init URL", [(id<ProbeMovie>)bare URL] ? @"non-nil" : @"nil");
                row(@"init duration", timeString(((AVAsset *)bare).duration));
                row(@"init tracks count", countString([(id<ProbeMovie>)bare tracks]));
                row(@"init defaultMediaDataStorage", objectString([(id<ProbeMovie>)bare defaultMediaDataStorage]));
            }
            return bare;
        });
        attempt(@"movieWithURL nil", ^id { return [factory movieWithURL:nil options:nil]; });
        attempt(@"movieWithData nil", ^id { return [factory movieWithData:nil options:nil]; });
        attempt(@"initWithURL nil", ^id { return [(id<ProbeInit>)[movieClass alloc] initWithURL:nil options:nil]; });
        attempt(@"initWithData nil", ^id { return [(id<ProbeInit>)[movieClass alloc] initWithData:nil options:nil]; });
        attempt(@"movieWithData empty", ^id { return [factory movieWithData:[NSData data] options:nil]; });

        @try {
            id copied = [(id)movieA copy];
            row(@"movie-a copy", copied == movieA ? @"same object" : [NSString stringWithFormat:@"another %@", className(copied)]);
        } @catch (NSException *e) {
            row(@"movie-a copy", [NSString stringWithFormat:@"raised %@", e.name]);
        }

        AVAssetTrack *kept = nil;
        @autoreleasepool {
            id<ProbeMovie> movie = (id<ProbeMovie>)[factory movieWithURL:urlA options:nil];
            kept = [movie tracks].firstObject;
            row(@"released-movie movie and first track read", yesNo(movie != nil && kept != nil));
        }
        row(@"released-movie track class", className(kept));
        row(@"released-movie track mediaType", kept ? kept.mediaType : @"nil");
        row(@"released-movie track asset", objectString(kept.asset));
        row(@"released-movie track timeRange", rangeString(kept.timeRange));
        AVMovieTrack *keptMovieTrack = (AVMovieTrack *)kept;
        row(@"released-movie track mediaPresentationTimeRange", rangeString(keptMovieTrack.mediaPresentationTimeRange));
        row(@"released-movie track mediaDecodeTimeRange", rangeString(keptMovieTrack.mediaDecodeTimeRange));
        row(@"released-movie track alternateGroupID",
            [NSString stringWithFormat:@"%ld", (long)keptMovieTrack.alternateGroupID]);
        kept = nil;
        row(@"released-movie track released", @"yes");

        printf("rows: %d\n", rowCount);
        return 0;
    }
}
