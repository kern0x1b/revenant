#import <Foundation/Foundation.h>

static NSOperatingSystemVersion charon_parse_version(NSString *string)
{
    NSOperatingSystemVersion version = {0, 0, 0};
    NSArray *parts = [string componentsSeparatedByString:@"."];
    if (parts.count > 0)
        version.majorVersion = [parts[0] integerValue];
    if (parts.count > 1)
        version.minorVersion = [parts[1] integerValue];
    if (parts.count > 2)
        version.patchVersion = [parts[2] integerValue];
    return version;
}

static NSOperatingSystemVersion charon_system_version(void)
{
    static NSOperatingSystemVersion version;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *system = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
        id product = system[@"ProductVersion"];
        if ([product isKindOfClass:[NSString class]])
            version = charon_parse_version(product);
    });
    return version;
}

@implementation NSProcessInfo (CharonOperatingSystemVersion)

- (NSOperatingSystemVersion)operatingSystemVersion
{
    return charon_system_version();
}

- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version
{
    NSOperatingSystemVersion current = charon_system_version();
    if (current.majorVersion != version.majorVersion)
        return current.majorVersion > version.majorVersion;
    if (current.minorVersion != version.minorVersion)
        return current.minorVersion > version.minorVersion;
    return current.patchVersion >= version.patchVersion;
}

@end
