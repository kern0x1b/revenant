//
//  CharonBrailleMap.m
//  Accessibility
//
//  AXBrailleMap in one object, because one object carries the API of one release and this arrived with
//  15.2. The release has neither the class nor the protocol it names
//  (tools/intents/measure-release-carries.lua: 0 of the framework's 30 classes on 6.1.3 armv7, on 4.3
//  armv7 and on 3.0 armv6, with the control symbol found on all three), so every band builds this file
//  whole, and no Charon header is needed for it: AXBrailleMap.h is in the SDK the package compiles
//  against and is byte-identical to 26.2's.
//
//  A braille map is the state of a connected two-dimensional braille display: a grid of pins, each
//  raised to a height or lowered, and a size. The port carries the grid, the size, a copy and an
//  archive; the one member it cannot do is present an image, because this release has no display to
//  show one on.
//
//  Every rule below was measured against the host's own Accessibility.framework by
//  tests/backports/host/accessibilitymap/run.sh, which builds the same questions against the system's
//  class and against this one and compares the two answers line by line. The facts, and the one place
//  this port answers differently on purpose, are in facts/Accessibility/Accessibility.md.
//
//  Four things about that class are not what its header's spelling suggests, and each was measured:
//
//  * **The pin store keeps whatever it is given.** A height of 2.0 reads back 2.0, one of -1.0 reads
//    back -1.0, a fraction reads back exactly, and a negative point takes one. There is no range check
//    and no bounds check on the host and there is none here: a check the system does not make is a
//    port answering something a caller never asked for.
//  * **The store is real before anything has sized it.** A map obtained by allocation answers a zero
//    size and still keeps its pins, measured, so the store is created when the first pin arrives and
//    not by an initialiser.
//  * **A copy is frozen.** The host's copy answers the same size and the same pins, is unaffected by a
//    write to the original, and refuses a write to itself: it hands over a store that cannot take one,
//    and writing a pin to a copy raises NSInvalidArgumentException out of Foundation, measured twice.
//    The family carries the system's behaviour, so this copy is frozen the same way and by the same
//    route - the copy is handed the store as an immutable dictionary, and -setHeight:atPoint: sends
//    setObject:forKey: to whatever is there. Nothing here throws and nothing here catches: the same
//    Foundation class raises on both sides, which is why the case compares the exception's name and
//    not its text. An application that wrote a pin to a copy crashes on iOS 26 too, so no working
//    application depends on the write landing; the ledger entry at
//    .agent-work/handoffs/better-than-system-accessibility.md keeps the record of what a port that took
//    the write would have given, and that this port does not take it.
//  * **The archive is a real round trip.** The host's own map archives and unarchives with its size and
//    every pin intact, measured over a map with pins and over an empty one, so the port's does the same
//    and asks for secure coding, which the host answers YES to.
//
//  There is one thing the port has and the system does not, and it is named for that: the header marks
//  -init and +new unavailable and gives no other way to make a map, so on the system nothing but the
//  braille display service ever holds one. A caller that wants a map has to be able to ask for one, so
//  the port adds `+charon_mapWithDimensions:` - Charon's own spelling, the arrangement
//  CharonAccessibility.h already uses for AXRequest and AXBrailleTranslationResult - and the SDK's
//  initialisers stay where they are. The case for that factory is a port-only program, because the
//  system cannot be asked to build a map at all.
//

#import "CharonBrailleMap.h"

#import "../CharonSayOnce.h"

// The keys of the pin store, so that a pin is addressed by the point it is at and so that a store can be
// archived. The two coordinates as text, written here rather than taken from a framework: the
// spellings differ between the two SDKs this is compiled against - NSStringFromPoint is a macOS
// function and the iOS one has no name for it - and a key this port reads back has to be the same
// string on both. The key is internal, so nothing outside the port ever sees it.
static NSString *CharonBrailleMapKey(CGPoint point)
{
    return [NSString stringWithFormat:@"%g,%g", point.x, point.y];
}

// What the pin store has to be able to answer, and the reason it is a protocol and not a concrete type:
// an original's store is a mutable dictionary and a copy's is an immutable one, and the write has to
// compile against both. NSDictionary declares no setter at all, so the ivar cannot be typed as one and
// the message sent; NSMutableDictionary lies about the copy. A protocol states what is needed and
// nothing about which class answers it, and the frozen dictionary's refusal of the write is then
// Foundation's own, by the same class and with the same name as the system's.
@protocol CharonBrailleMapPinStore <NSObject>

