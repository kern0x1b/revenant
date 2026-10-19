// UIListSeparatorConfiguration145.m - the list separator configuration of iOS 14.5.
//
// ONE OBJECT, ONE RELEASE: every row here is 14.5.  It is its own .m because it is a class this object
// DEFINES; release-split.lua reads band points only, so a 14.5 method in a 14.0 or 15.0 file would pass it
// and only a reader would catch it.
//
// The declarations are the build SDK's own: the 16.4 SDK this package compiles against carries
// UIListSeparatorConfiguration.h, and it is byte for byte the 26.2 one after the comments and the
// availability macros are stripped.  Nothing is redeclared here.
//
// EVERY DEFAULT BELOW IS MEASURED, not read out of a header, and the header states none of them.  The
// oracle is the host's own UIKit under Mac Catalyst 27.0 (build 26A428), read by the probes in
// .agent-work/runs/b2/ and held to the port by the case in
// tests/backports/host/uikit2/listseparator_test.m; the numbers are in
// facts/UIKit/UIListSeparatorConfiguration145.md, M1.
//
// WHAT PRODUCES ONE: a UICollectionView list.  The port's own list cells draw their separators
// (UICollectionViewListCell.m, which takes charon_semantic_color(CharonSemanticColorSeparator)), so this
// class is the configuration those cells would be handed and what an application sets on a list's
// `separatorConfiguration`.  That is the whole of what it does here - it stores what it was given and
// answers it back - and the row says so rather than claiming the appearance model the host carries.

#import <UIKit/UIKit.h>
#import "CharonLists.h"

// Measured on the host (facts/UIKit/UIListSeparatorConfiguration145.md, M1): the colour of a separator on a
// list and the colour of that separator while several rows are selected are the SAME colour on a light
// interface - both resolve to 0 0 0 0.098, which is also what [UIColor separatorColor] resolves to there.
// The multiple-selection colour is a DYNAMIC colour on the host (a UIDynamicProviderColor, a block over the
// trait collection), so the port makes it a dynamic colour too, over the same role, rather than freezing
// one value that would be wrong in the other appearance.
//
// The two colour NAMES the host uses are 13.0 dynamic catalog entries with no name on 6.1.3 or 4.3, so the
// port reuses what this library already has for that role - charon_semantic_color, whose
// CharonSemanticColorSeparator row is the release's own separator colour measured against iOS and not
// against the Catalyst host.  That is reuse rather than a second copy, and the case compares the ROLE, not
// the name and not the four components, because neither the name nor the components are shared between the
// two releases.
static UIColor *charon_separator_colour(void)
{
    return charon_semantic_color(CharonSemanticColorSeparator);
}

static UIColor *charon_multiple_selection_separator_colour(void)
{
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return charon_separator_colour();
    }];
}

@implementation UIListSeparatorConfiguration {
@private
    UICollectionLayoutListAppearance _listAppearance;
    UIListSeparatorVisibility _topVisibility;
    UIListSeparatorVisibility _bottomVisibility;
    NSDirectionalEdgeInsets _topInsets;
    NSDirectionalEdgeInsets _bottomInsets;
    UIColor *_color;
    UIColor *_multipleSelectionColor;
}

// `visualEffect` is 15.0 and its accessors live in UIListSeparatorConfiguration+VisualEffect15.m. It is
// @dynamic HERE and not synthesised, because the 16.4 SDK declares the property on this class and clang
// would otherwise emit the pair into this object - nm on the object at armv7-apple-ios6.0 showed
// -visualEffect, -setVisualEffect: and _OBJC_IVAR_$_UIListSeparatorConfiguration._visualEffect in a file
// whose every other member is 14.5, and the registry check is right to call that a 14.5 object carrying
// API the release does not have. The ivar auto-synthesis would make is not wanted either: the storage is
// the object's own associated value in the 15.0 object, keyed there, so that the copy the header asks for
// is made once and in one place. The three seams below are where this object reaches that storage.
@dynamic visualEffect;

+ (BOOL)supportsSecureCoding
{
    // Measured: the class answers +supportsSecureCoding YES and a configuration archives through a
    // secure-coding archiver and reads back with every value - 4263 bytes for a plain one.
    return YES;
}

