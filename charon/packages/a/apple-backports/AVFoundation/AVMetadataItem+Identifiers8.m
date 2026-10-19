#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <string.h>

static NSString *charon_metadata_key_string(id key)
{
    if ([key isKindOfClass:[NSString class]])
        return key;
    if ([key isKindOfClass:[NSNumber class]])
        return [(NSNumber *)key stringValue];
    if ([key isKindOfClass:[NSData class]]) {
        NSData *data = key;
        const uint8_t *bytes = data.bytes;
        NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 2];
        for (NSUInteger index = 0; index < data.length; index++)
            [hex appendFormat:@"%02x", bytes[index]];
        return hex;
    }
    return nil;
}

static NSString *charon_metadata_data_type(id value)
{
    if ([value isKindOfClass:[NSString class]])
        return @"com.apple.metadata.datatype.UTF-8";
    if ([value isKindOfClass:[NSData class]]) {
        NSData *data = value;
        const uint8_t *bytes = data.bytes;
        if (data.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF)
            return @"com.apple.metadata.datatype.JPEG";
        if (data.length >= 8 && bytes[0] == 0x89 && bytes[1] == 'P' && bytes[2] == 'N' && bytes[3] == 'G')
            return @"com.apple.metadata.datatype.PNG";
        if (data.length >= 6 && bytes[0] == 'G' && bytes[1] == 'I' && bytes[2] == 'F')
            return @"com.apple.metadata.datatype.GIF";
        if (data.length >= 2 && bytes[0] == 'B' && bytes[1] == 'M')
            return @"com.apple.metadata.datatype.BMP";
        return @"com.apple.metadata.datatype.raw-data";
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        const char *type = ((NSNumber *)value).objCType;
        if (strcmp(type, @encode(float)) == 0)
            return @"com.apple.metadata.datatype.float32";
        if (strcmp(type, @encode(double)) == 0)
            return @"com.apple.metadata.datatype.float64";
        if (strcmp(type, @encode(BOOL)) == 0 || strcmp(type, @encode(unsigned char)) == 0)
            return @"com.apple.metadata.datatype.uint8";
        if (strcmp(type, @encode(char)) == 0)
            return @"com.apple.metadata.datatype.int8";
        if (strcmp(type, @encode(unsigned short)) == 0)
            return @"com.apple.metadata.datatype.uint16";
        if (strcmp(type, @encode(short)) == 0)
            return @"com.apple.metadata.datatype.int16";
        if (strcmp(type, @encode(unsigned int)) == 0 || strcmp(type, @encode(unsigned long)) == 0)
            return @"com.apple.metadata.datatype.uint32";
        if (strcmp(type, @encode(int)) == 0 || strcmp(type, @encode(long)) == 0)
            return @"com.apple.metadata.datatype.int32";
        if (strcmp(type, @encode(unsigned long long)) == 0)
            return @"com.apple.metadata.datatype.uint64";
        return @"com.apple.metadata.datatype.int64";
    }
    return nil;
}

@implementation AVMetadataItem (CharonIdentifiers8)

+ (AVMetadataIdentifier)identifierForKey:(id)key keySpace:(AVMetadataKeySpace)keySpace
{
    NSString *keyString = charon_metadata_key_string(key);
    return (keySpace.length && keyString.length) ? [NSString stringWithFormat:@"%@/%@", keySpace, keyString] : nil;
}

+ (AVMetadataKeySpace)keySpaceForIdentifier:(AVMetadataIdentifier)identifier
{
    NSRange slash = [identifier rangeOfString:@"/"];
    return slash.location == NSNotFound ? nil : [identifier substringToIndex:slash.location];
}

+ (id)keyForIdentifier:(AVMetadataIdentifier)identifier
{
    NSRange slash = [identifier rangeOfString:@"/"];
    return slash.location == NSNotFound ? nil : [identifier substringFromIndex:slash.location + 1];
}

- (AVMetadataIdentifier)identifier
{
    return [[self class] identifierForKey:self.key keySpace:self.keySpace];
}

- (NSString *)extendedLanguageTag
{
    return [self.locale.localeIdentifier stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
}

- (NSString *)dataType
{
    return charon_metadata_data_type(self.value);
}

@end

@implementation AVMutableMetadataItem (CharonIdentifiers8)

- (void)setIdentifier:(AVMetadataIdentifier)identifier
{
    self.key = [AVMetadataItem keyForIdentifier:identifier];
    self.keySpace = [AVMetadataItem keySpaceForIdentifier:identifier];
}

- (void)setExtendedLanguageTag:(NSString *)extendedLanguageTag
{
    self.locale = extendedLanguageTag ? [NSLocale localeWithLocaleIdentifier:[extendedLanguageTag stringByReplacingOccurrencesOfString:@"-" withString:@"_"]] : nil;
}

- (NSString *)dataType
{
    NSString *stored = objc_getAssociatedObject(self, @selector(dataType));
    return stored ?: charon_metadata_data_type(self.value);
}

- (void)setDataType:(NSString *)dataType
{
    objc_setAssociatedObject(self, @selector(dataType), dataType, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
