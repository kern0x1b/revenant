#import "CharonVision.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"
/* VNRecognizeAnimalsRequest's own header marks +knownAnimalIdentifiersForRevision:error: deprecated
 * in 15.0, so declaring it here warns in this file whatever the caller does. VNRequests.m ignores the
 * same warning for the same reason. */
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
/* The class method below is declared on VNDetectFaceLandmarksRequest's own interface, so a category
 * on that class draws this warning whether or not the interface's implementation defines it -- and
 * it does not: VNRequests.m's @implementation of the class is empty, and nm on its object finds no
 * selector named supportsConstellation at all. The warning is per translation unit and cannot see
 * the other file, and there is one definition of the method in this library. */
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

/* Vision of iOS 13.0, and only that: the names this object carries are the ones no earlier release
 * exports -- every symbol below first appears in the 16.0 arm64e cache, which is the first held rung
 * after the hole where 13.0, 14.0 and 15.0 would sit -- and every measurement behind them is in
 * facts/Vision/Absence.md with the command that produced it.
 *
 * A release that has Vision cannot be told what to do about any of it from a header, because the
 * recognisers behind these requests are Apple's own and Apple has published no source for Vision at
 * all (coordination/corpus/sources.md, measured 2026-09-30). What IS knowable is the shape: the two
 * releases this port deploys on carry no Vision image whatever, so a name here is a name the release
 * has never heard of, and the question each row answers is what this port does with it.
 *
 * What each answer below is:
 *   - VNElementTypeSize and the two animal identifiers answer with values measured out of a Vision
 *     image and not out of a name (the name of a constant is never its value);
 *   - +revision:supportsConstellation: answers the truth table Apple's own answers, for the pairs
 *     Apple's own Vision was asked about;
 *   - the precision and recall addition answers NO, which is what the gate its own header describes
 *     says a caller must read before sending the two methods beside it;
 *   - a request class is declared and its revision table answers from the port's own, and running it
 *     comes back from the request handler as VNErrorNotImplemented -- the refusal every request of
 *     iOS 11 and 12 this port cannot run already answers with, so a caller tests an error rather
 *     than losing the process to an unrecognised class.
 *
 * Every METHOD the headers of these twelve classes declare is written down here as well as every
 * property, because clang synthesises a property and never a method. Four of them are:
 *
 *   - +knownAnimalIdentifiersForRevision:error: answers the two identifiers this file exports, which
 *     is all of the list, and refuses a revision the port's own table does not carry;
 *   - -topCandidates:, -boundingBoxForRange:error: and -computeDistance:toFeaturePrintObservation:error:
 *     each answer for an observation of the port's own that carries nothing, which is what Apple
 *     answers for the same class with nothing in it (measured for the first two; the third cannot be
 *     measured, because this host's Vision does not instantiate VNFeaturePrintObservation at all, and
 *     the method says so where a reader of it is).
 *
 * Three methods these headers declare are NOT written down, and the reason is written down with them
 * in facts/Vision/Absence.md section 7: each reports a catalogue this port does not have -- 1303
 * classification names, and the language codes of a text recogniser -- and a list of another
 * release's copied in would be a wrong answer rather than a missing one.
 */

/* The identifiers an animal recognition answer carries, with the texts Apple's Vision gives them.
 *
 * "Cat" and "Dog", measured twice and read the same way both times: out of the Vision image of the
 * 16.0 arm64e cache through the exported symbol, whose value is a CFString (tools/corpus/
 * cache-value.lua), and out of the Vision of this host through VNAnimalIdentifierCat itself. The
 * capital is the capital and nothing else -- the name of the constant is not the text it names, and
 * a caller that compares an observation's identifier against these needs the text, not the name. */
VNAnimalIdentifier const VNAnimalIdentifierCat = @"Cat";
VNAnimalIdentifier const VNAnimalIdentifierDog = @"Dog";

