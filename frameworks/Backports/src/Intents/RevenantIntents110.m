#import <Intents/Intents.h>
#import <Intents/INParameter.h>
#import <objc/runtime.h>

#import "RevenantCoding.h"

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
    INParameter *parameter = [[self alloc] init];
    parameter->_parameterClass = aClass;
    parameter->_parameterKeyPath = [keyPath copy];
    return parameter;
}

- (BOOL)isEqualToParameter:(INParameter *)parameter
{
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
        revenant_intents_decode(self, coder);
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    revenant_intents_encode(self, coder);
}

- (id)copyWithZone:(NSZone *)zone
{
    INParameter *copy = [[[self class] allocWithZone:zone] init];
    revenant_intents_copy(copy, self);
    return copy;
}

@end
