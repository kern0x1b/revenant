#import "CharonVision.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
#pragma clang diagnostic ignored "-Wnullability-completeness"

/* Vision of iOS 11.0, and only that. One request is here and one only, and it is here because of the
 * release rather than because of its header:
 *
 *   VNDetectHumanRectanglesRequest.h annotates the class API_AVAILABLE(ios(13.0)), and the 16.4 SDK
 *   surface this registry was read from says 13.0 too. But 11.0's own Vision already exports the class
 *   -- tools/cache-index/first-rung.lua answers 11.0 for it, and the census of 11.0 in
 *   facts/Vision/Absence.md section 1 finds it among 155 VN* classes, beside VNHumanObservation and
 *   VNHumanDetector. A release can carry a class before the release that declares it public.
 *
 * release-split reads the release and not the header, and it is the stricter of the two: a file whose
 * symbols first appear in more than one release is refused, and this one did refuse -- 27 symbols
 * reading 11.0 and 16.0 together in what used to be Vision130.m. So the class and everything defined
 * inside its own @implementation come here, and Vision130.m holds the 13.0 names, and neither file
 * crosses into the other.
 *
 * The recogniser behind it is Apple's own and Apple has published no source for Vision, so what the
 * port carries is the class, its properties and its revision table: NSClassFromString answers it,
 * alloc makes one, +supportedRevisions and -revision answer from VNRequests.m's own table, and running
 * one comes back from the request handler as VNErrorNotImplemented. Every measurement is in
 * facts/Vision/Absence.md with the command beside it.
 */

/* The upper body alone, which is what the request looks for unless a caller asks for the whole person.
 * Zero is not that: the property's own header says the default is YES, so it is written down here
 * rather than left to whatever a freshly synthesised ivar holds. */
@implementation VNDetectHumanRectanglesRequest {
    BOOL _upperBodyOnly;
}

- (instancetype)initWithCompletionHandler:(VNRequestCompletionHandler)completionHandler
{
    if ((self = [super initWithCompletionHandler:completionHandler]))
        _upperBodyOnly = YES;
    return self;
}

@end
