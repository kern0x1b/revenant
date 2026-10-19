#import <CoreML/CoreML.h>

#include "CharonMLBridge.h"
#include "CharonMLInternal.h"

@implementation MLModelConfiguration {
    MLComputeUnits _computeUnits;
    BOOL _allowLowPrecisionAccumulationOnGPU;
    id _preferredMetalDevice;
    NSDictionary<MLParameterKey *, id> *_parameters;
    NSString *_modelDisplayName;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _computeUnits = MLComputeUnitsAll;
    }
    return self;
}

- (MLComputeUnits)computeUnits
{
    return _computeUnits;
}

- (void)setComputeUnits:(MLComputeUnits)computeUnits
{
    _computeUnits = computeUnits;
}

- (BOOL)allowLowPrecisionAccumulationOnGPU
{
    return _allowLowPrecisionAccumulationOnGPU;
}

- (void)setAllowLowPrecisionAccumulationOnGPU:(BOOL)allow
{
    _allowLowPrecisionAccumulationOnGPU = allow;
}

- (id<MTLDevice>)preferredMetalDevice
{
    return _preferredMetalDevice;
}

- (void)setPreferredMetalDevice:(id<MTLDevice>)device
{
    _preferredMetalDevice = device;
}

- (NSDictionary<MLParameterKey *, id> *)parameters
{
    return _parameters;
}

- (void)setParameters:(NSDictionary<MLParameterKey *, id> *)parameters
{
    _parameters = [parameters copy];
}

- (NSString *)modelDisplayName
{
    return _modelDisplayName;
}

- (void)setModelDisplayName:(NSString *)modelDisplayName
{
    _modelDisplayName = [modelDisplayName copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    MLModelConfiguration *copy = [[MLModelConfiguration allocWithZone:zone] init];
    if (copy == nil) {
        return nil;
    }
    copy->_computeUnits = _computeUnits;
    copy->_allowLowPrecisionAccumulationOnGPU = _allowLowPrecisionAccumulationOnGPU;
    copy->_preferredMetalDevice = _preferredMetalDevice;
    copy->_parameters = [_parameters copy];
    copy->_modelDisplayName = [_modelDisplayName copy];
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self init];
    if (self != nil) {
        _computeUnits = (MLComputeUnits)[coder decodeIntegerForKey:@"computeUnits"];
        _allowLowPrecisionAccumulationOnGPU = [coder decodeBoolForKey:@"allowLowPrecisionAccumulationOnGPU"];
        _parameters = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class],
                                                                          [MLParameterKey class], nil]
                                           forKey:@"parameters"];
        _modelDisplayName = [coder decodeObjectOfClass:[NSString class] forKey:@"modelDisplayName"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_computeUnits forKey:@"computeUnits"];
    [coder encodeBool:_allowLowPrecisionAccumulationOnGPU forKey:@"allowLowPrecisionAccumulationOnGPU"];
    [coder encodeObject:_parameters forKey:@"parameters"];
    [coder encodeObject:_modelDisplayName forKey:@"modelDisplayName"];
}

@end
