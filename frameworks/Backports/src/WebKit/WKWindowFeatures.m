#if defined(REVENANT_HOST_BUILD)
#define WKWindowFeatures WKWindowFeaturesRevenant
#endif

#import <WebKit/WebKit.h>

static NSNumber *FeatureBoolean(NSString *value)
{
    if (!value)
        return @YES;
    NSString *text = value.lowercaseString;
    if ([text isEqualToString:@"yes"] || [text isEqualToString:@"on"])
        return @YES;
    if ([text isEqualToString:@"no"] || [text isEqualToString:@"off"])
        return @NO;
    return @([text doubleValue] != 0);
}

static NSNumber *FeatureNumber(NSString *value)
{
    return value ? @([value doubleValue]) : nil;
}

@implementation WKWindowFeatures {
    NSNumber *_menuBarVisibility;
    NSNumber *_statusBarVisibility;
    NSNumber *_toolbarsVisibility;
    NSNumber *_allowsResizing;
    NSNumber *_x;
    NSNumber *_y;
    NSNumber *_width;
    NSNumber *_height;
}

+ (instancetype)revenant_featuresWithString:(NSString *)string
{
    WKWindowFeatures *features = [[self alloc] init];
    NSCharacterSet *spaces = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSString *item in [string componentsSeparatedByString:@","]) {
        NSRange equal = [item rangeOfString:@"="];
        NSString *name = equal.location == NSNotFound ? item : [item substringToIndex:equal.location];
        NSString *key = [name stringByTrimmingCharactersInSet:spaces].lowercaseString;
        NSString *value = equal.location == NSNotFound ? nil : [[item substringFromIndex:NSMaxRange(equal)] stringByTrimmingCharactersInSet:spaces];
        if ([key isEqualToString:@"menubar"])
            features->_menuBarVisibility = FeatureBoolean(value);
        else if ([key isEqualToString:@"status"])
            features->_statusBarVisibility = FeatureBoolean(value);
        else if ([key isEqualToString:@"toolbar"])
            features->_toolbarsVisibility = FeatureBoolean(value);
        else if ([key isEqualToString:@"resizable"])
            features->_allowsResizing = FeatureBoolean(value);
        else if ([key isEqualToString:@"left"] || [key isEqualToString:@"screenx"])
            features->_x = FeatureNumber(value);
        else if ([key isEqualToString:@"top"] || [key isEqualToString:@"screeny"])
            features->_y = FeatureNumber(value);
        else if ([key isEqualToString:@"width"] || [key isEqualToString:@"innerwidth"])
            features->_width = FeatureNumber(value);
        else if ([key isEqualToString:@"height"] || [key isEqualToString:@"innerheight"])
            features->_height = FeatureNumber(value);
    }
    return features;
}

- (NSNumber *)menuBarVisibility
{
    return _menuBarVisibility;
}

- (NSNumber *)statusBarVisibility
{
    return _statusBarVisibility;
}

- (NSNumber *)toolbarsVisibility
{
    return _toolbarsVisibility;
}

- (NSNumber *)allowsResizing
{
    return _allowsResizing;
}

- (NSNumber *)x
{
    return _x;
}

- (NSNumber *)y
{
    return _y;
}

- (NSNumber *)width
{
    return _width;
}

- (NSNumber *)height
{
    return _height;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