/* How many bytes one element of a feature print's data takes.
 *
 * The enumeration names three cases and this answers the width of each, with 0 for the unknown one
 * and for every argument the enumeration does not name. Measured against the Vision of this host
 * over the arguments 0 to 4: 0 gives 0, 1 gives 4, 2 gives 8, and 3 and 4 give 0. The widths are
 * sizeof rather than literals so that the answer is the width of the type on the release that asks,
 * which is the whole of what the function is for. */
NSUInteger VNElementTypeSize(VNElementType elementType)
{
    switch (elementType) {
        case VNElementTypeFloat:
            return sizeof(float);
        case VNElementTypeDouble:
            return sizeof(double);
        case VNElementTypeUnknown:
            break;
    }
    return 0;
}

/* Which constellations of face landmarks a revision of the face landmarks request maps a face with.
 *
 * Apple's own answers, for every pair of a revision from 1 to 4 and a constellation from not-defined
 * through 76 points: revisions 1, 2 and 3 map a face with 65 points, revision 3 alone also with 76,
 * and not-defined for none of them. Every other pair is NO as well, which is what Apple's own Vision
 * answers and not this port declining anything.
 *
 * That this port carries revisions 1 and 2 of the request and not revision 3 is a different question
 * from the one asked here, and it is answered where it belongs: a request handler refuses a revision
 * the port does not carry with VNErrorUnsupportedRevision, which VNRequests.m's own revision table
 * decides. */
@implementation VNDetectFaceLandmarksRequest (CharonVision130Constellation)

+ (BOOL)revision:(NSUInteger)requestRevision supportsConstellation:(VNRequestFaceLandmarksConstellation)constellation
{
    if (constellation == VNRequestFaceLandmarksConstellation65Points)
        return requestRevision >= 1 && requestRevision <= 3;
    if (constellation == VNRequestFaceLandmarksConstellation76Points)
        return requestRevision == 3;
    return NO;
}

@end

/* The precision and recall a classification can be read at. This port runs a Core ML classifier,
 * which answers one score per class, and a curve is those same scores swept across thresholds of
 * themselves: there is no set of scores here and so no operation points to compare, which is the
 * whole of what the three answers below say.
 *
 * The property is the gate its own header describes: when it is YES, every other precision/recall
 * method in this addition may be called, so answering NO is what keeps
 * a caller from sending the two methods, and the two answering NO is what a caller that sends them
 * anyway gets rather than an answer about a curve that is not there. */
@implementation VNClassificationObservation (CharonVision130PrecisionRecall)

- (BOOL)hasPrecisionRecallCurve
{
    return NO;
}

- (BOOL)hasMinimumPrecision:(float)minimumPrecision forRecall:(float)recall
{
    return NO;
}

- (BOOL)hasMinimumRecall:(float)minimumRecall forPrecision:(float)precision
{
    return NO;
}

@end

/* The two requests the measured values above belong to: an animal recognition answer carries one of
 * the two identifiers, and a feature print's data is the array of elements whose type this answers.
 * Each is a VNImageBasedRequest, which is what its own header declares it to be, so a caller builds
 * it the way it builds every other image request and the request handler takes it. The feature print
 * request's own default is written down beside it above. */
@implementation VNRecognizeAnimalsRequest

/* Which animals a revision of this request can answer with. This is one of the three catalogue
 * methods the 13.0 headers declare, and the only one of them this port can answer, because the
 * catalogue it reports is the two identifiers above and those are the whole of it.
 *
 * Apple's own Vision answers exactly two for every revision it carries -- "Cat,Dog", measured for
 * each of revisions 1 and 2, which are the two its own table holds -- and answers nothing with
 * com.apple.Vision 16 for a revision it does not carry, which is VNErrorUnsupportedRevision and the
 * code this port's own revision table refuses with. So the list is the two constants and the
 * unsupported revision is refused from VNRequests.m's own table rather than from a second one
 * written down here. */
