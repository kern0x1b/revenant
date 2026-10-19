#import <CoreML/CoreML.h>

#include "CharonMLBridge.h"
#include "CharonMLTensor.h"
#include "CharonMLValue.h"

@interface MLFeatureValue () {
@public
    charon_ml_value _value;
    MLFeatureType _type;
    MLMultiArray *_multiArray;
    MLSequence *_sequence;
    CVPixelBufferRef _pixelBuffer;
    NSDictionary *_given;
}
- (charon_ml_value *)charonValue;
@end

@implementation MLFeatureValue

- (charon_ml_value *)charonValue
{
    return &_value;
}

- (void)dealloc
{
    if (_pixelBuffer != NULL) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
    charon_ml_value_free(&_value);
}

#pragma mark - the constructors

+ (instancetype)valueOfKind:(charon_ml_value_kind)kind type:(MLFeatureType)type
{
    MLFeatureValue *value = [[MLFeatureValue alloc] init];
    if (value == nil) {
        return nil;
    }
    value->_type = type;
    value->_value.kind = kind;
    return value;
}

+ (instancetype)featureValueWithInt64:(int64_t)number
{
    MLFeatureValue *value = [self valueOfKind:CHARON_ML_VALUE_NUMBER type:MLFeatureTypeInt64];
    if (value != nil) {
        value->_value = charon_ml_value_number((double)number);
    }
    return value;
}

+ (instancetype)featureValueWithDouble:(double)number
{
    MLFeatureValue *value = [self valueOfKind:CHARON_ML_VALUE_NUMBER type:MLFeatureTypeDouble];
    if (value != nil) {
        value->_value = charon_ml_value_number(number);
    }
    return value;
}

+ (instancetype)featureValueWithString:(NSString *)string
{
    MLFeatureValue *value = [self valueOfKind:CHARON_ML_VALUE_STRING type:MLFeatureTypeString];
    if (value != nil) {
        value->_value = charon_ml_value_string_copy(string.UTF8String, strlen(string.UTF8String));
    }
    return value;
}

+ (instancetype)featureValueWithMultiArray:(MLMultiArray *)array
{
    MLFeatureValue *value;
    charon_ml_array *backing;
    if (array == nil) {
        return nil;
    }
    value = [self valueOfKind:CHARON_ML_VALUE_ARRAY type:MLFeatureTypeMultiArray];
    if (value == nil) {
        return nil;
    }
    backing = [array charonArray];
    value->_value = charon_ml_value_array(*backing);
    value->_value.array.owns_data = 0;
    value->_multiArray = array;
    return value;
}

+ (instancetype)featureValueWithPixelBuffer:(CVPixelBufferRef)buffer
{
    MLFeatureValue *value;
    void *bytes;
    OSType format;
    int data_type;
    if (buffer == NULL) {
        return nil;
    }
    if (CVPixelBufferLockBaseAddress(buffer, 0) != kCVReturnSuccess) {
        return nil;
    }
    format = CVPixelBufferGetPixelFormatType(buffer);
    switch (format) {
    case kCVPixelFormatType_32BGRA:
    case kCVPixelFormatType_32ARGB:
        data_type = CHARON_ML_ARRAY_FLOAT32;
        break;
    default:
        CVPixelBufferUnlockBaseAddress(buffer, 0);
        return [self undefinedFeatureValueWithType:MLFeatureTypeImage];
    }
    bytes = CVPixelBufferGetBaseAddress(buffer);
    if (bytes == NULL) {
        CVPixelBufferUnlockBaseAddress(buffer, 0);
        return [self undefinedFeatureValueWithType:MLFeatureTypeImage];
    }
    value = [self valueOfKind:CHARON_ML_VALUE_IMAGE type:MLFeatureTypeImage];
    if (value == nil) {
        CVPixelBufferUnlockBaseAddress(buffer, 0);
        return nil;
    }
    value->_pixelBuffer = (CVPixelBufferRef)CVPixelBufferRetain(buffer);
    value->_value.kind = CHARON_ML_VALUE_IMAGE;
    value->_value.array = charon_ml_array_make(data_type, NULL, 0, bytes);
    return value;
}

+ (instancetype)featureValueWithDictionary:(NSDictionary<id, NSNumber *> *)dictionary
                                     error:(NSError **)error
{
    MLFeatureValue *value;
    NSEnumerator *keys;
    id key;
    if (dictionary == nil) {
        charon_ml_error(error, CHARON_ML_ERROR_FEATURE_TYPE, @"a dictionary feature value needs a dictionary");
        return nil;
    }
    value = [self valueOfKind:CHARON_ML_VALUE_DICTIONARY type:MLFeatureTypeDictionary];
    if (value == nil) {
        return nil;
    }
    value->_value = charon_ml_value_dictionary();
    keys = [dictionary keyEnumerator];
    while ((key = [keys nextObject]) != nil) {
        id entry = [dictionary objectForKey:key];
        if ([key isKindOfClass:[NSString class]] && [entry isKindOfClass:[NSNumber class]]) {
            charon_ml_dictionary_put(&value->_value, [key UTF8String], [entry doubleValue]);
        }
    }
    value->_given = dictionary;
    return value;
}

