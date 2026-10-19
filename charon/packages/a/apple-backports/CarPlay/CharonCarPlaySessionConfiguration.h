// The port's own Charon seam on CPSessionConfiguration, shared by the two objects that hold the class's
// two releases.
//
// CPSessionConfiguration.h is 12.0 at :26-33 and :38 and 13.0 at :36, and an object holds API of exactly
// one release (modules/apple/backports.lua's releases_in, read by `tools/release-split.lua`). So
// CarPlaySessionConfiguration12.m and CarPlaySessionConfiguration13.m are objects of their own, and a
// category cannot add an ivar: the 13.0 value's storage therefore sits with the class's own 12.0 ivars
// and this accessor is how the 13.0 object reaches them.
//
// It is a header rather than a declaration repeated in both files because a category that declares a
// method it does not implement warns (-Wincomplete-implementation), and the tree's own convention for
// exactly this is a Charon<Framework>.h per package. Every name is Charon-prefixed, so none of this is
// API and none of it appears in the library's exports.
#ifndef CHARON_CARPLAY_SESSION_CONFIGURATION_H
#define CHARON_CARPLAY_SESSION_CONFIGURATION_H

#import <CarPlay/CarPlay.h>

@interface CPSessionConfiguration (CharonContentStyle)

// The 13.0 value's storage, read by CarPlaySessionConfiguration13.m's -contentStyle.
//
// A READER AND NO WRITER, deliberately. The header declares the property `readonly` with no public
// setter, and the release's only writer is the private -setContentStyle: on a class conforming to
// CARSessionObserving -- the connected CarPlay system. So a Charon setter here would be a writer nothing
// calls, which is dead code rather than the `inert` a row means: `inert` is about the SYMBOL, and the
// symbol is this getter, which loads and answers. What would write it is a connected head unit, and there
// is none on either fleet device. (The 17.4 members of the navigation session are the opposite case and
// do have Charon writers, because a public readwrite property needs one.)
- (CPContentStyle)charon_contentStyle;

@end

#endif