+ (NSArray<VNAnimalIdentifier> *)knownAnimalIdentifiersForRevision:(NSUInteger)requestRevision error:(NSError **)error
{
    if (![[self supportedRevisions] containsIndex:requestRevision]) {
        if (error)
            *error = charon_vision_error(VNErrorUnsupportedRevision, [NSString stringWithFormat:@"%@ does not support Revision%lu",
                                                                           NSStringFromClass(self), (unsigned long)requestRevision]);
        return nil;
    }
    return @[VNAnimalIdentifierCat, VNAnimalIdentifierDog];
}

@end

/* The requests of 13.0, each declared over VNImageBasedRequest by its own header and each with
 * exactly one revision in 13.0, so the port's own revision table places every one of them without a
 * revision of its own. The classifier, the face capture quality, the two saliency maps, the animals,
 * the text and the feature print are Apple's own models, and there is no source for any of them.
 *
 * Ten of them, and not the eleventh: VNDetectHumanRectanglesRequest is annotated ios(13.0) here too,
 * but 11.0's Vision already exports the class, so it and its properties live in Vision110.m. A file
 * whose symbols first appear in more than one release is refused by release-split, and this one was.
 *
 * Two of them are declared conforming to a protocol by their own headers, and declaring a class
 * whose header names a protocol puts that protocol in the class's own conformance list at run time:
 * -conformsToProtocol: and -instancesRespondToSelector: answer for it whether or not this port writes
 * the selector down. So each member those protocols declare is written down here, and a row is
 * registered for it. A class that answered YES to a protocol and then raised on the protocol's own
 * selector would be worse than a class that were not there. */
@implementation VNClassifyImageRequest
@end

/* VNFaceObservationAccepting's inputFaceObservations, which is this class's own API by its header's
 * declaration. VNDetectFaceLandmarksRequest carries the same property in VNRequests.m, and this is
 * that one again for the request that scores a face rather than the one that maps it. */
@implementation VNDetectFaceCaptureQualityRequest {
    NSArray *_inputFaceObservations;
}
@synthesize inputFaceObservations = _inputFaceObservations;
@end

@implementation VNGenerateAttentionBasedSaliencyImageRequest
@end

@implementation VNGenerateObjectnessBasedSaliencyImageRequest
@end

/* The request that answers with the feature print observation whose element type VNElementTypeSize
 * answers for. Zero is not this request's own default either: VNImageCropAndScaleOptionScaleFill is
 * 2, and the header says ScaleFill is the default, so a fresh ivar's 0 -- which is CenterCrop --
 * would answer with the other option. */
@implementation VNGenerateImageFeaturePrintRequest {
    VNImageCropAndScaleOption _imageCropAndScaleOption;
}

- (instancetype)initWithCompletionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler]))
        _imageCropAndScaleOption = VNImageCropAndScaleOptionScaleFill;
    return self;
}

@end

/* VNRequestProgressProviding's two members, which this class's own header declares it conforming to.
 * The handler a caller installs is kept and handed back; the request cannot be run here, so it is
 * never called, and a request that reports no progress is told so rather than left to guess.
 *
 * indeterminate answers NO, which is what Apple's own Vision answers for this class (measured, see
 * facts/Vision/Absence.md section 4). It is asked here of a request this port cannot run at all, and
 * NO is the answer that does not promise fractions of work that will never happen. */
@implementation VNRecognizeTextRequest {
    VNRequestProgressHandler _progressHandler;
}
@synthesize progressHandler = _progressHandler;

- (BOOL)indeterminate
{
    return NO;
}

@end

/* The observations those requests answer with. Each is declared over the superclass its own header
 * names -- VNRectangleObservation for the area a text was read from, VNObservation for the feature
 * print and VNPixelBufferObservation for the saliency map -- so an answer is a kind of the
 * observation this port already answers for, and it inherits that observation's archiving and copying
 * rather than writing a second one. The port fills none of them: there is no model behind any of
 * these requests, so a handler refuses the request and no observation of this port's making appears.
 *
 * Opening a class makes clang synthesise the PROPERTIES its header declares and nothing else, so
 * every property above is answered without a line here and every METHOD its header declares has to be
 * written down: a caller that sends one this object does not define does not get a wrong answer, it
 * loses the process to an unrecognised selector. Two of the three are written down below, and their
 * answers are Apple's own answers for an observation of the same kind with nothing in it, measured
 * (facts/Vision/Absence.md section 4). The third is written down without one, and says why. */
