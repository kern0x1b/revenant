// Holds CharonSearchDatastore.m's reading of the shared store to what it claims: an application can write
// anything into that directory, so an entry that is not archive data, an archive that raises, an archive
// that decodes to nothing or to another class, and a file whose "entries" are no dictionary are each logged
// as rejected and skipped, and the item stored properly is still found. run.sh builds the port's own sources
// and the bundle's, with the store root inside the build directory. The release's SPContentResult, which
// the host does not have, is stood in for by the class below: it only records what the bundle hands over.
#import <CoreSpotlight/CoreSpotlight.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <unistd.h>

@interface SPContentResult : NSObject
+ (id)resultWithIdentifier:(id)identifier title:(id)title subtitle:(id)subtitle summary:(id)summary auxiliaryTitle:(id)auxiliaryTitle auxiliarySubtitle:(id)auxiliarySubtitle actionURL:(id)actionURL searchableContent:(id)content;
@end

@implementation SPContentResult
+ (id)resultWithIdentifier:(id)identifier title:(id)title subtitle:(id)subtitle summary:(id)summary auxiliaryTitle:(id)auxiliaryTitle auxiliarySubtitle:(id)auxiliarySubtitle actionURL:(id)actionURL searchableContent:(id)content
{
    return identifier;
}
@end

@interface Query : NSObject
@property (readonly) NSString *searchString;
@end
@implementation Query
- (NSString *)searchString { return @"good"; }
@end

@interface Pipe : NSObject
@property NSMutableArray *found;
@end
@implementation Pipe
- (void)appendResults:(NSArray *)results { [self.found addObjectsFromArray:results]; }
@end

static int failures;

static void check(BOOL condition, NSString *what)
{
    printf("%s %s\n", condition ? "ok" : "FAIL", what.UTF8String);
    if (!condition)
        failures++;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *root = [NSString stringWithUTF8String:argv[1]];
        NSString *log = [NSString stringWithUTF8String:argv[2]];
        freopen(log.fileSystemRepresentation, "w", stderr);

        CSSearchableItemAttributeSet *attributes = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"public.text"];
        attributes.title = @"good";
        CSSearchableItem *item = [[CSSearchableItem alloc] initWithUniqueIdentifier:@"stored" domainIdentifier:@"d" attributeSet:attributes];
        CSSearchableIndex *index = [[CSSearchableIndex alloc] initWithName:@"store"];
        [index indexSearchableItems:@[item] completionHandler:^(NSError *error) { if (error) printf("FAIL the good item was not stored: %s\n", error.description.UTF8String); }];

        NSString *storeFile = [root stringByAppendingPathComponent:@"space.kern0x1b.corespotlight.default/store.plist"];
        NSMutableDictionary *disk = [NSMutableDictionary dictionaryWithContentsOfFile:storeFile];
        NSMutableDictionary *entries = disk[@"entries"];
        NSMutableData *noRoot = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:noRoot];
        [archiver encodeObject:@"x" forKey:@"other"];
        [archiver finishEncoding];
        const char junk[] = "garbage that is no archive at all";
        entries[@"a-string"] = @"not data";
        entries[@"garbage"] = [NSData dataWithBytes:junk length:sizeof junk];
        entries[@"empty"] = [NSData data];
        entries[@"no-root"] = noRoot;
        entries[@"another-class"] = [NSKeyedArchiver archivedDataWithRootObject:@42];
        [disk writeToFile:storeFile atomically:YES];
        NSString *other = [root stringByAppendingPathComponent:@"other.application"];
        [[NSFileManager defaultManager] createDirectoryAtPath:other withIntermediateDirectories:YES attributes:nil error:NULL];
        [@{@"entries": @[@"not", @"a", @"dictionary"]} writeToFile:[other stringByAppendingPathComponent:@"array.plist"] atomically:YES];
        [@"not a property list" writeToFile:[other stringByAppendingPathComponent:@"text.plist"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];

        Class datastore = NSClassFromString(@"CharonSearchDatastore");
        check(datastore != Nil, @"the bundle registered its datastore class");
        Pipe *pipe = [Pipe new];
        pipe.found = [NSMutableArray array];
        ((void (*)(id, SEL, id, id))objc_msgSend)([datastore new], NSSelectorFromString(@"performQuery:withResultsPipe:"), [Query new], pipe);
        check([pipe.found isEqualToArray:@[@"stored"]], [NSString stringWithFormat:@"the item stored properly is found, and nothing else (%@)", pipe.found]);

        fflush(stderr);
        NSString *logged = [NSString stringWithContentsOfFile:log encoding:NSUTF8StringEncoding error:NULL];
        NSDictionary *reasons = @{@"a-string": @"not archive data", @"garbage": @"decodes to no", @"empty": @"decodes to no",
                                  @"no-root": @"decodes to no", @"another-class": @"decodes to no"};
        for (NSString *entry in reasons) {
            NSRange line = [logged rangeOfString:[@"rejected entry " stringByAppendingString:entry]];
            NSString *rest = line.location == NSNotFound ? @"" : [logged substringFromIndex:line.location];
            rest = [rest componentsSeparatedByString:@"\n"].firstObject;
            check([rest rangeOfString:reasons[entry]].location != NSNotFound,
                  [NSString stringWithFormat:@"entry %@ is logged as rejected, as %@ (%@)", entry, reasons[entry], rest]);
        }
        check([logged rangeOfString:@"array.plist: its entries are a"].location != NSNotFound, @"a file whose entries are no dictionary is logged as rejected");
        check([logged rangeOfString:@"text.plist: not a property list dictionary"].location != NSNotFound, @"a file that is no property list is logged as rejected");
        check([logged rangeOfString:@"rejected entry stored"].location == NSNotFound, @"the stored item is not logged as rejected");
    }
    printf("failures: %d\n", failures);
    return failures ? 1 : 0;
}
