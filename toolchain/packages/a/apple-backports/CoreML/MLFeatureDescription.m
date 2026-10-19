#include "RevenantMLConstraints.h"

@interface MLMultiArrayConstraint () {
    NSArray<NSNumber *> *_shape;
    MLMultiArrayDataType _dataType;
    MLMultiArrayShapeConstraint *_shapeConstraint;
}
- (instancetype)revenant_initWithShape:(NSArray<NSNumber *> *)shape
                     dataType:(MLMultiArrayDataType)dataType
               shapeConstraint:(MLMultiArrayShapeConstraint *)shapeConstraint;
@end

@interface MLImageConstraint () {
    NSInteger _pixelsHigh;
    NSInteger _pixelsWide;
    OSType _pixelFormatType;
    MLImageSizeConstraint *_sizeConstraint;
}
- (instancetype)revenant_initWithPixelsHigh:(NSInteger)pixelsHigh
                        pixelsWide:(NSInteger)pixelsWide
                  pixelFormatType:(OSType)pixelFormatType
                    sizeConstraint:(MLImageSizeConstraint *)sizeConstraint;
@end

@interface MLDictionaryConstraint () {
    MLFeatureType _keyType;
}
- (instancetype)revenant_initWithKeyType:(MLFeatureType)keyType;
@end

@interface MLFeatureDescription () {
    NSString *_name;
    MLFeatureType _type;
    BOOL _optional;
    MLMultiArrayConstraint *_multiArrayConstraint;
    MLImageConstraint *_imageConstraint;
    MLDictionaryConstraint *_dictionaryConstraint;
    MLSequenceConstraint *_sequenceConstraint;
}
- (instancetype)revenant_initWithName:(NSString *)name type:(MLFeatureType)type optional:(BOOL)optional;
- (instancetype)revenant_initWithFeature:(const revenant_ml_feature *)feature;
@end

@implementation MLMultiArrayConstraint

- (instancetype)revenant_initWithShape:(NSArray<NSNumber *> *)shape
                     dataType:(MLMultiArrayDataType)dataType
               shapeConstraint:(MLMultiArrayShapeConstraint *)shapeConstraint
{
    MLMultiArrayConstraint *built = [super init];
    if (built != nil) {
        _shape = shape != nil ? [shape copy] : @[];
        _dataType = dataType;
        _shapeConstraint = shapeConstraint;
    }
    return built;
}

- (NSArray<NSNumber *> *)shape
{
    return _shape;
}

- (MLMultiArrayDataType)dataType
{
    return _dataType;
}
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] revenant_initWithShape:_shape
                                                         dataType:_dataType
                                                   shapeConstraint:[_shapeConstraint copy]];
}


- (MLMultiArrayShapeConstraint *)shapeConstraint
{
    return _shapeConstraint;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _shape = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSNumber class], nil] forKey:@"shape"];
        _dataType = (MLMultiArrayDataType)[coder decodeIntForKey:@"dataType"];
        _shapeConstraint = [coder decodeObjectOfClass:[MLMultiArrayShapeConstraint class]
                                            forKey:@"shapeConstraint"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_shape forKey:@"shape"];
    [coder encodeInt:(int)_dataType forKey:@"dataType"];
    [coder encodeObject:_shapeConstraint forKey:@"shapeConstraint"];
}

@end

@implementation MLImageConstraint

- (instancetype)revenant_initWithPixelsHigh:(NSInteger)pixelsHigh
                        pixelsWide:(NSInteger)pixelsWide
                  pixelFormatType:(OSType)pixelFormatType
                    sizeConstraint:(MLImageSizeConstraint *)sizeConstraint
{
    MLImageConstraint *built = [super init];
    if (built != nil) {
        _pixelsHigh = pixelsHigh;
        _pixelsWide = pixelsWide;
        _pixelFormatType = pixelFormatType;
        _sizeConstraint = sizeConstraint;
    }
    return built;
}

- (NSInteger)pixelsHigh
{
    return _pixelsHigh;
}

- (NSInteger)pixelsWide
{
    return _pixelsWide;
}

- (OSType)pixelFormatType
{
    return _pixelFormatType;
}
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] revenant_initWithPixelsHigh:_pixelsHigh
                                                                pixelsWide:_pixelsWide
                                                          pixelFormatType:_pixelFormatType
                                                            sizeConstraint:[_sizeConstraint copy]];
}