// The designated initialiser, and every value in it is measured:
//
//   the two visibilities are UIListSeparatorVisibilityAutomatic, which is 0;
//   both insets are UIListSeparatorAutomaticInsets, which is 0 top, CGFLOAT_MAX leading, 0 bottom,
//   CGFLOAT_MAX trailing - the release's own constant, already implemented (registry/UIKit/
//   uikit-constants.json), and NOT a zero: an automatic inset is what tells the list to compute it;
//   the colour is the separator colour and the multiple-selection colour is that same role as a dynamic
//   colour.
//
// Measured over ALL FIVE UICollectionLayoutListAppearance values - plain, grouped, inset grouped, sidebar
// and sidebar plain - and they are the same for every one of them, which is why the appearance is stored
// and nothing is switched on it.  The host does raise for an appearance it does not know
// ("UICollectionView internal inconsistency: unknown list appearance style"), and the port does not
// reproduce that refusal: it has no list-appearance model to be inconsistent with, and a refusal the port
// could only fake would be a refusal nobody measured.
- (instancetype)initWithListAppearance:(UICollectionLayoutListAppearance)listAppearance
{
    if ((self = [super init])) {
        _listAppearance = listAppearance;
        _topVisibility = UIListSeparatorVisibilityAutomatic;
        _bottomVisibility = UIListSeparatorVisibilityAutomatic;
        _topInsets = UIListSeparatorAutomaticInsets;
        _bottomInsets = UIListSeparatorAutomaticInsets;
        _color = charon_separator_colour();
        _multipleSelectionColor = charon_multiple_selection_separator_colour();
    }
    return self;
}

// -init and +new are NS_UNAVAILABLE in the SDK's header and this object defines NEITHER, which is
// decided by the class's own method lists and not by the header.
//
// The arm64e shared cache of iOS 16.0, read with modules/apple/objc.lua's inventory: `-init` is NOT in
// UIListSeparatorConfiguration's own instance list and no method named `new` is in its own metaclass
// list - `no-own-init`, `no-own-new`. The controls of that read, because a reader that answered nothing
// would answer this too: `-init` is in the own instance list of 28851 of the cache's classes,
// ARConfiguration among them and NSObject among those, and a method named `new` is in the own metaclass
// list of 523 of them, NSObject itself among those. The coordinator's own class_copyMethodList count on
// the host agrees and is the same shape: 37 instance methods with no `init`, 6 metaclass methods with no
// `new`. The 18.0 cache reads the same - no-own-init, no-own-new, and its own 37 instance methods carry
// -initWithCoder: and -initWithListAppearance: and no `init`, its own 6 metaclass methods no `new` - and its
// census is 37248 and 665, the numbers this band's item 1 measured on that cache. No 14.x cache is held
// here and the class arrived in 14.5, so 16.0 is the oldest release on this machine that carries it.
//
// So a call reaches NSObject's -init, on this release and on Apple's alike, and what it answers is the
// zero of every field: both visibilities 0, both insets 0 0 0 0 - ZERO, where -initWithListAppearance:,
// the header's NS_DESIGNATED_INITIALIZER, gives the automatic ones - and both colours nil. The port
// answers exactly that by defining nothing, which is why those numbers need no code here.
//
// An earlier version of this file DID define both, -init as `[super init]` and +new as
// `[[self alloc] init]`, and the first was also the only warning the package's own line printed on it:
// "convenience initializer should not invoke an initializer on 'super'". Both are gone, and the warning
// with them: the header already marks -initWithListAppearance: NS_DESIGNATED_INITIALIZER, so the class's
// one initializer is a designated one and there is no secondary initializer left to warn about.

- (UIListSeparatorVisibility)topSeparatorVisibility { return _topVisibility; }
- (void)setTopSeparatorVisibility:(UIListSeparatorVisibility)visibility { _topVisibility = visibility; }
- (UIListSeparatorVisibility)bottomSeparatorVisibility { return _bottomVisibility; }
- (void)setBottomSeparatorVisibility:(UIListSeparatorVisibility)visibility { _bottomVisibility = visibility; }
- (NSDirectionalEdgeInsets)topSeparatorInsets { return _topInsets; }
- (void)setTopSeparatorInsets:(NSDirectionalEdgeInsets)insets { _topInsets = insets; }
- (NSDirectionalEdgeInsets)bottomSeparatorInsets { return _bottomInsets; }
- (void)setBottomSeparatorInsets:(NSDirectionalEdgeInsets)insets { _bottomInsets = insets; }
- (UIColor *)color { return _color; }
- (void)setColor:(UIColor *)color { _color = color; }
- (UIColor *)multipleSelectionColor { return _multipleSelectionColor; }
- (void)setMultipleSelectionColor:(UIColor *)color { _multipleSelectionColor = color; }

