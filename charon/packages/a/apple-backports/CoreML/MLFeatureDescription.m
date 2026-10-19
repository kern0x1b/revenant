/* MLFeatureDescription: what a model says about one of its features, and the constraints that
 * say which values that feature will take.
 *
 * The model reader has already read all of this out of the specification's own fields -- the
 * name, the kind of value, whether the feature may be left out, and for a multi array or an
 * image or a sequence the shape, the size, the element type and the count. This turns that into
 * the classes an application asks, and the one method that matters is `-isAllowedValue:`, which
 * is the check a caller makes before it hands a value to a model and the check the model makes
 * of what it is handed.
 *
 * The constraints are separate classes because that is how Core ML declares them: a feature of
 * the multi array type carries a multi array constraint and none of the others, and a caller
 * reading `multiArrayConstraint` of a string feature gets nil. So a description builds the
 * constraint its own type has and no other.
 */

#include "CharonMLConstraints.h"

/* The constraints' own storage and the one initialiser each of them is built with. None of them
 * has a public initialiser in Core ML -- a model builds them and a caller only reads them -- so
 * the initialiser each is built with is declared here, next to the storage it fills, and the
 * declaration comes before the reading code that uses it. */

@interface MLMultiArrayConstraint () {
    NSArray<NSNumber *> *_shape;
    MLMultiArrayDataType _dataType;
    MLMultiArrayShapeConstraint *_shapeConstraint;
}
- (instancetype)charon_initWithShape:(NSArray<NSNumber *> *)shape
                     dataType:(MLMultiArrayDataType)dataType
               shapeConstraint:(MLMultiArrayShapeConstraint *)shapeConstraint;
@end

@interface MLImageConstraint () {
    NSInteger _pixelsHigh;
    NSInteger _pixelsWide;
    OSType _pixelFormatType;
    MLImageSizeConstraint *_sizeConstraint;
}
- (instancetype)charon_initWithPixelsHigh:(NSInteger)pixelsHigh
                        pixelsWide:(NSInteger)pixelsWide
                  pixelFormatType:(OSType)pixelFormatType
                    sizeConstraint:(MLImageSizeConstraint *)sizeConstraint;
@end

@interface MLDictionaryConstraint () {
    MLFeatureType _keyType;
}
- (instancetype)charon_initWithKeyType:(MLFeatureType)keyType;
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
- (instancetype)charon_initWithName:(NSString *)name type:(MLFeatureType)type optional:(BOOL)optional;
- (instancetype)charon_initWithFeature:(const charon_ml_feature *)feature;
@end

/* The element type and the shape a multi array feature takes. A model that fixes its shape
 * gives one shape here and no shape constraint at all; a model that will take a range of shapes
 * gives the range in the shape constraint, and its shape array then holds a -1 for the dimension
 * whose length is not fixed, which is the specification's own way of writing "flexible". */
@implementation MLMultiArrayConstraint

