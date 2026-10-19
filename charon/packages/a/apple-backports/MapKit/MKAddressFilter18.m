#import <MapKit/MapKit.h>
#import <Foundation/Foundation.h>
#import "CharonMapKit.h"

@implementation MKAddressFilter {
    NSUInteger _includingOptions;
    NSUInteger _excludingOptions;
}

+ (instancetype)filterIncludingAll
{
    return [[[self alloc] init] charon_setIncluding:0 excluding:0];
}

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
