#import "CharonPDFKit.h"

// PDFAppearanceCharacteristics as the value object the header declares: a settable member per key of
// an /MK dictionary (PDF 1.7 Table 8.40), and the dictionary itself as the key-values property.
//
// Nothing in the 26.2 SDK hands one of these out - there is no -[PDFAnnotation appearanceCharacteristics]
// and grep for appearanceCharacteristics across PDFKit.framework/Headers finds this class's own
// key-values property and nothing else - so both sides build the object with -init and the comparison
// is object against object.  That is a real comparison and not a formality: every rule below was
// measured by setting the member on the HOST's own object and reading it, and reading the key values
// after the set, so a setter that dropped its value or a getter that invented one would show up.
//
// MEASURED, each with the fixture or the sequence that fixes it:
//
//   a fresh object            -controlType -1, -rotation 0, the two colours nil, all three captions nil,
//                              and -appearanceCharacteristicsKeyValues with ONE key: R = 0.
//   R is always in the values - it is there on a fresh object, on one whose only other member is a
//                              caption (two keys, CA and R), and on one whose rotation was set to 0
//                              explicitly (one key).  So R is unconditional and the other five keys
//                              are there only when their member has a value.
//   -controlType is not a key  - set to each value from -1 to 3 and read back exactly, and the key
//                              values stay at one key throughout.  Six members set at once still give
//                              six keys, none of them controlType.  So it is kept and not published.
//   setting nil CLEARS         - caption and background color set, then set to nil, and the key values
//                              fall back from three keys to the one R.
//   an empty string is a value - caption and downCaption set to @"" and the key values answer three,
//                              so the check is not "the string has characters" but "the string is
//                              not nil".

@implementation PDFAppearanceCharacteristics {
    // The /MK dictionary this object is.  It starts with the one key every answer carries, so the
    // fresh object's key values are R = 0 because of the same code path a set rotation takes.
    NSMutableDictionary *_values;
    // Not in _values, for the reason measured above: the host keeps it and does not publish it.
    PDFWidgetControlType _controlType;
}

// -init is the object the header leaves open - PDFAppearanceCharacteristics.h declares no initializer,
// so a fresh one is what NSObject's is.  The rotation's own key is written here rather than left to a
// getter, so that -appearanceCharacteristicsKeyValues is the dictionary and not a copy of one that
// could fall out of step with it.
- (instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _controlType = kPDFWidgetUnknownControl;
    _values = [NSMutableDictionary dictionary];
    [_values setObject:[NSNumber numberWithInteger:0] forKey:PDFAppearanceCharacteristicsKeyRotation];
    return self;
}

// Each of the seven members is computed from the dictionary, so @dynamic says "not an ivar" and
// nothing else; every one of them has a body below.  The gate compiles with
// -Werror=objc-missing-property-synthesis, which is what wants these lines: an accessor this port wrote
// by hand is a claim the compiler should not second-guess silently.  PDFAnnotation11.m records the
// same thing for its own computed properties.
@dynamic controlType;
@dynamic backgroundColor;
@dynamic borderColor;
@dynamic rotation;
@dynamic caption;
@dynamic rolloverCaption;
@dynamic downCaption;
@dynamic appearanceCharacteristicsKeyValues;

// One value out of the dictionary, for the members whose type is an object.  Nil for a key that was
// never set and for a key that was set to nil, which are the same thing here because a nil set
// REMOVES the key (measured).
- (id)charon_objectForKey:(NSString *)key
{
    return _values[key];
}

- (void)charon_setObject:(id)value forKey:(NSString *)key
{
    if (value == nil)
        [_values removeObjectForKey:key];
    else
        [_values setObject:value forKey:key];
}

- (PDFWidgetControlType)controlType
{
    return _controlType;
}

- (void)setControlType:(PDFWidgetControlType)controlType
{
    _controlType = controlType;
}

- (UIColor *)backgroundColor
{
    return [self charon_objectForKey:PDFAppearanceCharacteristicsKeyBackgroundColor];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [self charon_setObject:backgroundColor forKey:PDFAppearanceCharacteristicsKeyBackgroundColor];
}

- (UIColor *)borderColor
{
    return [self charon_objectForKey:PDFAppearanceCharacteristicsKeyBorderColor];
}

- (void)setBorderColor:(UIColor *)borderColor
{
    [self charon_setObject:borderColor forKey:PDFAppearanceCharacteristicsKeyBorderColor];
}

// -rotation is the one member with no absent answer: its key is in the dictionary from -init, so a
// getter that finds nothing cannot happen.  A negative rotation is kept as it is set (measured at -90),
// so this is not a value clamped into a range.
- (NSInteger)rotation
{
    return [[_values objectForKey:PDFAppearanceCharacteristicsKeyRotation] integerValue];
}

- (void)setRotation:(NSInteger)rotation
{
    [_values setObject:[NSNumber numberWithInteger:rotation]
                forKey:PDFAppearanceCharacteristicsKeyRotation];
}

- (NSString *)caption
{
    return [self charon_objectForKey:PDFAppearanceCharacteristicsKeyCaption];
}

- (void)setCaption:(NSString *)caption
{
    [self charon_setObject:caption forKey:PDFAppearanceCharacteristicsKeyCaption];
}

- (NSString *)rolloverCaption
{
    return [self charon_objectForKey:PDFAppearanceCharacteristicsKeyRolloverCaption];
}

- (void)setRolloverCaption:(NSString *)rolloverCaption
{
    [self charon_setObject:rolloverCaption forKey:PDFAppearanceCharacteristicsKeyRolloverCaption];
}

- (NSString *)downCaption
{
    return [self charon_objectForKey:PDFAppearanceCharacteristicsKeyDownCaption];
}

- (void)setDownCaption:(NSString *)downCaption
{
    [self charon_setObject:downCaption forKey:PDFAppearanceCharacteristicsKeyDownCaption];
}

// The dictionary itself, which is what the host's own property answers: a COPY, so a caller holding
// it cannot change this object through it.  The host's answers are compared by KEY SET and by each
// key's value, not by identity, and the port's copy is of the same dictionary the members read.
- (NSDictionary *)appearanceCharacteristicsKeyValues
{
    return [_values copy];
}

@end