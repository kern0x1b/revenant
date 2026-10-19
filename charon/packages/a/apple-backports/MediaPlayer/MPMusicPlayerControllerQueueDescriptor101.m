// The four MPMusicPlayerController queue methods that take a 10.1 queue descriptor: -setQueueWithDescriptor:,
// -appendQueueDescriptor: and -prependQueueDescriptor: (10.3), and -openToPlayQueueDescriptor:completionHandler:
// on MPSystemMusicPlayerController (11.0). The queue setting itself is the RELEASE's, called at the
// release's own spelling; this file is the translation from a descriptor to that call.
//
// MEASURED, class-scoped, with tools/corpus/objc-inventory.lua over the armv7 caches of 6.1.3 and 4.3
// (commands in facts/MediaPlayer/LanguageOptions.md, controls as that page records). From
// MPMusicPlayerController's own 66 instance methods at 6.1.3 - 52 at 4.3 - the queue setters that exist
// on the release:
//
//   -setQueueWithQuery:             PRESENT   PRESENT
//   -setQueueWithItemCollection:    PRESENT   PRESENT
//   -setQueueWithSeedItems:         PRESENT   PRESENT
//   -setQueueWithQuery:firstItem:   PRESENT   PRESENT
//   -setQueueWithGeniusMixPlaylist: PRESENT   (absent at 4.3)
//   -setQueueWithStoreIDs:          absent    absent
//   -setQueueWithItemIDs:           absent    absent
//
// -setQueueWithQuery: and -setQueueWithItemCollection: are BOTH declared by the SDK header as public API
// (MPMusicPlayerController.h), and both are the release's own methods, so a 10.1 media-item descriptor
// resolves onto a call the release really has, with the release's own argument order. That is what makes
// -setQueueWithDescriptor: a bridge rather than a queue this port builds and hopes for: the caller then
// hears its queue back through the release's own -nowPlayingItemAtIndex: and -nowPlayingItem.
//
// -setQueueWithQuery:firstItem: is deliberately NOT CALLED, and the reason is the sharpest measurement in
// this file. The release HAS that method - it is one of the 66 own instance methods at 6.1.3 and one of
// the 52 at 4.3 - and it is exactly the call a descriptor's startItem wants. But NO SDK HEADER DECLARES
// IT: awk over the @interface MPMusicPlayerController block of the 16.4 header lists the public queue
// setters as -setQueueWithQuery:, -setQueueWithItemCollection:, -setQueueWithStoreIDs:,
// -setQueueWithDescriptor:, -prependQueueDescriptor: and -appendQueueDescriptor:, and the two-argument
// form is not among them. So it is a private method of the framework, and calling it would be a private
// API trick where a public one exists - which this port does not do. The startItem is therefore not
// applied, and the file says so rather than reaching for the selector that would apply it.
//
// WHAT IS NOT BRIDGED, and it is most of the family. A descriptor is one of two concrete subclasses and
// only one of them has a setter on this release:
//
//   MPMusicPlayerMediaItemQueueDescriptor  ->  -setQueueWithQuery: / -setQueueWithItemCollection:  REAL, called
//   MPMusicPlayerStoreQueueDescriptor      ->  nothing                                            NO setter at either end
//
// The Store case is not a gap in this file. MPMusicPlayerController has no setter taking a Store ID in any
// spelling on 6.1.3 or 4.3, and there is nothing to resolve an ID to: MPMediaItem.playbackStoreID is on 0
// of the 113981 distinct selector names and none of the release's MPMediaItem getters is declared
// anywhere in it (facts/MediaPlayer/AbsentRows.md). Calling -setQueueWithQuery: with a query fabricated
// out of Store IDs would be a different API's answer under this method's name, which is the failure this
// port exists to avoid. So the Store descriptor is delivered unchanged and nothing pretends to have set
// a queue.
//
// One object per release, with the exception this file states rather than hides: it holds the 10.1
// setter AND the 10.3 pair AND the 11.0 method, and that is three releases. The reason is mechanical and
// is the trap in AGENTS.md under "A C function shared between backport files": a helper defined in a file
// that exports one band's API is left OUT of the bands that do not export it, so the reference is
// `Undefined symbols` in later bands only - backports-gate links one band and passes, and only the
// all-band canon build shows it. Splitting these three would put the descriptor-consuming logic and the
// two no-op methods in different objects with one calling the other. So they share one object and every
// row carries its own release in the registry, which is what band() places on. release-split reads band
// points only, so it cannot see this - the exception is stated here, in all three rows, and by each row
// naming the release its own API arrived in.

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation MPMusicPlayerController (CharonQueueDescriptor101)

