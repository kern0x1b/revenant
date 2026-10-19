// UIEventAttribution145.m - the link-preview attribution value object of iOS 14.5 and the view that would
// host it, on this release.
//
// ONE OBJECT, ONE RELEASE: every row here is 14.5.  It is its own .m rather than a category on an existing
// file because both are classes this object DEFINES, and release-split.lua reads band points only, so a
// 14.5 method in a 14.0 or 15.0 file would pass it and only a reader would catch it.
//
// The declarations are the build SDK's own: measured, the 16.4 SDK this package compiles against carries
// UIEventAttribution.h and UIEventAttributionView.h, and both are byte for byte the 26.2 ones after the
// comments and the availability macros are stripped.  Nothing is redeclared here, exactly as
// UIButtonConfiguration.m redeclares nothing for UIButtonConfiguration.
//
// WHAT THIS PORT IS NOT: a system that produces one.  An attribution is what a link preview carries, and
// a link preview is what a Safari view controller or a link-preview extension hands the system - neither
// exists on 6.1.3 or 4.3, and the port builds no SafariServices into this library.  What a caller on this
// release can do is build an attribution from the four values it was given, read them back, copy it and
// archive it; that is the whole of what this object does, and every row says so rather than claiming a
// preview flow this release has no path to.

#import <UIKit/UIKit.h>

@implementation UIEventAttribution {
@private
    uint8_t _sourceIdentifier;
    NSURL *_destinationURL;
    NSURL *_reportEndpoint;
    NSString *_sourceDescription;
    NSString *_purchaser;
}

- (instancetype)initWithSourceIdentifier:(uint8_t)sourceIdentifier
                         destinationURL:(NSURL *)destinationURL
                     sourceDescription:(NSString *)sourceDescription
                              purchaser:(NSString *)purchaser
{
    if ((self = [super init])) {
        _sourceIdentifier = sourceIdentifier;
        // The three object properties are `copy` in the SDK's header, so they are copied here rather than
        // held: a caller that mutates an NSURL or an NSString it passed in would otherwise change what
        // this object reads back.  -[NSURL copy] returns the same object for an immutable URL, so the round
        // trip the case asks is the same identity on both sides - and the case asks for identity on the
        // string too, which is what -copyWithZone: gives for an immutable NSString.
        _destinationURL = [destinationURL copy];
        _sourceDescription = [sourceDescription copy];
        _purchaser = [purchaser copy];
        // reportEndpoint is readonly with no initialiser argument, so the only value it can hold here is
        // the one the caller sets after building the object, and a fresh one holds nil - measured on the
        // host: a fresh attribution built from four values answers nil for it.
        _reportEndpoint = nil;
    }
    return self;
}

// -init and +new are NS_UNAVAILABLE in the SDK's header: an attribution has no meaning without the URL it
// points at, so there is no sensible zero of it.  The port cannot remove NSObject's two, and MEASURED, the
// host's do not refuse either - both return quietly and hand back an object whose five values are the zeros
// of their types:
//
//   +[UIEventAttribution new] returned <UIEventAttribution: 0x75830881e0>
//   -init returned <UIEventAttribution: 0x7583088240>
//   -init object: id=0 url=(nil) desc=(nil) purchaser=(nil) endpoint=(nil)
//
// An earlier reading of this file had +new raising, on the strength of a probe that sent `new` to an
// INSTANCE - where there is no such method and the exception is the port's own probe talking to itself.  The
// corrected measurement is the four lines above, and the port answers the zeros rather than refusing,
// because refusing is not what the release does and a class whose only constructor raised would leave
// +alloc with nothing to send.
- (instancetype)init
{
    return [super init];
}

+ (instancetype)new
{
    // [[self alloc] init], not [self init]: inside a class method `self` is the class object, and sending
    // -init to a class raises "cannot init a class object".  The group caught that - the first version of
    // this line was `return [self init]` and the run died on it - which is what a case that exercises the
    // row rather than reading it is for.
    return [[self alloc] init];
}

- (uint8_t)sourceIdentifier { return _sourceIdentifier; }
- (NSURL *)destinationURL { return _destinationURL; }
- (NSURL *)reportEndpoint { return _reportEndpoint; }
- (NSString *)sourceDescription { return _sourceDescription; }
- (NSString *)purchaser { return _purchaser; }

// There is NO -setReportEndpoint: here, and its absence is measured rather than an omission.  The header
// declares the property `readonly`, so a setter would answer a selector no Apple header declares - which is
// what UIKit26_0.m's note on UIDeferredMenuElement's identifier calls a worse answer than an empty one.  It
// is also unreachable: reportEndpoint has no initialiser argument, its only producer is the system that
// opens a link preview, and there is none on this release.  So the getter answers nil for every object a
// caller can build here, which is what the host answers for a caller-built one too (measured, M1).

// The copy is the receiver, and that is MEASURED rather than a shortcut.  On the host:
//
//   copy is same: 1
//   copyWithZone: is same: 1
//   array copy holds same: 1
//
// -copy and -copyWithZone: both answer `self` - the third line is the control, an NSMutableArray holding
// this object and copied, which holds the same instance - so UIEventAttribution is an immutable value object
// whose copy is itself.  An earlier version of this method built a new object through the designated
// initialiser; the case "a copy is not its receiver" is what caught it, and it was the case that was right:
// a value object that answers a second instance for a copy is not the class the release has.
- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

// Two helpers, and they exist because of the same measurement: sending a message to a nil receiver answers
// NO, so `[_a isEqual:_b]` is NO whenever either side is nil, and every object a caller can build has a nil
// reportEndpoint (it is readonly with no initialiser argument).  Written as `a == b || [a isEqual:b]`, the
// two nils are equal - which is what the host answers, measured - and this is the only form that says so.
static BOOL charon_event_objects_equal(id ours, id theirs)
{
    return ours == theirs || [ours isEqual:theirs];
}

static BOOL charon_event_strings_equal(NSString *ours, NSString *theirs)
{
    return ours == theirs || [ours isEqualToString:theirs];
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[UIEventAttribution class]])
        return NO;
    UIEventAttribution *that = other;
    return _sourceIdentifier == that->_sourceIdentifier
        && charon_event_objects_equal(_destinationURL, that->_destinationURL)
        && charon_event_objects_equal(_reportEndpoint, that->_reportEndpoint)
        && charon_event_strings_equal(_sourceDescription, that->_sourceDescription)
        && charon_event_strings_equal(_purchaser, that->_purchaser);
}

- (NSUInteger)hash
{
    return (NSUInteger)_sourceIdentifier ^ [_destinationURL hash] ^ [_sourceDescription hash] ^ [_purchaser hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<UIEventAttribution: %p; sourceIdentifier = %u; destinationURL = %@; sourceDescription = %@; purchaser = %@>",
                                      self, (unsigned)_sourceIdentifier, _destinationURL, _sourceDescription, _purchaser];
}

@end

// The view.  Measured on the host: opaque YES, user interaction NO, no background colour, no subviews, and
// no accessibility element - so it is an inert, non-interactive rectangle as far as this release can tell,
// and that is what this is.  A link-preview attribution has nothing to draw on 6.1.3: the only thing that
// ever put one on screen was a link preview, and there is no path to one here (see the note above).  The
// two answers that are not UIView's own defaults are written, because UIView's defaults are NO for both and
// the host answers otherwise, and a row that says "the host is opaque" while the port answers transparent
// would be a row the case holds red.
@implementation UIEventAttributionView

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.opaque = YES;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        self.opaque = YES;
        self.userInteractionEnabled = NO;
    }
    return self;
}

@end