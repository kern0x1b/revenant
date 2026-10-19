#import <Foundation/Foundation.h>

#import <objc/runtime.h>
#import "CharonMorphology.h"

@implementation NSInflectionRuleExplicit
{
    NSMorphology *_morphology;
}

- (instancetype)initWithMorphology:(NSMorphology *)morphology
{
    // -[NSInflectionRule init] is NS_UNAVAILABLE in the header - the class is abstract - so the
    // subclass's designated initialiser cannot go through [super init] and reaches NSObject's own
    // instead. The host's own -copyWithZone: on this class refuses as though it were abstract (measured),
    // and that refusal is in the base class below.
    // [self class], not the name: the class object of the receiver is this class whatever it is
    // called, where a lookup by name finds the other one of the two when both exist.
    self = class_createInstance([self class], 0);
    if (self)
        _morphology = [morphology copy];
    return self;
}

- (NSMorphology *)morphology { return _morphology; }

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_morphology forKey:@"morphology"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    // For the same reason as the designated initialiser: -init is unavailable on the abstract base.
    // [self class], not the name: the class object of the receiver is this class whatever it is
    // called, where a lookup by name finds the other one of the two when both exist.
    self = class_createInstance([self class], 0);
    if (self)
        _morphology = [[coder decodeObjectOfClass:[NSMorphology class] forKey:@"morphology"] copy];
    return self;
}

@end
