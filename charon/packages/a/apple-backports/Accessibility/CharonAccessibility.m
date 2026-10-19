//
//  CharonAccessibility.m
//  Accessibility
//
//  The Accessibility names the port's own SDK does not have, and what each of them answers where
//  this release cannot reach the service behind it. facts/Accessibility/Accessibility.md has the
//  whole of it; the three places that matter here are:
//
//  * **A request is the system's.** +[AXRequest currentRequest] is the request the system's
//    assistive technology is currently serving, and its technology is the one serving it. This
//    release runs no assistive-technology service that holds a current request, so there is none
//    and the class is the container an application keeps its own request in.
//  * **A feature override is a service.** beginOverrideSession… is how an application asks the
//    system to turn grayscale on, or Voice Control on, for a while. The system that does it is not
//    on this release, so the manager answers nil with the error the header's own enumeration has
//    for exactly this - AXFeatureOverrideSessionErrorAppNotEntitled is the wrong one, and
//    Undefined is the one that says nothing: there is no service to be entitled to. A session that
//    cannot exist is not invented so that endOverrideSession: has something to end.
//  * **A braille table is Apple's data.** AXBrailleTable is a table of dot patterns that a
//    provider supplies, and AXBrailleTranslator maps print text onto the table it is given. The
//    table is a value this port cannot invent and the system does not ship in a form a port may
//    read, so +defaultTableForLocale: and the two sets answer empty, and a translation is only
//    what the table says: an input with no table maps to no cells.
//

#import "CharonAccessibility.h"

#import "../../../c/charon-coding/files/CharonCoding.h"

#pragma mark - AXRequest

@implementation AXRequest {
    // An NSString, not an AXTechnology: Apple spells that typedef as NSString *const, so an ivar
    // of that type is a const pointer and could never be assigned. The property's own type is
    // the same object, so the accessor answers it unchanged.
    NSString *_servingTechnology;
}

// The header marks -init unavailable, so a request is built here: the technology that will serve
// it, and the request's own storage.
- (instancetype)charon_withTechnology:(AXTechnology)technology
{
    // Not an initialiser by its name, so it cannot chain to -init the way an initialiser does; it
    // builds through the allocation and sets what it was given, which is the same object the
    // header's -init NS_UNAVAILABLE means only that there is no argument-less one.
    AXRequest *request = [[AXRequest alloc] init];
    [request charon_setTechnology:technology];
    return request;
}

- (void)charon_setTechnology:(AXTechnology)technology
{
    _servingTechnology = [technology copy];
}

- (AXTechnology)technology
{
    return _servingTechnology;
}

+ (AXRequest *)currentRequest
{
    // Nothing on this release is serving a request, so there is no current one. The container
    // below is how an application keeps the request it is answering, which is what the property
    // is for on a release that has an assistive technology to ask.
    return nil;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        charon_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    charon_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    AXRequest *copy = [[AXRequest allocWithZone:zone] charon_withTechnology:_servingTechnology];
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<AXRequest technology %@>", _servingTechnology ?: @"(none)"];
}

@end
