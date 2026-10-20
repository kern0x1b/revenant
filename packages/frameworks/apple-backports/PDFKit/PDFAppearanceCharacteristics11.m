#import "RevenantPDFKit.h"

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

- (id)revenant_objectForKey:(NSString *)key
{
    return _values[key];
}

- (void)revenant_setObject:(id)value forKey:(NSString *)key
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
    return [self revenant_objectForKey:PDFAppearanceCharacteristicsKeyBackgroundColor];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [self revenant_setObject:backgroundColor forKey:PDFAppearanceCharacteristicsKeyBackgroundColor];
}

- (UIColor *)borderColor
{
    return [self revenant_objectForKey:PDFAppearanceCharacteristicsKeyBorderColor];
}

- (void)setBorderColor:(UIColor *)borderColor
{
    [self revenant_setObject:borderColor forKey:PDFAppearanceCharacteristicsKeyBorderColor];
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
    return [self revenant_objectForKey:PDFAppearanceCharacteristicsKeyCaption];
}

- (void)setCaption:(NSString *)caption
{
    [self revenant_setObject:caption forKey:PDFAppearanceCharacteristicsKeyCaption];
}

- (NSString *)rolloverCaption
{
    return [self revenant_objectForKey:PDFAppearanceCharacteristicsKeyRolloverCaption];
}

- (void)setRolloverCaption:(NSString *)rolloverCaption
{
    [self revenant_setObject:rolloverCaption forKey:PDFAppearanceCharacteristicsKeyRolloverCaption];
}

- (NSString *)downCaption
{
    return [self revenant_objectForKey:PDFAppearanceCharacteristicsKeyDownCaption];
}

- (void)setDownCaption:(NSString *)downCaption
{
    [self revenant_setObject:downCaption forKey:PDFAppearanceCharacteristicsKeyDownCaption];
}

- (NSDictionary *)appearanceCharacteristicsKeyValues
{
    return [_values copy];
}

@end
