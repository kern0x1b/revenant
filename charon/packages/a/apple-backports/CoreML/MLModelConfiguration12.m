/* MLModelConfiguration, in a file of its own because an object may only carry the API of a single
 * release: the configuration arrived in iOS 12 and the model it configures in iOS 11. It holds what
 * a caller asks a model to do with, and it answers it back unchanged: this release has one unit a
 * Core ML model can run on, the CPU, and a configuration that says otherwise is not wrong -- it is a
 * request the run honours by running on that same CPU, which is what the release's own hardware
 * leaves it.
 */
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
        /* The units a model runs on are the caller's to choose and the port's to answer, and the
         * answer is the choice: this release has one unit a Core ML model can run on, the CPU,
         * and a configuration that says otherwise is not wrong -- it is a request the run
         * honours by running on that same CPU, which is what the release's own hardware leaves
         * it. The default is All, as Core ML's own default is, and a caller who wants the CPU
         * named says CPUOnly. */
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
    /* Kept as the caller gave it and handed back as it is, which is what a configuration is: the
     * setting an application made, readable by the application that made it. A Core ML model
     * here runs on the CPU, so nothing in a prediction reads it -- a caller that wanted the
     * device to be used would be asking for a Core ML compute engine on a release that has no
     * Metal driver at all, and that is said in the facts rather than pretended at here. */
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

/* --- the options for one prediction ------------------------------------------------------------ */