- (NSNumber *)objectForKey:(NSString *)key;
- (void)setObject:(NSNumber *)value forKey:(NSString *)key;

@end

@implementation AXBrailleMap {
    // The pins, by point. Typed as the immutable dictionary and created mutable on the first write,
    // because the two answers this class has to give are the two shapes: an original takes a write, and
    // a copy of one does not. The write is not checked here - -setHeight:atPoint: sends
    // setObject:forKey: to whatever is there - so a write to a copy raises out of Foundation the way it
    // does on the system, by the same class and with the same name, and not by a throw written here.
    id<CharonBrailleMapPinStore> _pins;
    CGSize _size;
}

// Charon's own spelling, and the only way to make a map that either implementation has: the system's
// comes from the braille service, and there is no braille service on this release.
+ (instancetype)charon_mapWithDimensions:(CGSize)dimensions
{
    AXBrailleMap *map = [[AXBrailleMap alloc] init];
    map->_size = dimensions;
    return map;
}

- (void)setHeight:(float)height atPoint:(CGPoint)point
{
    // Created here and not in an initialiser, because the measured store accepts a pin on a map that
    // nothing has sized: a map obtained by allocation and never sized still keeps what it is given.
    if (!_pins) {
        _pins = (id<CharonBrailleMapPinStore>)[NSMutableDictionary dictionary];
    }
    // Sent as a message and not as a subscript assignment, because that is what reaches a store that
    // cannot take the write: an immutable dictionary has no subscript setter, and the message is what
    // Foundation raises NSInvalidArgumentException for on its frozen dictionaries. The original's store
    // is mutable and takes it; a copy's is not.
    [_pins setObject:@(height) forKey:CharonBrailleMapKey(point)];
}

- (float)heightAtPoint:(CGPoint)point
{
    // A pin that was never written reads lowered, measured: the host answers 0 for a point it has never
    // been given, whatever else has been written to the map.
    return [_pins objectForKey:CharonBrailleMapKey(point)].floatValue;
}

- (CGSize)dimensions
{
    return _size;
}

- (void)presentImage:(CGImageRef)image
{
    (void)image;
    charon_say_once_for(@"AXBrailleMap.presentImage",
                        @"AXBrailleMap -presentImage: this release has no braille display to show an image "
                        @"on, so the image is not presented");
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    // Its own map with the same size and the same pins, measured: a write to the original after the copy
    // leaves the copy answering what it answered before. The host's copy is not writable - it hands over
    // a frozen store and a write to it raises - and this one is, which is the difference the case
    // declares and the ledger entry is about.
    AXBrailleMap *copy = [[AXBrailleMap allocWithZone:zone] init];
    copy->_size = _size;
    // Frozen, and frozen by being the store itself rather than a mutable copy of it: the copy keeps what
    // the original had when the copy was made, which is what the host's copy answers, and a write to it
    // finds an immutable dictionary where the host's copy finds one too. The original keeps its own
    // mutable store and stays writable, measured.
    copy->_pins = _pins ? (id<CharonBrailleMapPinStore>)[NSDictionary dictionaryWithDictionary:(NSDictionary *)_pins] : nil;
    return copy;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    // The host answers YES, measured with +supportsSecureCoding on its own class.
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    // The size and every pin, which is what the host's own round trip carries, measured over a map with
    // pins and over an empty one. The two keys are this port's own: they are not a format a port shares
    // with the system, because a port archive is read by a port and a system archive by the system.
    [coder encodeDouble:_size.width forKey:@"sizeWidth"];
    [coder encodeDouble:_size.height forKey:@"sizeHeight"];
    [coder encodeObject:_pins forKey:@"pins"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _size = CGSizeMake([coder decodeDoubleForKey:@"sizeWidth"],
                           [coder decodeDoubleForKey:@"sizeHeight"]);
        // A WRITABLE store, which is the opposite of what the first version of this comment said: it
        // called an unarchived store frozen, as an intent. Measured on the host, a map that came out of an
        // archive took a write and answered the new height, so the two now agree - a COPY is frozen on
        // both sides, an ARCHIVED map is not on either.
        //
        // The store is the decoder's own dictionary and nothing is copied, and that is a measurement
        // rather than a saving: what an unarchiver hands back for a dictionary is a mutable instance, so
        // a mutableCopy of it here would be a line that changes nothing - and the first version of the
        // mutant for this rule survived because of it, the frozen store it produced behaving exactly like
        // the mutable one. The store that IS frozen is the one a copy hands over, and M14 breaks that.
        _pins = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"pins"];
    }
    return self;
}

@end
