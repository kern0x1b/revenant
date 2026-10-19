// MPMediaPlaylistPropertySeedItems, the 3.0 band's MediaPlayer string constant, one of one.
//
// THE BAND IS 3.0 AND THE PROPERTY IS 8.0, and both are kept because the disagreement is real and the tool
// settles it. `tools/cache-index/first-rung.lua _MPMediaPlaylistPropertySeedItems` answers 3.0 - the oldest
// HELD release that carries the name - while the property that reads it, MPMediaPlaylist.seedItems, is
// MP_API(ios(8.0)). A first draft put this constant in MediaPlayerConstants80.m beside that property, and
// `tools/release-split.lua` refused the object:
//
//     MediaPlayerConstants80.o  _MPMediaPlaylistPropertySeedItems            3.0
//     MediaPlayerConstants80.o  _MPNowPlayingInfoPropertyDefaultPlaybackRate 8.0
//     MediaPlayerConstants80.o  MIXED-RELEASES  3.0,8.0
//
// which is the check earning its place: the band is read from the release ladder symbol by symbol and not
// from the header's annotation, and a file holding two of them is one object for two releases. This file
// is the 3.0 object and MediaPlayerConstants80.m keeps only the 8.0 constant it already had.
//
// The reason the two disagree is visible in the headers and is worth recording, because it is the same
// observation the seedItems row's own source makes: MPMediaPlaylistPropertySeedItems is declared in
// MPMediaPlaylist.h with NO MP_API annotation at all, while MPNowPlayingInfoPropertyDefaultPlaybackRate
// carries one. An unannotated extern is unversioned, so the name belongs to no release later than the
// header that declares it - and the ladder agrees, answering 3.0 rather than 8.0.
//
// THE VALUE WAS READ, NOT DERIVED, and the reading is what this file exists to record. The port's
// convention for these keys has been "the value is the property's own name", and that convention is FALSE
// for two keys in the tree beside it: facts/MediaPlayer/MediaPlayerConstants.md:8-12 records that
// MPMediaPlaylistPropertyAuthorDisplayName is "externalVendorDisplayName" and
// MPMediaPlaylistPropertyDescriptionText is "descriptionInfo" - neither is the name of the constant nor of
// the property. A value spelled from this key's name would have been a guess dressed as a fact.
//
// Read from Apple's own framework, and the reader is shown live by printing those two known values in the
// same run (tests/backports/host/mediaplayeritem/seedkey.m, which links MediaPlayer and prints three values
// and a negative control):
//
//   MPMediaPlaylistPropertySeedItems          seedItems
//   MPMediaPlaylistPropertyAuthorDisplayName  externalVendorDisplayName
//   MPMediaPlaylistPropertyDescriptionText    descriptionInfo
//   MPMediaPlaylistPropertyAKeyNoFrameworkHas (nil)
//
// So for THIS key the convention happens to hold, and that is a fact about this key rather than a rule -
// which is the reason it had to be read at all. One key of the three holds its own name; the other two do
// not.
//
// It shadows nothing: 6.1.3 exports none of MediaPlayer's 36 constants, so the port carries this one, and
// first-rung answers 3.0 - a release the port targets - so there is no band on this port that should have
// had the symbol from the release instead.
//
// Declared HERE, with the plain extern, and MediaPlayer.h is deliberately NOT imported: with -I on the port's
// own tree that import resolves to the PORT's shim rather than the SDK's - the same reason
// MediaPlayerConstants93.m gives. MPMediaPlaylist80.m, whose -seedItems reads the value through
// -valueForProperty:, imports the framework itself.
//
// A constant is READ, never CALLED. Nothing here touches MPMediaLibrary, MPMediaQuery or a library.

#import <Foundation/Foundation.h>

extern NSString *const MPMediaPlaylistPropertySeedItems;

NSString *const MPMediaPlaylistPropertySeedItems = @"seedItems";
