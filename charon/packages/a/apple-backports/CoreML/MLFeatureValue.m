/* MLFeatureValue: one value of one feature, over the C value the interpreter passes about.
 *
 * The value the interpreter produces is a charon_ml_value and this holds it: a number, a
 * string, an array, a dictionary or an image. What the accessors do is answer in the form
 * Core ML documents -- a number, a string, an MLMultiArray, a dictionary -- and what a caller
 * asks for a value does not hold is nil, because that is what the documentation says and an
 * application is written to test for it.
 */
#import <CoreML/CoreML.h>

#include "CharonMLBridge.h"
#include "CharonMLTensor.h"
#include "CharonMLValue.h"

/* The value, and the type it is. An undefined value has a type and no contents: that is what
 * `undefinedFeatureValueWithType:` builds, and an optional input the caller left out is
 * answered as one. */
@interface MLFeatureValue () {
@public
    charon_ml_value _value;
    MLFeatureType _type;
    MLMultiArray *_multiArray; /* the MLMultiArray over _value, built once and kept */
    MLSequence *_sequence;     /* the sequence over _value, built once and kept */
    CVPixelBufferRef _pixelBuffer;
    NSDictionary *_given;   /* the dictionary a dictionary value was built from, as it was given */
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

/* One constructor for each of the specification's own cases, all of them the same thing: a value
 * of a kind holding one thing. The type is the constructor's to say rather than the kind's,
 * because the C holds a number as one kind whatever it is: an int64 and a double are the same four
 * kinds of value in the interpreter, and a caller asking `type` has to be told which one it is
 * looking at, or a model that wants a whole number would be handed a real and neither would know. */
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
        /* The bytes are the value's own: a string an application holds after the prediction
         * has gone has to still be there, and a view of a buffer that did not is not. */
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
    /* The value is a window on the array's own buffer, not a copy of it: an application that
     * writes through the multi array it handed over must see the change in the model. */
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
        /* A format this port does not unpack. The image is answered as an undefined value of
         * the image type rather than as a buffer of bytes that are not an image. */
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

/* A dictionary of a feature value. Core ML keeps the objects it is handed rather than a copy of
 * them, and it refuses nothing: a dictionary whose values are not numbers, or are not values at
 * all, becomes a dictionary value whose `dictionaryValue` answers exactly what was given. Only the
 * numbers go into the C, because only numbers are what the interpreter reads out of a dictionary
 * feature -- a classifier's probabilities -- and a value that is not a number is a caller's own
 * object that belongs to the caller. So the error is left alone: there is no failure here to
 * report, and an error an application had to clear before it could use its own dictionary would be
 * one it has no way to satisfy. */
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

/* A value of the invalid type, which is what an object a feature value cannot be made of becomes.
 * It is not an undefined value: an undefined value is one a caller left out on purpose and keeps
 * the type it was given, while this one holds nothing and says its type is the invalid one, so a
 * caller reading `type` can tell the two apart -- which is the whole of what a caller holding an
 * object it cannot convert has to go on. */
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
    /* The sequence is held, not flattened: it is an ordered list of numbers or of strings with
     * no shape of its own, and the value keeps it as it was given. The value's own type stays the
     * sequence type, which is what a caller switches on -- the sequence's type is the kind of its
     * *elements*, and a value whose type read 1 here would be an int64 value to everything that
     * asks, and a value holding three numbers is not one. */
    value->_value.kind = CHARON_ML_VALUE_SEQUENCE;
    value->_sequence = sequence;
    return value;
}

+ (instancetype)undefinedFeatureValueWithType:(MLFeatureType)type
{
    MLFeatureValue *value = [self valueOfKind:CHARON_ML_VALUE_NONE type:type];
    return value;
}

/* A value out of one the interpreter produced. The C's value moves into the object rather than
 * being copied: the interpreter built it for this answer and gives up owning it, and a copy
 * would be a second buffer holding the same numbers while the first was leaked or freed twice.
 * The type is the model's own -- what the description of that output names -- and not the C's
 * kind, because a number the model declared as a whole number is a whole number to a caller
 * even though both kinds are the same struct in the C. */
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

