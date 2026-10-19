#import <Foundation/Foundation.h>

static NSString *charon_group_folder_name(NSString *identifier)
{
    NSMutableString *name = [NSMutableString stringWithCapacity:identifier.length];
    for (NSUInteger index = 0; index < identifier.length; index++) {
        unichar unit = [identifier characterAtIndex:index];
        if (CFStringIsSurrogateHighCharacter(unit) && index + 1 < identifier.length && CFStringIsSurrogateLowCharacter([identifier characterAtIndex:index + 1])) {
            [name appendString:@"-"];
            index++;
            continue;
        }
        if ((unit >= '0' && unit <= '9') || (unit >= 'A' && unit <= 'Z') || (unit >= 'a' && unit <= 'z') || unit == ' ' || unit == '-' || unit == '.' || unit == '_') {
            [name appendFormat:@"%C", unit];
            continue;
        }
        if (unit >= 0xC0 && unit < 0x250) {
            NSString *single = [NSString stringWithCharacters:&unit length:1];
            NSString *decomposed = [single decomposedStringWithCanonicalMapping];
            unichar base = decomposed.length > 1 ? [decomposed characterAtIndex:0] : 0;
            if ((base >= 'A' && base <= 'Z') || (base >= 'a' && base <= 'z')) {
                [name appendFormat:@"%C", base];
                continue;
            }
        }
        [name appendString:@"-"];
    }
    return name;
}

@implementation NSFileManager (CharonAppGroup)

- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier
{
    if (![groupIdentifier isKindOfClass:[NSString class]] || !groupIdentifier.length)
        return nil;
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Group Containers"] stringByAppendingPathComponent:charon_group_folder_name(groupIdentifier)];
    if (![self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL])
        return nil;
    return [NSURL fileURLWithPath:path isDirectory:YES];
}

@end