- (id)copyWithZone:(NSZone *)zone
{
    // Measured: the host's copy is a DIFFERENT object (not self), holds every written value, and holds the
    // same colour INSTANCE the receiver does.  Built through the designated initialiser so the defaults come
    // from one place, then every property is written from the receiver.
    UIListSeparatorConfiguration *copy = [[UIListSeparatorConfiguration allocWithZone:zone] initWithListAppearance:_listAppearance];
    copy.topSeparatorVisibility = _topVisibility;
    copy.bottomSeparatorVisibility = _bottomVisibility;
    copy.topSeparatorInsets = _topInsets;
    copy.bottomSeparatorInsets = _bottomInsets;
    copy.color = _color;
    copy.multipleSelectionColor = _multipleSelectionColor;
    // The visual effect is 15.0 and its storage is in the 15.0 object, so this 14.5 object asks for it
    // rather than naming a member of another release.  No visible @interface for the class, so the call is
    // through the declared protocol: a direct message send of an undeclared selector would be a warning this
    // package's own line counts.
    if ([copy respondsToSelector:@selector(charon_takeVisualEffectFrom:)])
        [copy charon_takeVisualEffectFrom:self];
    return copy;
}

// -isEqual: and -hash are Apple's, and both are in the class's own 37 methods in the iOS 18.0 cache, so
// they are defined here.  What each field joins was measured one field at a time, with a pair that is
// identical apart from that one field (facts/UIKit/UIListSeparatorConfiguration145.md, M5; the probe in
// .agent-work/runs/fix/equality-probe.m):
//
//   field                     joins isEqual:   joins hash
//   topSeparatorVisibility            yes            yes
//   bottomSeparatorVisibility         yes            yes
//   topSeparatorInsets                yes            NO
//   bottomSeparatorInsets             yes            yes
//   color                             yes            yes
//   multipleSelectionColor            yes            yes
//   visualEffect (15.0)               yes            NO
//   the list appearance               NO             NO
//
// The two "NO" in the hash column were re-measured with four value sets each, because one sample cannot
// tell a field left out of the hash from a pair that happened to collide: the top insets and the visual
// effect are out of it every time, the bottom insets are in it every time.
//
// The appearance is the interesting one: it is not compared at all. Two configurations built from DIFFERENT
// appearances and equal in every field are equal - measured, both by writing every field alike (isEqual 1)
// and by writing only multipleSelectionColor alike (isEqual 1) - while two built from different appearances
// with nothing written are NOT, and the difference is their default multipleSelectionColor: on the host it
// is a UIDynamicProviderColor that differs between a plain and a sidebar configuration (measured: the two
// defaults are not isEqual: to each other). Writing either colour except that one leaves the pair unequal.
// So the appearance is carried by that default and by nothing else, which is also why the port's own pair
// from two appearances is EQUAL where the host's is not: the port's dynamic colour is the same role for
// every appearance, there being no list here whose appearance could vary it.

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[UIListSeparatorConfiguration class]])
        return NO;
    UIListSeparatorConfiguration *that = other;
    if (_topVisibility != that->_topVisibility || _bottomVisibility != that->_bottomVisibility)
        return NO;
    // The four doubles each, rather than UIEdgeInsetsEqualToDirectionalEdgeInsets: the SDK has no such
    // function - it was UIEdgeInsetsEqualToEdgeInsets for the older type - so an equality here is written out.
    const NSDirectionalEdgeInsets *top = &_topInsets, *topOther = &that->_topInsets;
    if (top->leading != topOther->leading || top->top != topOther->top ||
        top->bottom != topOther->bottom || top->trailing != topOther->trailing)
        return NO;
    const NSDirectionalEdgeInsets *bottom = &_bottomInsets, *bottomOther = &that->_bottomInsets;
    if (bottom->leading != bottomOther->leading || bottom->top != bottomOther->top ||
        bottom->bottom != bottomOther->bottom || bottom->trailing != bottomOther->trailing)
        return NO;
    // Colours by -isEqual:, not by identity: the host calls two separately made but equal colours equal
    // (measured, isEqual 1), and this port's dynamic colours are fresh objects on every read.
    if (_color != that->_color && ![_color isEqual:that->_color])
        return NO;
    if (_multipleSelectionColor != that->_multipleSelectionColor && ![_multipleSelectionColor isEqual:that->_multipleSelectionColor])
        return NO;
    // The visual effect is 15.0 and its storage is in the 15.0 object.
    if ([self respondsToSelector:@selector(charon_visualEffectIsEqualTo:)])
        return [self charon_visualEffectIsEqualTo:that];
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = (NSUInteger)_topVisibility;
    hash = hash * 31 + (NSUInteger)_bottomVisibility;
    // The BOTTOM insets only, and not the top: measured, four value sets each, and that is what the release
    // answers. It looks like a mistake and it is not - see the table above.
    hash = hash * 31 + (NSUInteger)_bottomInsets.leading;
    hash = hash * 31 + (NSUInteger)_bottomInsets.top;
    hash = hash * 31 + (NSUInteger)_bottomInsets.bottom;
    hash = hash * 31 + (NSUInteger)_bottomInsets.trailing;
    hash = hash * 31 + _color.hash;
    hash = hash * 31 + _multipleSelectionColor.hash;
    return hash;
}