- (instancetype)charon_initWithShape:(NSArray<NSNumber *> *)shape
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
    return [[[self class] allocWithZone:zone] charon_initWithShape:_shape
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

/* An image feature's own numbers: the size it wants, the pixel format it wants, and the range or
 * the set of sizes it will take. The specification writes an image feature as a width, a height
 * and a colour space, and a model that will take more than one size writes the set or the range
 * beside them. */
@implementation MLImageConstraint

- (instancetype)charon_initWithPixelsHigh:(NSInteger)pixelsHigh
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
    return [[[self class] allocWithZone:zone] charon_initWithPixelsHigh:_pixelsHigh
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

/* What a dictionary feature's keys have to be. There is one thing to say about a dictionary --
 * the kind of its keys -- so this is the smallest of the constraints. */
@implementation MLDictionaryConstraint

- (instancetype)charon_initWithKeyType:(MLFeatureType)keyType
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
    return [[[self class] allocWithZone:zone] charon_initWithKeyType:_keyType];
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

/* The description of a feature that names no constraints of its own, which is what a sequence's
 * element is: the specification types a sequence's element in the feature's own oneof rather
 * than in a description, so an element is a number or a string and nothing else, and the
 * description a caller reads it through has to say that much and no more. */
- (instancetype)charon_initWithName:(NSString *)name
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

/* Builds the description of one feature out of what the model reader read for it. The name is
 * copied because the reader's copy belongs to the model and the description outlives it, and
 * each constraint is built here because whether a feature has one follows from its own type: a
 * multi array has a multi array constraint and nothing else does. */
- (instancetype)charon_initWithFeature:(const charon_ml_feature *)feature
{
    /* The description of one feature is the description of its name, type and optionality with
     * the constraints of that type built onto it, so it is built by handing those three to the
     * initialiser that takes them and then filling in what the type implies. */
    MLFeatureDescription *built = [self charon_initWithName:feature->name != NULL ? @(feature->name) : nil
                                                      type:charon_ml_feature_type_of(feature->type)
                                                  optional:feature->optional != 0];
    if (built == nil) {
        return nil;
    }
    switch (_type) {
    case MLFeatureTypeMultiArray:
        _multiArrayConstraint = [[MLMultiArrayConstraint alloc]
            charon_initWithShape:charon_ml_shape_to_array(feature->shape, feature->rank)
                 dataType:charon_ml_array_type(feature->data_type)
           shapeConstraint:charon_ml_shape_constraint_of(feature)];
        break;
    case MLFeatureTypeImage:
        _imageConstraint = charon_ml_image_constraint_of(feature);
        break;
    case MLFeatureTypeDictionary:
        _dictionaryConstraint = [[MLDictionaryConstraint alloc] charon_initWithKeyType:MLFeatureTypeString];
        break;
    case MLFeatureTypeSequence: {
        MLFeatureDescription *element =
            [[MLFeatureDescription alloc] charon_initWithName:nil
                                                  type:charon_ml_feature_type_of(feature->element_type)
                                              optional:NO];
        NSUInteger length = feature->has_count_range && feature->count_upper >= 0
                                ? (NSUInteger)(feature->count_upper - feature->count_lower)
                                : 0;
        _sequenceConstraint = [[MLSequenceConstraint alloc]
            charon_initWithValueDescription:element
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

/* Whether a value may be given to a feature with this description. This is the check the
 * specification's own fields are read for, and it is the check a model makes of what it is
 * handed, so the rules are the model's rules rather than this class's own:
 *
 *   - an undefined value is allowed exactly when the feature is optional, because a feature
 *     that is not optional is one the model cannot do without;
 *   - a defined value has to be of the type the feature names. Int64 and Double are separate
 *     types and a value of one is not a value of the other: a model that multiplies what it is
 *     given and a model that counts what it is given are told apart by this;
 *   - a multi array has to have the element type the feature names and a shape it will take:
 *     the one shape the feature fixes, or a shape inside the range it allows, or one of the
 *     shapes it enumerates. A feature that fixes no shape at all takes any, which is what a
 *     shape constraint of the unspecified kind means;
 *   - an image has to be of the size the feature fixes, inside the range it allows, or one of
 *     the sizes it enumerates;
 *   - a dictionary's keys have to be of the key type its constraint names;
 *   - a sequence has to have as many elements as its count range allows.
 */
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
        return charon_ml_shape_allowed(_multiArrayConstraint.shapeConstraint, array.shape);
    }
    case MLFeatureTypeImage:
        return _imageConstraint != nil &&
               charon_ml_image_size_allowed(_imageConstraint.sizeConstraint, _imageConstraint.pixelsHigh,
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

/* A copy is a description of the same feature, and the constraints are copied with it rather
 * than shared: they are the same numbers, and one description's constraint changing under
 * another would be a change nobody asked for. */
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
            charon_initWithShape:_multiArrayConstraint.shape
                 dataType:_multiArrayConstraint.dataType
           shapeConstraint:[_multiArrayConstraint.shapeConstraint copy]];
    }
    if (_imageConstraint != nil) {
        copy->_imageConstraint = [[MLImageConstraint alloc]
            charon_initWithPixelsHigh:_imageConstraint.pixelsHigh
                    pixelsWide:_imageConstraint.pixelsWide
              pixelFormatType:_imageConstraint.pixelFormatType
                sizeConstraint:[_imageConstraint.sizeConstraint copy]];
    }
    if (_dictionaryConstraint != nil) {
        copy->_dictionaryConstraint =
            [[MLDictionaryConstraint alloc] charon_initWithKeyType:_dictionaryConstraint.keyType];
    }
    if (_sequenceConstraint != nil) {
        copy->_sequenceConstraint = [[MLSequenceConstraint alloc]
            charon_initWithValueDescription:[_sequenceConstraint.valueDescription copy]
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
                                      charon_ml_feature_type_name_of(_type),
                                      _optional ? @" optional" : @""];
}

@end
