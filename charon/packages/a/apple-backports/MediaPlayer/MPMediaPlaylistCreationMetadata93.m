// MPMediaPlaylistCreationMetadata, the 9.3 class, a value holder for a playlist the caller is creating in
// the cloud.
//
// MEASURED, class-scoped, with tools/corpus/objc-inventory.lua over the armv7 caches of 6.1.3 and 4.3
// (commands in facts/MediaPlayer/LanguageOptions.md; controls as that page records - the same reader, the
// same two files, MPNowPlayingInfoCenter PRESENT at 6.1.3 and ABSENT at 4.3): this class reads ABSENT from
// both ends, so it is new code and cannot shadow anything and `implemented` is available.
//
// IT IS A VALUE HOLDER, and the header says so in its own shape. MPMediaPlaylist.h at 26.2 declares it
// MP_INIT_UNAVAILABLE with one designated initializer and three properties:
//
//   - (instancetype)initWithName:(NSString *)name NS_DESIGNATED_INITIALIZER;
//   @property (nonatomic, readonly, copy) NSString *name;
//   @property (null_resettable, nonatomic, copy) NSString *authorDisplayName;
//   @property (nonatomic, copy) NSString *descriptionText;
//
// So the class holds a name and two descriptive strings and does nothing else. `name` is the designated
// initializer's argument and is readonly, so it is set once; the other two are readwrite and are the
// caller's to fill in.
//
// null_resettable ON authorDisplayName IS A CONTRACT AND IS HONOURED. The header's own comment says
// "Defaults to the requesting app's display name" - so nil does not mean "no author", it means "not set,
// use the app's name". This object therefore answers a nil authorDisplayName with the PORT'S OWN bundle
// display name, read from the main bundle, rather than with nil. That is a real lookup, not a constant:
// an application with a different CFBundleDisplayName gets its own name, which is what the header's
// comment describes. A nil answer would instead mean "this playlist has no author", which is a different
// statement and not one the header permits for this property.
//
// THE ONE THING THIS OBJECT DOES NOT DO, which is the limit on the whole 9.3 cloud family. The class this
// is an argument to is -[MPMediaLibrary getPlaylistWithUUID:creationMetadata:completionHandler:], and that
// method stays `absent`: the release has no iCloud music library, and MPMediaLibrary's own 110 instance
// and 23 class methods are all local-library work. So this object is constructible and its three
// properties work, and nothing on this release can send it anywhere. The class is carried because it is a
// value holder an application can build, and the method is not carried because the endpoint is not there -
// two different questions, and the row above says which is which.
//
// MP_INIT_UNAVAILABLE is a COMPILE-TIME attribute (MediaPlayerDefines.h:70-73 expands it to
// "+ (instancetype)new NS_UNAVAILABLE; - (instancetype)init NS_UNAVAILABLE;"), so this object declares no
// -init of its own: the header's designated initializer is the only way in, and the check asserts that a
// bare -init is unavailable rather than testing a spelling the SDK forbids.
//
// One object per release: this file is the 9.3 class. MPMediaPlaylist93.m holds the two 9.3 keys of the
// existing playlist class and MPMediaPlaylist80.m the 8.0 one; release-split reads band points only, so a
// file holding all three would pass that check and still be one object for three releases.

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation MPMediaPlaylistCreationMetadata
{
    // The author's display name once it has been needed, and nil until then - which is the header's own
    // null_resettable "not set" spelling and not a missing value.
    NSString *_authorDisplayName;
}

@synthesize name = _name;
@synthesize descriptionText = _descriptionText;

// The header's designated initializer, quoted above. `name` is `@property (nonatomic, readonly, copy)`, so
// it is copied here and has no setter: the identifier a playlist is created under cannot change after the
// fact, and a copy property whose value could be reassigned would not be the property the header declares.
- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        _name = [name copy];
    }
    return self;
}

- (NSString *)name { return _name; }
- (NSString *)descriptionText { return _descriptionText; }

// authorDisplayName is `null_resettable`, so nil is the "not set" spelling and the header says what to
// answer instead: "Defaults to the requesting app's display name". The lookup is real - the main bundle's
// own display name - so an application with its own CFBundleDisplayName reads its own name back, and a
// bundle with no display name at all falls through to its bundle name, which is what
// -[NSBundle localizedInfoDictionary] and -bundleName between them provide.
//
// The value is COPIED into the instance the first time it is needed, so that a later read is the same
// string even if the bundle's dictionary changes - the property is `copy`, and a property that recomputed
// on every read could return a different value from two reads of an unchanged object.
//
// THE FALLBACK CHAIN IS THREE DEEP, and the third step exists because a measurement demanded it. The
// header says the default is "the requesting app's display name", and the first two steps are the
// Info.plist keys that name it: CFBundleDisplayName, then CFBundleName. Neither is guaranteed - the host
// check is a command-line binary with neither - so the last step is the process name, which is a string
// every process has. A getter that answered nil for a bundle without a display name would break the
// property's own null_resettable promise, which is that nil is a spelling meaning "use the default"
// rather than a spelling meaning "there is no answer".
- (NSString *)authorDisplayName {
    if (!_authorDisplayName) {
        NSDictionary *info = [[NSBundle mainBundle] localizedInfoDictionary];
        NSString *display = info[@"CFBundleDisplayName"];
        if (![display isKindOfClass:[NSString class]] || display.length == 0) {
            // CFBundleDisplayName, then the Info.plist's own CFBundleName, and nothing else. NOT
            // -[NSBundle bundleName], which a first draft used and which is macOS-only: the iOS SDK
            // declares no such selector and clang answers "no visible @interface for 'NSBundle' declares
            // the selector 'bundleName'" - measured. The Info.plist key is the same string the macOS
            // accessor would have read, so this is the same fallback by a documented route rather than a
            // second spelling of the same lookup.
            display = info[@"CFBundleName"];
        }
        if (![display isKindOfClass:[NSString class]] || display.length == 0) {
            // A BUNDLE WITH NEITHER KEY, which is not a theoretical case: the host check that exercises
            // this file is a bare command-line binary whose Info.plist carries neither CFBundleDisplayName
            // nor CFBundleName, and the first draft of the getter answered nil there - measured, two RED
            // lines, the "never set" case and the "reset to nil" case. null_resettable promises an answer
            // for nil, and a caller that reads authorDisplayName on a bundle without a display name must
            // still get a string. The last fallback is the process's own name, which is the one string a
            // bundle always has and which is what a display name is for.
            display = [[NSProcessInfo processInfo] processName];
        }
        _authorDisplayName = [display copy];
    }
    return _authorDisplayName;
}

- (void)setAuthorDisplayName:(NSString *)authorDisplayName {
    _authorDisplayName = [authorDisplayName copy];
}

@end