- (MLImageSizeConstraint *)sizeConstraint
{
    return _sizeConstraint;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _pixelsHigh = [coder decodeIntegerForKey:@"pixelsHigh"];
        _pixelsWide = [coder decodeIntegerForKey:@"pixelsWide"];
        _pixelFormatType = (OSType)[[coder decodeObjectOfClass:[NSNumber class]
                                                   forKey:@"pixelFormatType"] unsignedIntValue];
        _sizeConstraint = [coder decodeObjectOfClass:[MLImageSizeConstraint class] forKey:@"sizeConstraint"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_pixelsHigh forKey:@"pixelsHigh"];
    [coder encodeInteger:_pixelsWide forKey:@"pixelsWide"];
    [coder encodeObject:@((uint32_t)_pixelFormatType) forKey:@"pixelFormatType"];
    [coder encodeObject:_sizeConstraint forKey:@"sizeConstraint"];
}

@end

@implementation MLDictionaryConstraint

- (instancetype)revenant_initWithKeyType:(MLFeatureType)keyType
{
    MLDictionaryConstraint *built = [super init];
    if (built != nil) {
        _keyType = keyType;
    }
    return built;
}

- (MLFeatureType)keyType
{
    return _keyType;
}
- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] allocWithZone:zone] revenant_initWithKeyType:_keyType];
}


+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _keyType = (MLFeatureType)[coder decodeIntegerForKey:@"keyType"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_keyType forKey:@"keyType"];
}

@end

#pragma mark - the description

@implementation MLFeatureDescription

- (instancetype)revenant_initWithName:(NSString *)name
                        type:(MLFeatureType)type
                    optional:(BOOL)optional
{
    MLFeatureDescription *built = [super init];
    if (built != nil) {
        _name = [name copy];
        _type = type;
        _optional = optional;
    }
    return built;
}

- (instancetype)revenant_initWithFeature:(const revenant_ml_feature *)feature
{
    MLFeatureDescription *built = [self revenant_initWithName:feature->name != NULL ? @(feature->name) : nil
                                                      type:revenant_ml_feature_type_of(feature->type)
                                                  optional:feature->optional != 0];
    if (built == nil) {
        return nil;
    }
    switch (_type) {
    case MLFeatureTypeMultiArray:
        _multiArrayConstraint = [[MLMultiArrayConstraint alloc]
            revenant_initWithShape:revenant_ml_shape_to_array(feature->shape, feature->rank)
                 dataType:revenant_ml_array_type(feature->data_type)
           shapeConstraint:revenant_ml_shape_constraint_of(feature)];
        break;
    case MLFeatureTypeImage:
        _imageConstraint = revenant_ml_image_constraint_of(feature);
        break;
    case MLFeatureTypeDictionary:
        _dictionaryConstraint = [[MLDictionaryConstraint alloc] revenant_initWithKeyType:MLFeatureTypeString];
        break;
    case MLFeatureTypeSequence: {
        MLFeatureDescription *element =
            [[MLFeatureDescription alloc] revenant_initWithName:nil
                                                  type:revenant_ml_feature_type_of(feature->element_type)
                                              optional:NO];
        NSUInteger length = feature->has_count_range && feature->count_upper >= 0
                                ? (NSUInteger)(feature->count_upper - feature->count_lower)
                                : 0;
        _sequenceConstraint = [[MLSequenceConstraint alloc]
            revenant_initWithValueDescription:element
                          countRange:NSMakeRange((NSUInteger)feature->count_lower, length)];
        break;
    }
    default:
        break;
    }
    return built;
}

- (NSString *)name
{
    return _name;
}

- (MLFeatureType)type
{
    return _type;
}

- (BOOL)isOptional
{
    return _optional;
}

- (MLMultiArrayConstraint *)multiArrayConstraint
{
    return _multiArrayConstraint;
}

- (MLImageConstraint *)imageConstraint
{
    return _imageConstraint;
}

- (MLDictionaryConstraint *)dictionaryConstraint
{
    return _dictionaryConstraint;
}

- (MLSequenceConstraint *)sequenceConstraint
{
    return _sequenceConstraint;
}