@implementation VNRecognizedTextObservation

/* The candidates of a piece of text, best first. This port's observation carries none -- there is no
 * text recogniser behind any of its requests -- so the answer is an empty array, and that is what
 * Apple's own Vision answers for an observation of this class with nothing in it, for a count of 10
 * and for a count of 0 alike. An empty array rather than nil, because the header does not mark the
 * result nullable: a caller that counts what it gets reads 0 and carries on. */
- (NSArray<VNRecognizedText *> *)topCandidates:(NSUInteger)maxCandidateCount
{
    return @[];
}

@end

@implementation VNFeaturePrintObservation

/* How far apart two feature prints are. This port's print holds no data at all: elementType is
 * Unknown and elementCount is 0, because there is no model behind VNGenerateImageFeaturePrintRequest.
 * There is therefore nothing to compare on either side of the call and NO is the whole of the answer,
 * which is also what Apple answers when two prints are not comparable.
 *
 * It is the one answer below that is NOT measured against Apple's own Vision, and it is written down
 * here rather than left out so that the reason is where a reader of it is: this host's Vision does
 * not hand back an object from [[VNFeaturePrintObservation alloc] init] at all, so every question
 * asked of one reaches nil and nil answers NO (facts/Vision/Absence.md section 4).
 *
 * Both out-parameters are left exactly as the caller passed them. A distance of nothing would be a
 * number the caller would go on to use, and an error would need a code from the Vision domain that
 * no measurement of this port or of any release supports; NO with nothing written is the answer that
 * claims the least. */
- (BOOL)computeDistance:(float *)outDistance toFeaturePrintObservation:(VNFeaturePrintObservation *)featurePrint error:(NSError **)error
{
    return NO;
}

@end

@implementation VNSaliencyImageObservation
@end

/* The text itself, the one observation of this release with nothing above it but NSObject, and so the
 * only one whose protocols the port cannot inherit: its own header declares it over NSObject with
 * NSCopying, NSSecureCoding and VNRequestRevisionProviding. Each of those is written down here.
 *
 * The archiver holds the two properties the header declares on the class and the revision, keyed the
 * way this library keys every other observation -- by the class and the property -- so an archive
 * written here cannot be read as another observation's. Nothing of this port makes one, so no archive
 * exists to read; what the class owes a caller is that archiving, copying and reading back an object
 * of the class answers instead of raising. */
@implementation VNRecognizedText

@synthesize requestRevision = _requestRevision;

/* The box around the characters of a range of this text. The characters are what a text recogniser
 * reports and this port recognises no text, so there are none to draw a box around and the header's
 * own nullable result is nil -- which is what Apple's own Vision answers for a VNRecognizedText with
 * nothing in it, with no error set beside it (facts/Vision/Absence.md section 4). Written down so
 * that a caller reads nil rather than losing the process; the range is accepted and not inspected
 * because there is nothing here it could be inspected against. */
- (VNRectangleObservation *)boundingBoxForRange:(NSRange)range error:(NSError **)error
{
    return nil;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_string forKey:@"VNRecognizedText.string"];
    [coder encodeFloat:_confidence forKey:@"VNRecognizedText.confidence"];
    [coder encodeInteger:(NSInteger)_requestRevision forKey:@"VNRecognizedText.requestRevision"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _string = [[coder decodeObjectOfClass:[NSString class] forKey:@"VNRecognizedText.string"] copy];
        _confidence = [coder decodeFloatForKey:@"VNRecognizedText.confidence"];
        _requestRevision = (NSUInteger)[coder decodeIntegerForKey:@"VNRecognizedText.requestRevision"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    VNRecognizedText *copy = [[VNRecognizedText allocWithZone:zone] init];
    copy->_string = _string;
    copy->_confidence = _confidence;
    copy->_requestRevision = _requestRevision;
    return copy;
}

@end
