// What this Mac's own MediaPlayer answers for the MPMediaItem properties the registry declares absent.
//
// The iOS SDK header is the authority for what exists and what a property is called: five of these are
// declared with a `getter=` attribute, so the property name is not a selector on any platform and a probe
// that asks for it learns nothing. The header is parsed here and the getter name written in it is the name
// asked for - the property name only when there is no getter=, which is what clang then synthesises. The
// macOS framework is the oracle for the behaviour of what it also has and for nothing else: what it lacks is
// not what iOS declares.
//
// A value needs a media library and this process has none, so what is asked is the two questions a value
// cannot answer: does the class declare the getter, and what does the getter answer when there is no value.
//
// **This probe refuses to report a number it cannot account for.** It parses with one pattern over the
// whole line, then asserts that it parsed every property it was asked about and that every name it is about
// to ask is an identifier - no `*`, no `)`, no `=`. Two earlier versions broke exactly there and printed a
// confident, wrong number: one compared the availability token for equality against `MP_API` while the
// header writes `MP_API(ios(8.0))`, and asked about nothing while its controls passed; one kept the header's
// punctuation, so six pointer-typed properties and four getter= ones were asked under names that are not
// selectors, and it printed 11 of 16. An assertion turns that class of mistake into a non-zero exit.
//
//     xcrun clang -fobjc-arc -framework Foundation -framework MediaPlayer -o /tmp/mpitem-probe probe.m
//     /tmp/mpitem-probe /path/to/iPhoneOS26.2.sdk/.../MediaPlayer.framework/Headers/MPMediaItem.h
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

// The 22 the registry lists absent.
static NSArray *const wanted = @[
    @"albumTrackNumber", @"discNumber", @"albumArtistPersistentID", @"albumPersistentID", @"albumTrackCount",
    @"artistPersistentID", @"assetURL", @"beatsPerMinute", @"cloudItem", @"comments", @"compilation",
    @"composerPersistentID", @"discCount", @"genrePersistentID", @"lyrics", @"podcastPersistentID",
    @"userGrouping", @"protectedAsset", @"dateAdded", @"explicitItem", @"playbackStoreID", @"preorder",
];
static NSString *const positiveControl = @"albumTitle";
static NSString *const negativeControl = @"aGetterNoFrameworkHas";

// @property (attributes) type name MP_API(...), in one pattern over the whole line. The availability macro
// is named by its prefix because the header writes MP_API(ios(8.0)) as one token. Built once, in main: a
// regular expression is not a compile-time constant, and a file initialiser that silently failed to compile
// once left a stale binary being run and read.
static NSRegularExpression *propertyLine, *getterAttribute, *identifier;

static void compile_patterns(void) {
    propertyLine = [NSRegularExpression
        regularExpressionWithPattern:@"@property\\s*\\(([^)]*)\\)\\s*([^;]*?)([A-Za-z_]\\w*)\\s+MP_[A-Z_]+\\("
                             options:0 error:NULL];
    getterAttribute = [NSRegularExpression
        regularExpressionWithPattern:@"getter\\s*=\\s*([A-Za-z_]\\w*)" options:0 error:NULL];
    identifier = [NSRegularExpression
        regularExpressionWithPattern:@"^[A-Za-z_]\\w*$" options:0 error:NULL];
}

static NSDictionary *parse_property(NSString *line) {
    NSTextCheckingResult *hit = [propertyLine firstMatchInString:line options:0
                                                          range:NSMakeRange(0, line.length)];
    if (!hit) {
        return nil;
    }
    NSString *attributes = [line substringWithRange:[hit rangeAtIndex:1]];
    NSString *type = [[line substringWithRange:[hit rangeAtIndex:2]]
                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *name = [line substringWithRange:[hit rangeAtIndex:3]];
    NSString *getter = name;
    NSTextCheckingResult *g = [getterAttribute firstMatchInString:attributes options:0
                                                            range:NSMakeRange(0, attributes.length)];
    if (g) {
        getter = [attributes substringWithRange:[g rangeAtIndex:1]];
    }
    return @{@"property": name, @"getter": getter, @"type": type};
}

// A name a selector could be. Anything else is the header's punctuation still attached, and asking about it
// would be asking about a selector that does not exist.
static BOOL is_identifier(NSString *name) {
    return [identifier firstMatchInString:name options:0 range:NSMakeRange(0, name.length)] != nil;
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IONBF, 0);
    compile_patterns();
    if (argc < 2) {
        fprintf(stderr, "usage: probe MPMediaItem.h\n");
        return 2;
    }
    NSString *header = [NSString stringWithUTF8String:argv[1]];
    NSString *text = [NSString stringWithContentsOfFile:header encoding:NSUTF8StringEncoding error:NULL];
    if (!text) {
        fprintf(stderr, "cannot read %s\n", header.UTF8String);
        return 2;
    }

    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        NSDictionary *property = parse_property(line);
        if (property && [wanted containsObject:property[@"property"]]) {
            [rows addObject:property];
        }
    }

    // The assertions. Each of these is a way a previous version of this probe reported a wrong number, and
    // each is a non-zero exit rather than a line of output.
    if (rows.count != wanted.count) {
        fprintf(stderr, "FAIL: parsed %zu of the %zu properties this probe was asked about, so the run "
                        "below is not a measurement\n", (size_t)rows.count, (size_t)wanted.count);
        for (NSString *missing in wanted) {
            if (![rows filteredArrayUsingPredicate:
                   [NSPredicate predicateWithBlock:^BOOL(NSDictionary *r, id _) {
                       return [r[@"property"] isEqualToString:missing];
                   }]].count) {
                fprintf(stderr, "  not parsed: %s\n", missing.UTF8String);
            }
        }
        return 1;
    }
    for (NSDictionary *row in rows) {
        NSString *name = (NSString *)row[@"property"];
        NSString *getter = (NSString *)row[@"getter"];
        if (!is_identifier(name) || !is_identifier(getter)) {
            fprintf(stderr, "FAIL: %s has getter %s, which is not an identifier, so asking about it would be "
                            "asking about a selector that does not exist\n", name.UTF8String, getter.UTF8String);
            return 1;
        }
    }

    Class item = objc_getClass("MPMediaItem");
    printf("MPMediaItem on this host: %s\n", item ? "present" : "absent");
    printf("header: %s, %zu properties parsed, every getter an identifier\n",
           header.lastPathComponent.UTF8String, (size_t)rows.count);
    printf("\n%-28s %-22s %-28s %s\n", "property", "getter", "type", "host answers");
    printf("------------------------------------------------------------------------------------------------\n");
    unsigned found = 0;
    for (NSDictionary *row in rows) {
        NSString *getter = row[@"getter"];
        BOOL answers = item != nil && class_getInstanceMethod(item, NSSelectorFromString(getter)) != NULL;
        found += answers ? 1 : 0;
        printf("%-28s %-22s %-28s %s\n", [row[@"property"] UTF8String], getter.UTF8String,
               [row[@"type"] UTF8String], answers ? "declares the getter" : "does not answer");
    }
    printf("\nasked %zu, the host declares %u\n", (size_t)rows.count, found);
    printf("control, positive %-24s %s\n", positiveControl.UTF8String,
           item && class_getInstanceMethod(item, NSSelectorFromString(positiveControl)) ? "declared" : "MISSING");
    printf("control, negative %-24s %s\n", negativeControl.UTF8String,
           item && class_getInstanceMethod(item, NSSelectorFromString(negativeControl)) ? "FOUND, which cannot be" : "absent, as it must be");
    return 0;
}