// The keys are the host's own, read out of the host's archive plist (facts/UIKit/
// UIListSeparatorConfiguration145.md, M4): topSepVisibility, bottomSepVisibility, topSepInsets, insets -
// which is the BOTTOM separator's insets, the top one having its own key - color, multiSelectColor and
// visualEffect.
//
// What the host's archive does NOT carry, measured, is the list appearance: the plist has no key for it.
// So neither does this, and that is not an omission either - an archive read back here gets the six values
// above and the appearance it was built with is gone, which is what the host's own archive does.
//
// `visualEffect` is in the host's plist under its own name, and it IS written - through the seam above,
// from the 15.0 object that defines the pair and holds the storage.  It was not written in the first
// version of this file, on the ground that "an archive that carried a key nothing here can answer would
// claim API this library has no row for": the ground was right and the conclusion wrong, because the
// accessors existed all the same, auto-synthesised into this object by the SDK's declaration. A row is a
// statement about the code, not a thing that decides it.
- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_topVisibility forKey:@"topSepVisibility"];
    [coder encodeInteger:_bottomVisibility forKey:@"bottomSepVisibility"];
    [coder encodeObject:[NSValue valueWithBytes:&_topInsets objCType:@encode(NSDirectionalEdgeInsets)]
                forKey:@"topSepInsets"];
    [coder encodeObject:[NSValue valueWithBytes:&_bottomInsets objCType:@encode(NSDirectionalEdgeInsets)]
                forKey:@"insets"];
    [coder encodeObject:_color forKey:@"color"];
    [coder encodeObject:_multipleSelectionColor forKey:@"multiSelectColor"];
    // The host's own archive writes SEVEN keys and the seventh is `visualEffect`, the property's own name -
    // read out of the host's plist, where the object's dictionary is { bottomSepVisibility, color, insets,
    // multiSelectColor, topSepInsets, topSepVisibility, visualEffect }.  15.0, so the 15.0 object writes it.
    if ([self respondsToSelector:@selector(charon_encodeVisualEffectWithCoder:)])
        [self charon_encodeVisualEffectWithCoder:coder];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // The decoded object gets the same defaults the designated initialiser would give and then every value
    // the archive holds, so a configuration read back has the six measured values whatever the archive
    // said, and the appearance stays at the zero - which is what the host's own archive gives, since it
    // carries none.
    if ((self = [self initWithListAppearance:(UICollectionLayoutListAppearance)0])) {
        _topVisibility = (UIListSeparatorVisibility)[coder decodeIntegerForKey:@"topSepVisibility"];
        _bottomVisibility = (UIListSeparatorVisibility)[coder decodeIntegerForKey:@"bottomSepVisibility"];
        NSValue *top = [coder decodeObjectOfClass:[NSValue class] forKey:@"topSepInsets"];
        if (top)
            [top getValue:&_topInsets];
        NSValue *bottom = [coder decodeObjectOfClass:[NSValue class] forKey:@"insets"];
        if (bottom)
            [bottom getValue:&_bottomInsets];
        UIColor *color = [coder decodeObjectOfClass:[UIColor class] forKey:@"color"];
        if (color)
            _color = color;
        UIColor *multiple = [coder decodeObjectOfClass:[UIColor class] forKey:@"multiSelectColor"];
        if (multiple)
            _multipleSelectionColor = multiple;
        if ([self respondsToSelector:@selector(charon_decodeVisualEffectWithCoder:)])
            [self charon_decodeVisualEffectWithCoder:coder];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<UIListSeparatorConfiguration %p visibility: {top: %ld, bottom: %ld}, bottom insets: {l: %g, t: %g}>",
                                      self, (long)_topVisibility, (long)_bottomVisibility,
                                      (double)_bottomInsets.leading, (double)_bottomInsets.top];
}

@end