- (BOOL)isAllowedValue:(MLFeatureValue *)value
{
    if (value == nil) {
        return NO;
    }
    if (value.isUndefined) {
        return _optional;
    }
    if (value.type != _type) {
        return NO;
    }
    switch (_type) {
    case MLFeatureTypeMultiArray: {
        MLMultiArray *array = value.multiArrayValue;
        if (array == nil || _multiArrayConstraint == nil) {
            return NO;
        }
        if (_multiArrayConstraint.dataType != (MLMultiArrayDataType)0 &&
            array.dataType != _multiArrayConstraint.dataType) {
            return NO;
        }
        return revenant_ml_shape_allowed(_multiArrayConstraint.shapeConstraint, array.shape);
    }
    case MLFeatureTypeImage:
        return _imageConstraint != nil &&
               revenant_ml_image_size_allowed(_imageConstraint.sizeConstraint, _imageConstraint.pixelsHigh,
                                            _imageConstraint.pixelsWide, value.imageBufferValue);
    case MLFeatureTypeDictionary:
        return _dictionaryConstraint != nil && _dictionaryConstraint.keyType == MLFeatureTypeString;
    case MLFeatureTypeSequence: {
        MLSequence *sequence = value.sequenceValue;
        NSRange allowed = _sequenceConstraint.countRange;
        NSUInteger count;
        if (sequence == nil) {
            return NO;
        }
        count = (NSUInteger)sequence.count;
        if (count < allowed.location ||
            (allowed.length != 0 && count > allowed.location + allowed.length)) {
            return NO;
        }
        return YES;
    }
    default:
        return YES;
    }
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil) {
        _name = [coder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _type = (MLFeatureType)[coder decodeIntegerForKey:@"type"];
        _optional = [coder decodeBoolForKey:@"optional"];
        _multiArrayConstraint = [coder decodeObjectOfClass:[MLMultiArrayConstraint class]
                                                forKey:@"multiArrayConstraint"];
        _imageConstraint = [coder decodeObjectOfClass:[MLImageConstraint class] forKey:@"imageConstraint"];
        _dictionaryConstraint = [coder decodeObjectOfClass:[MLDictionaryConstraint class]
                                               forKey:@"dictionaryConstraint"];
        _sequenceConstraint = [coder decodeObjectOfClass:[MLSequenceConstraint class]
                                               forKey:@"sequenceConstraint"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeInteger:(NSInteger)_type forKey:@"type"];
    [coder encodeBool:_optional forKey:@"optional"];
    [coder encodeObject:_multiArrayConstraint forKey:@"multiArrayConstraint"];
    [coder encodeObject:_imageConstraint forKey:@"imageConstraint"];
    [coder encodeObject:_dictionaryConstraint forKey:@"dictionaryConstraint"];
    [coder encodeObject:_sequenceConstraint forKey:@"sequenceConstraint"];
}

- (id)copyWithZone:(NSZone *)zone
{
    MLFeatureDescription *copy = [[MLFeatureDescription allocWithZone:zone] init];
    if (copy == nil) {
        return nil;
    }
    copy->_name = [_name copy];
    copy->_type = _type;
    copy->_optional = _optional;
    if (_multiArrayConstraint != nil) {
        copy->_multiArrayConstraint = [[MLMultiArrayConstraint alloc]
            revenant_initWithShape:_multiArrayConstraint.shape
                 dataType:_multiArrayConstraint.dataType
           shapeConstraint:[_multiArrayConstraint.shapeConstraint copy]];
    }
    if (_imageConstraint != nil) {
        copy->_imageConstraint = [[MLImageConstraint alloc]
            revenant_initWithPixelsHigh:_imageConstraint.pixelsHigh
                    pixelsWide:_imageConstraint.pixelsWide
              pixelFormatType:_imageConstraint.pixelFormatType
                sizeConstraint:[_imageConstraint.sizeConstraint copy]];
    }
    if (_dictionaryConstraint != nil) {
        copy->_dictionaryConstraint =
            [[MLDictionaryConstraint alloc] revenant_initWithKeyType:_dictionaryConstraint.keyType];
    }
    if (_sequenceConstraint != nil) {
        copy->_sequenceConstraint = [[MLSequenceConstraint alloc]
            revenant_initWithValueDescription:[_sequenceConstraint.valueDescription copy]
                          countRange:_sequenceConstraint.countRange];
    }
    return copy;
}

- (BOOL)isEqual:(id)object
{
    MLFeatureDescription *other = [object isKindOfClass:[MLFeatureDescription class]] ? object : nil;
    return other != nil && other->_type == _type && other->_optional == _optional &&
           (other->_name == _name || [other->_name isEqualToString:_name]);
}

- (NSUInteger)hash
{
    return [_name hash] ^ (NSUInteger)_type;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MLFeatureDescription %@ %s%@>", _name,
                                      revenant_ml_feature_type_name_of(_type),
                                      _optional ? @" optional" : @""];
}

@end
