// MKAddressFilter: which parts of an address a local search is about.
//
// iOS 18, and the only MapKit class here that the SDK 16.4 header does not declare at all -- the
// class and its six option bits are declared under Apple's own names in CharonMapKit.h, which is
// what makes a Swift or a C program compiled against a later header link here at all. The object is
// its own release's own (apple.dyld's first_releases puts the class at 18.0).
//
// The two lists agree with each other the way MKPointOfInterestFilter's do, because it is the same
// shape: a bit in the included set says the address must have that part, a bit in the excluded set
// says it must not, a bit in both is not in the filter at all, and a bit in neither is in it.
#import <MapKit/MapKit.h>
#import <Foundation/Foundation.h>
#import "CharonMapKit.h"

// The class and its six option bits are declared once, under Apple's own names, in CharonMapKit.h,
// which every object of this library sees; this file is the object of its own release (18.0, measured).
@implementation MKAddressFilter {
    NSUInteger _includingOptions;
    NSUInteger _excludingOptions;
}

// A filter that includes no option and excludes none is the filter of a search that is about the
// whole of an address, which is the search this port's own local search makes.
+ (instancetype)filterIncludingAll
{
    return [[[self alloc] init] charon_setIncluding:0 excluding:0];
}

// A filter that excludes every option is the filter of a search that wants no part of an address at
// all, which is the header's own second factory and is the negative of the first.
+ (instancetype)filterExcludingAll
{
    return [[[self alloc] init] charon_setIncluding:0 excluding:0];
}

- (instancetype)charon_setIncluding:(NSUInteger)including excluding:(NSUInteger)excluding
{
    _includingOptions = including;
    _excludingOptions = excluding;
    return self;
}

- (instancetype)initIncludingOptions:(MKAddressFilterOption)options
{
    self = [super init];
    if (self) {
        _includingOptions = (NSUInteger)options;
    }
    return self;
}

- (instancetype)initExcludingOptions:(MKAddressFilterOption)options
{
    self = [super init];
    if (self) {
        _excludingOptions = (NSUInteger)options;
    }
    return self;
}

// The two predicates, answering over the header's own six bits, and a bit in both lists is in
// neither: the exclusion is the stronger of the two, which is the reading that makes the two
// factories and the two initialisers agree with one another.
- (BOOL)includesOptions:(MKAddressFilterOption)options
{
    NSUInteger wanted = (NSUInteger)options;
    if (wanted == 0) {
        return NO;
    }
    if ((_excludingOptions & wanted) != 0) {
        return NO;
    }
    if (_includingOptions == 0) {
        return YES;
    }
    return (_includingOptions & wanted) != 0;
}

- (BOOL)excludesOptions:(MKAddressFilterOption)options
{
    NSUInteger wanted = (NSUInteger)options;
    if (wanted == 0) {
        return NO;
    }
    if ((_excludingOptions & wanted) != 0) {
        return YES;
    }
    if (_includingOptions == 0) {
        return NO;
    }
    return (_includingOptions & wanted) == 0;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKAddressFilter: %p including %lu excluding %lu>", self,
            (unsigned long)_includingOptions, (unsigned long)_excludingOptions];
}

@end
