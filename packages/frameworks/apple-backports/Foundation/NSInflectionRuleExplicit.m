#import <Foundation/Foundation.h>

#import <objc/runtime.h>
#import "RevenantMorphology.h"

@implementation NSInflectionRuleExplicit
{
    NSMorphology *_morphology;
}

- (instancetype)initWithMorphology:(NSMorphology *)morphology
{
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
    self = class_createInstance([self class], 0);
    if (self)
        _morphology = [[coder decodeObjectOfClass:[NSMorphology class] forKey:@"morphology"] copy];
    return self;
}

@end
