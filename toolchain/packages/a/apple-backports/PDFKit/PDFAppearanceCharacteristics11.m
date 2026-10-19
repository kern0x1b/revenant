#import "CharonPDFKit.h"

@implementation PDFAppearanceCharacteristics {
    NSMutableDictionary *_values;
    PDFWidgetControlType _controlType;
}

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

@dynamic controlType;
@dynamic backgroundColor;
@dynamic borderColor;
@dynamic rotation;
@dynamic caption;
@dynamic rolloverCaption;
@dynamic downCaption;
@dynamic appearanceCharacteristicsKeyValues;

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

- (NSDictionary *)appearanceCharacteristicsKeyValues
{
    return [_values copy];
}

@end
