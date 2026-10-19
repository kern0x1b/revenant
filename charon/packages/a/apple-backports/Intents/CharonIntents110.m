//
//  CharonIntents110.m
//  Intents
//
//  The one class of the iOS 11.0 group whose behaviour is more than storage, and the one member
//  of the iOS 10.0 group that takes it. What each of them answers, and what this release cannot,
//  is in facts/Intents/Intents.md.
//

#import <Intents/Intents.h>
#import <Intents/INParameter.h>
#import <objc/runtime.h>

#import "../../../c/charon-coding/files/CharonCoding.h"

#pragma mark - INParameter

@implementation INParameter {
    Class _parameterClass;
    NSString *_parameterKeyPath;
    NSMutableDictionary *_indicesBySubKeyPath;
}

@synthesize parameterClass = _parameterClass;
@synthesize parameterKeyPath = _parameterKeyPath;

+ (instancetype)parameterForClass:(Class)aClass keyPath:(NSString *)keyPath
{
    // The parameter is a class and a key path into it, and nothing else: that is what the header's
    // own two properties say, and an application that donates an interaction with this parameter
    // has said which of its values the parameter is and where in it the value is.
    INParameter *parameter = [[self alloc] init];
    parameter->_parameterClass = aClass;
    parameter->_parameterKeyPath = [keyPath copy];
    return parameter;
}

- (BOOL)isEqualToParameter:(INParameter *)parameter
{
    // Two parameters are the same parameter when they name the same class and the same key path,
    // which is the whole of what a parameter is.
    if (parameter == self) {
        return YES;
    }
    if (![parameter isKindOfClass:[INParameter class]]) {
        return NO;
    }
    return _parameterClass == parameter->_parameterClass &&
        (_parameterKeyPath == parameter->_parameterKeyPath ||
         [_parameterKeyPath isEqualToString:parameter->_parameterKeyPath]);
}

- (void)setIndex:(NSUInteger)index forSubKeyPath:(NSString *)subKeyPath
{
    if (!subKeyPath) {
        return;
    }
    if (!_indicesBySubKeyPath) {
        _indicesBySubKeyPath = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    _indicesBySubKeyPath[subKeyPath] = @(index);
}

- (NSUInteger)indexForSubKeyPath:(NSString *)subKeyPath
{
    // No index is NSNotFound's own answer: a sub key path that was never given an index has no
    // index, and the header's NSUInteger return has no other way of saying so.
    return subKeyPath ? [_indicesBySubKeyPath[subKeyPath] unsignedIntegerValue] : NSNotFound;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<INParameter %@ %@>",
            _parameterClass ? [NSString stringWithCString:class_getName(_parameterClass) encoding:NSUTF8StringEncoding] : @"",
            _parameterKeyPath];
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
    INParameter *copy = [[[self class] allocWithZone:zone] init];
    charon_intents_copy(copy, self);
    return copy;
}

@end
