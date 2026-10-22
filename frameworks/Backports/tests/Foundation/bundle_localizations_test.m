#import "check.h"

static NSString *revenant_localized(NSBundle *bundle, NSString *key, NSString *value, NSString *table, NSArray *localizations)
{
    SEL selector = @selector(localizedStringForKey:value:table:localizations:);
    return REVENANT_IMP(NSBundle, selector, NSString *(*)(id, SEL, NSString *, NSString *, NSString *, NSArray *))(bundle, selector, key, value, table, localizations);
}

static void revenant_write(NSString *root, NSString *localization, NSString *table, NSString *contents)
{
    NSString *folder = [root stringByAppendingPathComponent:[localization stringByAppendingString:@".lproj"]];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [contents writeToFile:[folder stringByAppendingPathComponent:[table stringByAppendingString:@".strings"]] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    revenant_write(root, @"en", @"Localizable", @"\"hello\" = \"Hello\";\n\"only\" = \"English only\";\n");
    revenant_write(root, @"fr", @"Localizable", @"\"hello\" = \"Bonjour\";\n");
    revenant_write(root, @"fr", @"Other", @"\"hello\" = \"Salut\";\n");
    [@"{CFBundleDevelopmentRegion = en;}" writeToFile:[root stringByAppendingPathComponent:@"Info.plist"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    NSBundle *bundle = [NSBundle bundleWithPath:root];
    revenant_expect_string("the first available localization wins", revenant_localized(bundle, @"hello", nil, nil, @[@"fr", @"en"]), revenant_negative ? @"Hello" : @"Bonjour");
    revenant_expect_string("the preference order picks English first", revenant_localized(bundle, @"hello", nil, nil, @[@"en", @"fr"]), @"Hello");
    revenant_expect_string("a named table is read", revenant_localized(bundle, @"hello", nil, @"Other", @[@"fr"]), @"Salut");
    revenant_expect_string("a missing key falls back to the key", revenant_localized(bundle, @"absent", nil, nil, @[@"fr"]), @"absent");
    revenant_expect_string("a missing key falls back to the value", revenant_localized(bundle, @"absent", @"default", nil, @[@"fr"]), @"default");
    revenant_expect_string("an empty list uses the development localization", revenant_localized(bundle, @"only", nil, nil, @[]), @"English only");
    [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];
    return revenant_finish();
}