- (void)setQueueWithDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor {
    if (!queueDescriptor) {
        return;
    }
    if ([queueDescriptor isKindOfClass:[MPMusicPlayerMediaItemQueueDescriptor class]]) {
        MPMusicPlayerMediaItemQueueDescriptor *media =
            (MPMusicPlayerMediaItemQueueDescriptor *)queueDescriptor;
        // Dispatched on what the descriptor actually HOLDS, not on which initializer built it: a
        // descriptor built with initWithQuery: carries a query, one built with initWithItemCollection:
        // carries a collection, and a caller may have set neither. Both setters below are the release's
        // own public methods with the release's own single argument.
        if (media.query) {
            [self setQueueWithQuery:media.query];
            return;
        }
        if (media.itemCollection) {
            [self setQueueWithItemCollection:media.itemCollection];
            return;
        }
        // A descriptor with neither is one the caller left empty. There is no release call that sets an
        // empty queue - -setQueueWithSeedItems: takes items and is the nearest, but passing an empty array
        // to it would be this port choosing an operation the caller did not ask for. The queue is left
        // as it is, which is what the caller already had.
        return;
    }
    if ([queueDescriptor isKindOfClass:[MPMusicPlayerStoreQueueDescriptor class]]) {
        // Deliberately not bridged; the reason is the header comment above and the row that carries it.
        return;
    }
}

// -appendQueueDescriptor: and -prependQueueDescriptor: are the header's 10.3 spellings. The release has
// NO method to append to or prepend to an existing queue: its own list is the five REPLACING setters
// above, and every one of them replaces the queue wholesale. There is also no way to read the current
// queue in a form that could be re-set with one item added - -nowPlayingItem is the item being played,
// not the queue, and -nowPlayingItemAtIndex: reads the release's queue by index but nothing returns it
// as something that could be handed back to a setter.
//
// The honest behaviour is to leave the queue alone, which is what these do. An implementation that read
// the current queue, appended in memory and called -setQueueWithQuery: with the result would change which
// item plays next and would lose the release's own start item, and the caller would then hear a queue
// through the release's accessors that the release never agreed to. Both return void in the header, so
// there is no error channel and nothing is invented to report through one.
- (void)appendQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor {
    (void)queueDescriptor;
}

- (void)prependQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor {
    (void)queueDescriptor;
}

@end

// MPSystemMusicPlayerController is declared by NO SDK HEADER AT ALL - not in 16.4, not in 26.2 - and the
// release carries no such class (objc-inventory reads it ABSENT from both 6.1.3 and 4.3). The method it
// is the receiver of is still a row, so the class is declared here, minimally, as the header-less
// subclass of MPMusicPlayerController the name describes. It is declared and not implemented: an
// @implementation would claim a class whose own behaviour is unknown on any release, and the row's claim
// is only about the one method.
@interface MPSystemMusicPlayerController : MPMusicPlayerController
@end

// The class needs an @implementation as well as an @interface, and its absence is a LINK failure rather
// than a warning: a category on a class the translation unit only declares leaves
// "_OBJC_CLASS_$_MPSystemMusicPlayerController" undefined at link time - measured, "Undefined symbols for
// architecture arm64 ... referenced from __OBJC_$_CATEGORY_MPSystemMusicPlayerController_$_CharonOpenToPlay11".
// The body is empty ON PURPOSE and the reason is the same as for the declaration: the class is
// MPMusicPlayerController's system-music sibling, the release has no such class on any held end, and an
// implementation here would have to invent what it does. What it inherits from MPMusicPlayerController -
// the release's own play, pause and queue accessors - is what it can honestly be.
@implementation MPSystemMusicPlayerController
@end

@implementation MPSystemMusicPlayerController (CharonOpenToPlay11)

// MPMusicPlayerController.h:46, the header's own declaration:
//     - (void)openToPlayQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor
//         MP_API(ios(11.0), tvos(14.0)) MP_UNAVAILABLE(watchos, macos) NS_SWIFT_NAME(openToPlay(_:));
// under the header's own comment, that the call makes Music play the content the queue describes. One argument
// and no completion handler, so the honest behaviour on a release with no
// Music application to switch to and no system music player is the one the two methods above give: the
// queue is left exactly as the caller had it. It returns void and takes no handler, so there is no
// channel to report through and nothing is invented to report through one - which is why this cannot be
// the port's own -openToPlayQueueDescriptor:completionHandler: below, which is not a spelling any SDK
// declares.
- (void)openToPlayQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor {
    (void)queueDescriptor;
}

- (void)openToPlayQueueDescriptor:(MPMusicPlayerQueueDescriptor *)queueDescriptor
               completionHandler:(void (^)(NSError *))completionHandler {
    (void)queueDescriptor;
    if (!completionHandler) {
        // Apple's block parameter is nonnull in the signature, so a nil handler is a caller that broke
        // its own contract. Returning costs nothing and is the same choice the
        // +[MPMediaLibrary requestAuthorization:] row makes for a nil handler.
        return;
    }
    // The handler is called exactly once, and the error says the one true thing: this could not open
    // anything. MPErrorDomain and MPErrorUnknown are Apple's own, MPErrorDomain's value read from
    // Apple's framework rather than spelled from its name (registry/MediaPlayer/absent_MediaPlayer.json,
    // MPErrorDomain, implemented), and MPErrorUnknown is the enum's own zero (MPError.h:17). The
    // description is the port's own sentence about the situation and carries no value a caller would
    // parse.
    completionHandler([NSError errorWithDomain:MPErrorDomain
                                         code:MPErrorUnknown
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"openToPlayQueueDescriptor: needs a system music player, "
                                                    @"which this release does not have"}]);
}

@end