+ (instancetype)charon_featureValueOfInvalidType
{
    MLFeatureValue *value = [self valueOfKind:CHARON_ML_VALUE_NUMBER type:MLFeatureTypeInvalid];
    if (value != nil) {
        value->_value = charon_ml_value_number(0.0);
    }
    return value;
}

+ (instancetype)featureValueWithSequence:(MLSequence *)sequence
{
    MLFeatureValue *value;
    if (sequence == nil) {
        return nil;
    }
    value = [self valueOfKind:CHARON_ML_VALUE_SEQUENCE type:MLFeatureTypeSequence];
    if (value == nil) {
        return nil;
    }
    value->_value.kind = CHARON_ML_VALUE_SEQUENCE;
    value->_sequence = sequence;
    return value;
}

+ (instancetype)undefinedFeatureValueWithType:(MLFeatureType)type
{
    MLFeatureValue *value = [self valueOfKind:CHARON_ML_VALUE_NONE type:type];
    return value;
}

+ (instancetype)charon_featureValueWithOwned:(charon_ml_value *)value type:(MLFeatureType)type
{
    MLFeatureValue *feature = [[MLFeatureValue alloc] init];
    if (feature == nil) {
        charon_ml_value_free(value);
        return nil;
    }
    feature->_value = *value;
    memset(value, 0, sizeof *value);
    feature->_type = type;
    if (feature->_value.kind == CHARON_ML_VALUE_ARRAY) {
        feature->_multiArray = [[MLMultiArray alloc] initWithWindowOf:feature->_value.array];
    }
    return feature;
}

#pragma mark - reading the value

- (MLFeatureType)type
{
    return _type;
}

- (BOOL)isUndefined
{
    return _value.kind == CHARON_ML_VALUE_NONE;
}

- (int64_t)int64Value
{
    if (_type != MLFeatureTypeInt64 || _value.kind != CHARON_ML_VALUE_NUMBER) {
        return 0;
    }
    return (int64_t)_value.number;
}

- (double)doubleValue
{
    if (_type != MLFeatureTypeDouble || _value.kind != CHARON_ML_VALUE_NUMBER) {
        return 0.0;
    }
    return _value.number;
}

- (NSString *)stringValue
{
    if (_value.kind != CHARON_ML_VALUE_STRING) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:_value.string.bytes
                                    length:_value.string.length
                                  encoding:NSUTF8StringEncoding];
}

- (MLMultiArray *)multiArrayValue
{
    if (_value.kind != CHARON_ML_VALUE_ARRAY) {
        return nil;
    }
    if (_multiArray == nil) {
        _multiArray = [[MLMultiArray alloc] initWithWindowOf:_value.array];
    }
    return _multiArray;
}

- (NSDictionary<id, NSNumber *> *)dictionaryValue
{
    size_t index;
    if (_value.kind != CHARON_ML_VALUE_DICTIONARY) {
        return nil;
    }
    if (_given != nil) {
        return _given;
    }
    {
        NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:_value.dictionary.count];
        for (index = 0; index < _value.dictionary.count; index++) {
            out[@(_value.dictionary.keys[index])] = @(_value.dictionary.values[index]);
        }
        return out;
    }
}

- (CVPixelBufferRef)imageBufferValue
{
    return _pixelBuffer;
}

- (MLSequence *)sequenceValue
{
    return _value.kind == CHARON_ML_VALUE_SEQUENCE ? _sequence : nil;
}

- (BOOL)isEqualToFeatureValue:(MLFeatureValue *)value
{
    if (value == nil || value->_type != _type || value->_value.kind != _value.kind) {
        return NO;
    }
    switch (_value.kind) {
    case CHARON_ML_VALUE_NUMBER:
        return value->_value.number == _value.number;
    case CHARON_ML_VALUE_STRING:
        return value->_value.string.length == _value.string.length &&
               memcmp(value->_value.string.bytes, _value.string.bytes, _value.string.length) == 0;
    case CHARON_ML_VALUE_ARRAY:
        return value->_value.array.count == _value.array.count &&
               value->_value.array.data_type == _value.array.data_type &&
               charon_ml_shape_equal(_value.array.shape, _value.array.rank,
                                      value->_value.array.shape, value->_value.array.rank) &&
               memcmp(value->_value.array.data, _value.array.data,
                      _value.array.count * charon_ml_type_size(_value.array.data_type)) == 0;
    case CHARON_ML_VALUE_DICTIONARY:
        if (value->_value.dictionary.count != _value.dictionary.count) {
            return NO;
        }
        {
            size_t index;
            for (index = 0; index < _value.dictionary.count; index++) {
                int found = 0;
                double number = 0.0;
                charon_ml_dictionary_get(&value->_value, _value.dictionary.keys[index], &number, &found);
                if (!found || number != _value.dictionary.values[index]) {
                    return NO;
                }
            }
        }
        return YES;
    default:
        return YES;
    }
}