/* The numeric forms, each for the type it names and zero for every other. Measured against a real
 * Core ML: `int64Value` of a double value is 0 and `doubleValue` of a whole number is 0, not the
 * number the value holds. The two are separate types, not two spellings of one, and the accessors
 * are how a caller tells which it has -- reading the wrong one and getting the right number back
 * would hide a mistake in the model or in the caller, which is the one thing these accessors are
 * there to catch. */
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

/* The forms that answer an object: nil for a value that is not of that type, which is what a
 * release that has Core ML answers and what an application written against it tests for. A value
 * that holds a string does not answer an empty string to a caller asking for an array, because
 * "not an array" and "an array of no strings" are different facts. */
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
        /* An array that arrived as a value becomes an MLMultiArray over the same buffer, so
         * an application that reads it and an application that wrote it see one array. */
        _multiArray = [[MLMultiArray alloc] initWithWindowOf:_value.array];
    }
    return _multiArray;
}

/* The dictionary, as the caller gave it where the value was built from one: Core ML keeps the
 * objects it was handed rather than a copy of them, so a value made of a dictionary of numbers
 * answers that dictionary and one made of anything else answers whatever else it holds. A value
 * that is not a dictionary answers nil. */
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
        return YES; /* two undefined values, or two images of the same type, are equal */
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
        /* A copy is its own buffer and its own values: a copy that shared the buffer would
         * change under the caller that made it. */
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

/* What a value is archived as, and what it is built back from.
 *
 * Every kind of value is written under a key of its own and read back from the same one, and the
 * kind is written beside them: a value of a real type that is *undefined* and a value of that type
 * that holds something are different facts, and the type alone cannot tell them apart -- which is
 * why the previous round trip lost the array and came back with an empty string where the archive
 * had written one.
 *
 * The keys are this port's own. An archive written by Apple's Core ML is a private format this
 * port does not read, and the other way round; what a caller may do is write with one and read with
 * the other on the same release, which is what tests/backports/host/coreml checks for every kind of
 * value, against the framework's own round trip.
 */
- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSNumber *type = [coder decodeObjectOfClass:[NSNumber class] forKey:@"type"];
    NSNumber *kind = [coder decodeObjectOfClass:[NSNumber class] forKey:@"kind"];
    self = [super init];
    if (self == nil) {
        return nil;
    }
    if (type == nil) {
        /* An archive that carries no type is not a value. A coder that handed back a value of the
         * invalid type holding nothing would be a thing this port makes of an object it cannot
         * convert, and not a thing a half-written archive means. */
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
        /* Read through the collection API, the way Core ML's own coder reads the array: an
         * MLMultiArray is a collection of numbers, and a coder asked to decode one that does not
         * require secure coding refuses it -- which is what the framework does, and what this
         * port's own Foundation does with the same name and the same reason, because
         * NSCoder+Collections14 raises it. Measured: on Apple's Core ML a plain
         * +[NSKeyedUnarchiver unarchiveObjectWithData:] of a value over a multi array raises
         * NSInvalidUnarchiveOperationException, and a secure unarchiver brings the array back.
         * Decoding it any other way here would have made the port succeed where the release
         * refuses, which is the difference this delivery was asked to match. */
        MLMultiArray *array = nil;
        if (!coder.requiresSecureCoding) {
            /* Core ML's own coder reads the array through a private unarchiver selector that
             * refuses a coder which does not require secure coding, and a caller that archives a
             * value over a multi array and reads it back with
             * +[NSKeyedUnarchiver unarchiveObjectWithData:] therefore gets this exception --
             * measured against Apple's Core ML, on every release that has a coder at all. The
             * private selector is not reachable from here and is not the sort of thing this port
             * calls, so the port refuses on the same condition with the same name and the same
             * reason, which is also the exact string the port's own Foundation raises from
             * NSCoder+Collections14 when a collection is decoded from a coder of this kind. */
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
        /* An image value's numbers are its pixel buffer's, and a pixel buffer is not something a
         * secure archive carries, so an image comes back of the image type and undefined. An
         * undefined value of any type comes back as it was, which is the difference the kind
         * records and the type alone could not. */
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
