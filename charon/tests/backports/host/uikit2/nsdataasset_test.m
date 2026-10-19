#import <UIKit/UIKit.h>
#import "check.h"

@interface CharonHostNSDataAsset : NSObject
- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name bundle:(NSBundle *)bundle;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSData *data;
@property (nonatomic, readonly, copy) NSString *typeIdentifier;
@end

static NSBundle *bundle_with(NSString *catalog, NSString *folder)
{
    [[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] copyItemAtPath:catalog toPath:[folder stringByAppendingPathComponent:@"Assets.car"] error:NULL];
    [@"<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>local.test.dataassets</string></dict></plist>" writeToFile:[folder stringByAppendingPathComponent:@"Info.plist"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    return [NSBundle bundleWithPath:folder];
}

static NSString *outcome(id (^block)(void))
{
    @try {
        return block() ? @"made" : @"nil";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raises %@: %@", exception.name, exception.reason];
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        Class ours = [CharonHostNSDataAsset class], system = [NSDataAsset class];
        NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-dataassets"];
        NSString *fixture = getenv("CHARON_DATA_ASSETS") ? @(getenv("CHARON_DATA_ASSETS")) : nil;
        NSString *real = getenv("CHARON_DATA_ASSET_CATALOG") ? @(getenv("CHARON_DATA_ASSET_CATALOG")) : nil;
        if (real.length && [[NSFileManager defaultManager] fileExistsAtPath:real]) {
            NSBundle *bundle = bundle_with(real, folder);
            NSData *listing = [NSData dataWithContentsOfFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"charon-dataassets.json"]];
            NSArray *rows = listing ? [NSJSONSerialization JSONObjectWithData:listing options:0 error:NULL] : @[];
            NSUInteger compared = 0;
            for (NSDictionary *row in rows) {
                if (![row[@"AssetType"] isEqual:@"Data"] || ![row[@"Compression"] isEqual:@"uncompressed"])
                    continue;
                NSString *name = row[@"Name"];
                CharonHostNSDataAsset *port = [[ours alloc] initWithName:name bundle:bundle];
                NSDataAsset *native = [[system alloc] initWithName:name bundle:bundle];
                NSString *label = [NSString stringWithFormat:@"the data set %@ of a catalogue an application was built with", name];
                CHECK(port != nil && native != nil && [port.data isEqualToData:native.data] && [port.typeIdentifier isEqualToString:native.typeIdentifier] && [port.name isEqualToString:native.name], label.UTF8String);
                compared++;
            }
            printf("compared %lu data sets of %s\n", (unsigned long)compared, real.UTF8String);
        }
        NSBundle *bundle = bundle_with(fixture ?: @"", [folder stringByAppendingString:@"-fixture"]);
        for (NSString *name in @[@"Plain", @"Config", @"Empty", @"Binary", @"Varied", @"plain", @"Missing", @""]) {
            CharonHostNSDataAsset *port = [[ours alloc] initWithName:name bundle:bundle];
            NSString *label = [NSString stringWithFormat:@"a name of the fixture: %@", name.length ? name : @"(empty)"];
            if ([name isEqualToString:@"Plain"])
                CHECK(port && [port.data isEqualToData:[@"plain data set\n" dataUsingEncoding:NSUTF8StringEncoding]] && [port.typeIdentifier isEqualToString:@"public.data"], label.UTF8String);
            else if ([name isEqualToString:@"Config"])
                CHECK(port && [port.typeIdentifier isEqualToString:@"public.json"] && [port.name isEqualToString:@"Config"], label.UTF8String);
            else if ([name isEqualToString:@"Empty"])
                CHECK(port && port.data.length == 0, label.UTF8String);
            else if ([name isEqualToString:@"Binary"])
                CHECK(port && port.data.length == 5120 && ((const uint8_t *)port.data.bytes)[255] == 255, label.UTF8String);
            else if ([name isEqualToString:@"Varied"])
                CHECK(port && ([port.data isEqualToData:[@"phone" dataUsingEncoding:NSUTF8StringEncoding]] || [port.data isEqualToData:[@"pad" dataUsingEncoding:NSUTF8StringEncoding]]), label.UTF8String);
            else
                CHECK(port == nil, label.UTF8String);
        }
        CHECK_EQUAL(outcome(^{ return [[ours alloc] initWithName:nil bundle:bundle]; }), outcome(^{ return [[system alloc] initWithName:nil bundle:bundle]; }), "a nil name is refused with the system's words");
        CHECK_EQUAL(outcome(^{ return [[ours alloc] initWithName:nil]; }), outcome(^{ return [[system alloc] initWithName:nil]; }), "and for the main bundle");
        CHECK_EQUAL(outcome(^{ return [[ours alloc] initWithName:@"Plain" bundle:nil]; }), outcome(^{ return [[system alloc] initWithName:@"Plain" bundle:nil]; }), "no bundle finds nothing");
        CharonHostNSDataAsset *port = [[ours alloc] initWithName:@"Plain" bundle:bundle];
        CHECK([port copy] == port && port.data == port.data, "an asset is immutable and copies as itself");
        CHECK([[port description] hasPrefix:@"<CharonHostNSDataAsset: "] && [[port description] containsString:@"name:'Plain' typeIdentifier='public.data' data="], "and describes itself as the system's does");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