#pragma mark - NSCopying and NSSecureCoding

- (id)copyWithZone:(NSZone *)zone
{
    MLFeatureValue *copy = [[MLFeatureValue allocWithZone:zone] init];
    if (copy == nil) {
        return nil;
    }
    copy->_type = _type;
    switch (_value.kind) {
    case CHARON_ML_VALUE_STRING:
        copy->_value = charon_ml_value_string_copy(_value.string.bytes, _value.string.length);
        break;
    case CHARON_ML_VALUE_ARRAY:
        copy->_value = charon_ml_value_array(
            charon_ml_array_alloc(_value.array.data_type, _value.array.shape, _value.array.rank));
        {
            size_t index;
            for (index = 0; index < _value.array.count && index < copy->_value.array.count; index++) {
                charon_ml_array_set(&copy->_value.array, (int64_t)index,
                                     charon_ml_array_get(&_value.array, (int64_t)index));
            }
        }
        break;
    case CHARON_ML_VALUE_DICTIONARY:
        copy->_value = charon_ml_value_dictionary();
        {
            size_t index;
            for (index = 0; index < _value.dictionary.count; index++) {
                charon_ml_dictionary_put(&copy->_value, _value.dictionary.keys[index],
                                          _value.dictionary.values[index]);
            }
        }
        break;
    default:
        copy->_value = _value;
        break;
    }
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSNumber *type = [coder decodeObjectOfClass:[NSNumber class] forKey:@"type"];
    NSNumber *kind = [coder decodeObjectOfClass:[NSNumber class] forKey:@"kind"];
    self = [super init];
    if (self == nil) {
        return nil;
    }
    if (type == nil) {
        return nil;
    }
    _type = (MLFeatureType)type.integerValue;
    switch ((charon_ml_value_kind)kind.integerValue) {
    case CHARON_ML_VALUE_NUMBER:
        _value = charon_ml_value_number([[coder decodeObjectOfClass:[NSNumber class]
                                                          forKey:@"number"] doubleValue]);
        break;
    case CHARON_ML_VALUE_STRING: {
        NSString *text = [coder decodeObjectOfClass:[NSString class] forKey:@"string"];
        if (text == nil) {
            return nil;
        }
        _value = charon_ml_value_string_copy(text.UTF8String, strlen(text.UTF8String));
        break;
    }
    case CHARON_ML_VALUE_ARRAY: {
        MLMultiArray *array = nil;
        if (!coder.requiresSecureCoding) {
            [NSException raise:NSInvalidUnarchiveOperationException
                        format:@"*** -[%@ _decodeCollectionOfClass:allowedClasses:forKey:]: This method only "
                               @"supports secure coding.",
                               NSStringFromClass([coder class])];
        }
        array = [coder decodeObjectOfClasses:[NSSet setWithObject:[MLMultiArray class]] forKey:@"array"];
        if (array == nil) {
            return nil;
        }
        _value = charon_ml_value_array(*[array charonArray]);
        _value.array.owns_data = 0;
        _multiArray = array;
        break;
    }
    case CHARON_ML_VALUE_DICTIONARY: {
        NSDictionary *pairs = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class],
                                                                          [NSString class], [NSNumber class], nil]
                                                 forKey:@"dictionary"];
        if (pairs == nil) {
            return nil;
        }
        _value = charon_ml_value_dictionary();
        _given = pairs;
        {
            NSEnumerator *keys = [pairs keyEnumerator];
            id key;
            while ((key = [keys nextObject]) != nil) {
                charon_ml_dictionary_put(&_value, [key UTF8String], [pairs[key] doubleValue]);
            }
        }
        break;
    }
    case CHARON_ML_VALUE_SEQUENCE: {
        MLSequence *sequence = [coder decodeObjectOfClass:[MLSequence class] forKey:@"sequence"];
        if (sequence == nil) {
            return nil;
        }
        _value.kind = CHARON_ML_VALUE_SEQUENCE;
        _sequence = sequence;
        break;
    }
    default:
        _value.kind = CHARON_ML_VALUE_NONE;
        break;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:@(_type) forKey:@"type"];
    [coder encodeObject:@(_value.kind) forKey:@"kind"];
    switch (_value.kind) {
    case CHARON_ML_VALUE_NUMBER:
        [coder encodeObject:@(_value.number) forKey:@"number"];
        break;
    case CHARON_ML_VALUE_STRING:
        [coder encodeObject:self.stringValue forKey:@"string"];
        break;
    case CHARON_ML_VALUE_ARRAY:
        [coder encodeObject:self.multiArrayValue forKey:@"array"];
        break;
    case CHARON_ML_VALUE_DICTIONARY:
        [coder encodeObject:self.dictionaryValue forKey:@"dictionary"];
        break;
    case CHARON_ML_VALUE_SEQUENCE:
        [coder encodeObject:self.sequenceValue forKey:@"sequence"];
        break;
    default:
        break;
    }
}

@end
