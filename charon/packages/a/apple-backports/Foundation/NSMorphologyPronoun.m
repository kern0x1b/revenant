#import <Foundation/Foundation.h>

#import "CharonMorphology.h"

@implementation NSMorphologyPronoun
{
    NSString *_pronoun;
    NSMorphology *_morphology;
    NSMorphology *_dependentMorphology;
}

- (instancetype)initWithPronoun:(NSString *)pronoun
                      morphology:(NSMorphology *)morphology
              dependentMorphology:(NSMorphology *)dependentMorphology
{
    self = [super init];
    if (self) {
        _pronoun = [pronoun copy];
        _morphology = [morphology copy];
        _dependentMorphology = [dependentMorphology copy];
    }
    return self;
}

- (NSString *)pronoun { return _pronoun; }
- (NSMorphology *)morphology { return _morphology; }
- (NSMorphology *)dependentMorphology { return _dependentMorphology; }

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithPronoun:_pronoun
                                                 morphology:_morphology
                                         dependentMorphology:_dependentMorphology];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_pronoun forKey:@"pronoun"];
    [coder encodeInteger:_morphology.grammaticalGender forKey:@"grammaticalGender"];
    [coder encodeInteger:_morphology.partOfSpeech forKey:@"partOfSpeech"];
    [coder encodeInteger:_morphology.number forKey:@"number"];
    [coder encodeInteger:_morphology.grammaticalCase forKey:@"grammaticalCase"];
    [coder encodeInteger:_morphology.determination forKey:@"determination"];
    [coder encodeInteger:_morphology.grammaticalPerson forKey:@"grammaticalPerson"];
    [coder encodeInteger:_morphology.pronounType forKey:@"pronounType"];
    [coder encodeInteger:_morphology.definiteness forKey:@"definiteness"];
    [coder encodeObject:_morphology forKey:@"morphology"];
    [coder encodeObject:_dependentMorphology forKey:@"dependentMorphology"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _pronoun = [[coder decodeObjectOfClass:[NSString class] forKey:@"pronoun"] copy];
    NSMorphology *morphology = [[NSMorphology alloc] initWithCoder:coder];
    _morphology = morphology;
    _dependentMorphology = [[coder decodeObjectOfClass:[NSMorphology class] forKey:@"dependentMorphology"] copy];
    return self;
}

@end
