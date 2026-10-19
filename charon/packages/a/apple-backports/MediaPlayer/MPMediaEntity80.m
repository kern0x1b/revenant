// -[MPMediaEntity objectForKeyedSubscript:], the 8.0 keyed-subscript accessor, over the accessor the
// release already has.
//
// MPMediaEntity.h at SDK 26.2 is the whole contract, quoted:
//
//   // (the header's note: keyed subscripting over the property constants, read-only)
//   - (nullable id)objectForKeyedSubscript:(id)key
//       MP_API(ios(8.0), tvos(14.0))
//       API_UNAVAILABLE(watchos, macos)
//
// The port does not invent a mapping. The key IS the MPMediaItemProperty* / MPMediaEntityProperty*
// constant - the sentence above the declaration says exactly that - and -valueForProperty: takes that
// same key and is the release's own method on MPMediaEntity:
//
//   -[MPMediaEntity valueForProperty:]        MPMediaEntity.h, ios(3.0) era, no MP_API
//
// Measured with tools/mach32_methods.py from the armv7 cache of 6.1.3 (MediaPlayer image at 0x31fe3000):
// MPMediaEntity has 18 own instance methods and 1 own class method and -valueForProperty: is among the 18.
// All 41 of the image's categories were read WITH THE CLASS EACH ONE EXTENDS, resolved through the
// category's own class pointer, and none of them extends MPMediaEntity. So nothing here can clobber the
// release's accessor and nothing in the release clobbers this one.
// -aSelectorNoFrameworkHas is absent as the control, and objectForKeyedSubscript: occurs exactly once in
// the whole 6.1.3 selector universe - on a collection class, not on MPMediaEntity, which is the trap
// facts/MediaPlayer/MPMediaItem.md:105 records for albumTrackNumber: a name in the per-cache list is
// necessary and not sufficient, and the per-class read is what decides a member.
//
// The port's answer is the release's own: a key the release has no value for answers nil, which is what
// -valueForProperty: answers and what the header's nullable says. Nothing is invented and nothing is
// defaulted, which is the whole contract of a subscript over a dictionary the entity owns.
//
// One object per release, per band()'s own rule: this file holds the 8.0 member and not the 8.0
// MPMediaItem members, which are MPMediaItem80.m's.

#import <Foundation/Foundation.h>
#if defined(CHARON_MEDIAPLAYER_STANDIN)
#import "MPMediaItemStandin.h"
#else
#import <MediaPlayer/MediaPlayer.h>
#endif

// A CATEGORY on a class the release owns, not an @implementation of it: the release's MPMediaEntity is
// the one that carries -valueForProperty: and the 18 other own methods, and this file adds one selector
// to it. Written as a bare `@implementation MPMediaEntity` it would claim the whole class - clang asks
// for -valueForProperty: and every one of the other 17, which the release has and this file must not
// define. MediaPlayerPickerController+AutomaticPresentation.m is the same idiom in this family.
#if defined(CHARON_MEDIAPLAYER_STANDIN)
// The stand-in declares MPMediaItem and no MPMediaEntity, because the checks that use it only ever
// compile code that reaches the entity through its own -valueForProperty:. The release's shape is
// MPMediaEntity : NSObject (measured: MPMediaEntity's own list, and none of the image's 41 categories
// extends MPMediaEntity), so the stand-in's entity is declared over NSObject and NOT over the item -
// MPMediaItem is MPMediaEntity's subclass on the release, not its superclass, and a stand-in that had
// that the wrong way round would make a check pass for the wrong reason.
@interface MPMediaEntity : NSObject
- (id)valueForProperty:(NSString *)property;
@end
// The SDK's own declaration of the member is not available to the stand-in build, so the contract is
// restated here for it - read from MPMediaEntity.h above, not invented for the check to pass.
@interface MPMediaEntity (Charon80)
- (nullable id)objectForKeyedSubscript:(id)key;
@end
#endif

@implementation MPMediaEntity (Charon80)

- (nullable id)objectForKeyedSubscript:(id)key {
    // The release's own accessor, by the key as given. NSString is the type every MPMediaItemProperty*
    // constant has, and the header types the parameter as plain id because a dictionary subscript is
    // typed as id; a key of another type is forwarded unchanged rather than refused, which is what
    // -valueForProperty: does with it too and what a NSDictionary's own -objectForKeyedSubscript: does.
    return [self valueForProperty:key];
}

@end