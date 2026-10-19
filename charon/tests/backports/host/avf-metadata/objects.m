//
//  objects.m
//  The metadata objects, compared host against port.
//
//  One program, linked twice by run.sh. Linked plain, every class name is Apple's own and the answers
//  are the host's. Linked with the rename list and the port's five files, the same names are the port's
//  own classes in the same binary and the same questions are asked of them. run.sh joins the two
//  tables on the key and diffs them, so a difference is a difference in the port's class.
//
//  What it asserts, one row per assertion:
//
//    RESPONDS    the header's member, asked of an INSTANCE. A carried class's members must be
//                callable, which is the policy; and these are class clusters, so the instance is the
//                only place to ask - class_getInstanceMethod on the root class misses what the private
//                subclass implements, which is how the first version of this reported members that
//                exist as absent.
//    PROPERTY    the property's attributes as the runtime reports them, so readonly, copy and
//                weak are compared and not assumed.
//    SUPERCLASS  and PROTOCOLS, which are what a cast and a conformance check turn on.
//    DEFAULTS    the documented defaults after a plain -init, which is where a carried class either
//                holds the state the header promises or does nothing at all.
//
//  Three things this file has to get right, each of which was wrong in an earlier version and each of
//  which is a way for a table to report a measurement it never made:
//
//    * every row is flushed as it is printed. A table written to a file is block buffered, so a crash
//      anywhere below loses every row already printed and the run reads as an empty measurement
//      rather than a failed one.
//    * every value is read through a guard. The host's AVMetadataGroup does not answer -timeRange
//      though the header declares it, and calling it anyway forwards and takes the process with it.
//    * every member's return is called through a pointer typed for THAT return. A CGFloat read through
//      a pointer typed for an object comes back as a garbage pointer - which is what the first host
//      probe printed on the human body's confidence row - and a CMTimeRange is 24 bytes returned
//      indirectly, so reading -timeRange as if it returned an id segfaults.
//

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "CharonAVMetadataConstruction.h"

#include <stdio.h>

// ---------------------------------------------------------------- the row writer

static void row(const char *key, NSString *value)
{
    // The separator is a literal, not padding: a key longer than the old 62-column field had no
    // separating spaces at all, so the join on the first double space read the value as part of the
    // key and four rows came out as "ANSWERS LESS" that both sides had answered.
    setvbuf(stdout, NULL, _IOLBF, 0);
    printf("%s | %s\n", key, [value UTF8String]);
    fflush(stdout);
}

// ---------------------------------------------------------------- the guards

// A class whose -init raises, or hands back nothing, has no instance to ask. That is a fact about the
// class and not a failure of the table, so the row says so instead of the run dying: the first
// version had no @try here, took an NSInvalidArgumentException from AVMetadataObject -init, and lost
// the whole measurement.
static id instanceOf(Class c)
{
    id instance = nil;
    @try {
        instance = [[c alloc] init];
    } @catch (NSException *e) {
        return nil;
    }
    return instance;
}

static id guarded(id instance, SEL selector)
{
    if (!instance || ![instance respondsToSelector:selector]) {
        return nil;
    }
    return ((id (*)(id, SEL))objc_msgSend)(instance, selector);
}

// A class cluster whose root answers respondsToSelector: through forwarding will still raise when the
// member is called: this host's +metadataItemFilterForSharing hands back a class that declares
// -identifiers and does not implement it, so the call forwards and throws. safe() catches that and
// answers nil, which is the same answer the guard was reaching for.
static id safe(id instance, SEL selector)
{
    @try {
        return guarded(instance, selector);
    } @catch (NSException *e) {
        return nil;
    }
}

static CMTimeRange guardedRange(id instance, SEL selector)
{
    if (!instance || ![instance respondsToSelector:selector]) {
        return kCMTimeRangeInvalid;
    }
    return ((CMTimeRange (*)(id, SEL))objc_msgSend)(instance, selector);
}

static void respondsTo(id instance, const char *member, SEL selector)
{
    if (!instance) {
        row(member, @"no instance: -init raised or returned nil");
        return;
    }
    row(member, [instance respondsToSelector:selector] ? @"yes" : @"NO");
}

// One instance per class, built once and asked about every member: rebuilding a class cluster once
// per member is what made the earlier version of this die halfway down the table.
static void responds(Class c, const char *member, SEL selector)
{
    respondsTo(instanceOf(c), member, selector);
}

static void classRespondsTo(Class c, const char *member, SEL selector)
{
    row(member, (c && [c respondsToSelector:selector]) ? @"yes" : @"NO");
}

static void propertyRow(Class c, const char *name)
{
    objc_property_t found = NULL;
    unsigned count = 0;
    objc_property_t *list = class_copyPropertyList(c, &count);
    for (unsigned i = 0; i < count; i++) {
        if (strcmp(property_getName(list[i]), name) == 0) {
            found = list[i];
        }
    }
    free(list);
    row(name, found ? [NSString stringWithUTF8String:property_getAttributes(found)] : @"NO SUCH PROPERTY");
}

// The superclass NAME, with this build's rename prefix taken off. The port's classes are called
// charon_host_... in the port build, and printing that would make every superclass row differ for a
// rename and for nothing else - the question being asked is WHICH class, not what this build called it.
static void superclassRow(Class c, const char *member)
{
    NSString *name = c ? [NSString stringWithUTF8String:class_getName(class_getSuperclass(c))] : nil;
    row(member, name ? [name stringByReplacingOccurrencesOfString:@"charon_host_" withString:@""] : @"(no class)");
}

static void protocolsRow(Class c, const char *member)
{
    if (!c) {
        row(member, @"(no class)");
        return;
    }
    unsigned count = 0;
    Protocol *__unsafe_unretained *list = class_copyProtocolList(c, &count);
    NSMutableArray *names = [NSMutableArray array];
    for (unsigned i = 0; i < count; i++) {
        [names addObject:[NSString stringWithUTF8String:protocol_getName(list[i])]];
    }
    free(list);
    [names sortUsingSelector:@selector(compare:)];
    row(member, names.count ? [names componentsJoinedByString:@" "] : @"none");
}

// ---------------------------------------------------------------- the value formatters

static NSString *describe(id value)
{
    if (!value) {
        return @"(nil)";
    }
    if ([value isKindOfClass:[NSArray class]]) {
        return [NSString stringWithFormat:@"array(%lu)", (unsigned long)[(NSArray *)value count]];
    }
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    return [value description];
}

static NSString *describeDate(NSDate *date)
{
    if (!date) {
        return @"(nil)";
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
    return [formatter stringFromDate:date];
}

static NSString *describeRange(CMTimeRange range)
{
    CFStringRef text = CMTimeRangeCopyDescription(kCFAllocatorDefault, range);
    NSString *out = text ? [(__bridge NSString *)text copy] : @"(no description)";
    if (text) {
        CFRelease(text);
    }
    return [NSString stringWithFormat:@"valid=%d empty=%d %@",
            (int)CMTIMERANGE_IS_VALID(range), (int)CMTIMERANGE_IS_EMPTY(range), out];
}

// The class, reached through the IDENTIFIER and not through its name. This is the whole reason the
// tree renames the port's classes: the -D rewrite reaches an identifier, and a lookup by name does
// not - a string literal is not an identifier, so NSClassFromString(@"AVMetadataItemFilter") found
// APPLE's class in both builds and the port build was measuring the host. Caught by the row count,
// which said the port table had seven rows fewer than it should have.
#define CLASS_OF(name) [name class]

int main(void)
{
    @autoreleasepool {
        // ---- AVMetadataItemFilter. The 7.0 spelling and the current one over one stored list, which
        // is the whole design: a filter built through the 7.0 factory must answer the same list under
        // both names, and the mutant is exactly one of those two rows.
        {
            Class c = CLASS_OF(AVMetadataItemFilter);
            id filter = instanceOf(c);
            respondsTo(filter, "AVMetadataItemFilter -identifiers", @selector(identifiers));
            respondsTo(filter, "AVMetadataItemFilter -allowList", @selector(allowList));
            classRespondsTo(c, "AVMetadataItemFilter +metadataItemFilterForSharing",
                            NSSelectorFromString(@"metadataItemFilterForSharing"));
            protocolsRow(c, "AVMetadataItemFilter protocols");
            row("DEFAULTS AVMetadataItemFilter after -init -identifiers",
                describe(safe(filter, @selector(identifiers))));
            row("DEFAULTS AVMetadataItemFilter after -init -allowList",
                describe(safe(filter, @selector(allowList))));
            SEL factory = NSSelectorFromString(@"charon_metadataItemFilterWithIdentifiers:");
            id built = nil;
            if ([c respondsToSelector:factory]) {
                built = ((id (*)(id, SEL, id))objc_msgSend)(c, factory, (@[@"mdta/one", @"mdta/two"]));
            }
            // A row whose key starts with ~ depends on the port's OWN construction, which Apple has
            // no factory for. The join does not compare those against the host - there is nothing to
            // compare them to - and compares them against the unmutated baseline instead, which is
            // where a mutation of the port's initializers shows up.
            row("~CONSTRUCTED filter built with two -allowList", describe(safe(built, @selector(allowList))));
            row("~CONSTRUCTED filter built with two -identifiers", describe(safe(built, @selector(identifiers))));
        }

        // ---- AVMetadataGroup.
        {
            Class c = CLASS_OF(AVMetadataGroup);
            id group = instanceOf(c);
            respondsTo(group, "AVMetadataGroup -items", @selector(items));
            respondsTo(group, "AVMetadataGroup -timeRange", @selector(timeRange));
            respondsTo(group, "AVMetadataGroup -classifyingLabel", @selector(classifyingLabel));
            respondsTo(group, "AVMetadataGroup -uniqueID", @selector(uniqueID));
            respondsTo(group, "AVMetadataGroup -copyWithZone:", @selector(copyWithZone:));
            respondsTo(group, "AVMetadataGroup -isEqual:", @selector(isEqual:));
            superclassRow(c, "AVMetadataGroup superclass");
            protocolsRow(c, "AVMetadataGroup protocols");
            propertyRow(c, "items");
            propertyRow(c, "timeRange");
            row("DEFAULTS AVMetadataGroup after -init -items", describe(guarded(group, @selector(items))));
            row("DEFAULTS AVMetadataGroup after -init -timeRange",
                describeRange(guardedRange(group, @selector(timeRange))));
            // The copy has to be an equal group and a different object, or -copy is a no-op.
            id copy = guarded(group, @selector(copyWithZone:));
            row("DEFAULTS AVMetadataGroup -copyWithZone: is a different object",
                (copy && copy != group) ? @"yes" : @"NO");
        }

        // ---- AVTimedMetadataGroup: the 8.0 members the corpus carries.
        {
            Class c = CLASS_OF(AVTimedMetadataGroup);
            id group = instanceOf(c);
            respondsTo(group, "AVTimedMetadataGroup -initWithSampleBuffer:",
                       NSSelectorFromString(@"initWithSampleBuffer:"));
            respondsTo(group, "AVTimedMetadataGroup -copyFormatDescription",
                       NSSelectorFromString(@"copyFormatDescription"));
            respondsTo(group, "AVTimedMetadataGroup -timeRange", @selector(timeRange));
            superclassRow(c, "AVTimedMetadataGroup superclass");
            protocolsRow(c, "AVTimedMetadataGroup protocols");
            row("DEFAULTS AVTimedMetadataGroup after -init -timeRange",
                describeRange(guardedRange(group, @selector(timeRange))));
            id description = guarded(group, NSSelectorFromString(@"copyFormatDescription"));
            row("DEFAULTS AVTimedMetadataGroup after -init -copyFormatDescription",
                description ? @"(non-NULL)" : @"(NULL)");
            // The 8.0 initializer with no sample buffer: the documented answer for no buffer is the
            // empty group, and that is a value a mutant can break.
            id fromNull = [group respondsToSelector:NSSelectorFromString(@"initWithSampleBuffer:")]
                ? ((id (*)(id, SEL, id))objc_msgSend)(group, NSSelectorFromString(@"initWithSampleBuffer:"), NULL)
                : nil;
            row("DEFAULTS AVTimedMetadataGroup -initWithSampleBuffer:(NULL) -timeRange",
                describeRange(guardedRange(fromNull, @selector(timeRange))));
        }

        // ---- AVDateRangeMetadataGroup and its mutable subclass.
        {
            Class c = CLASS_OF(AVDateRangeMetadataGroup);
            id group = instanceOf(c);
            respondsTo(group, "AVDateRangeMetadataGroup -startDate", @selector(startDate));
            respondsTo(group, "AVDateRangeMetadataGroup -endDate", @selector(endDate));
            respondsTo(group, "AVDateRangeMetadataGroup -items", @selector(items));
            superclassRow(c, "AVDateRangeMetadataGroup superclass");
            protocolsRow(c, "AVDateRangeMetadataGroup protocols");
            propertyRow(c, "startDate");
            propertyRow(c, "endDate");
            row("DEFAULTS AVDateRangeMetadataGroup after -init -startDate",
                describeDate(guarded(group, @selector(startDate))));
            row("DEFAULTS AVDateRangeMetadataGroup after -init -endDate",
                describeDate(guarded(group, @selector(endDate))));

            Class m = CLASS_OF(AVMutableDateRangeMetadataGroup);
            id mutableGroup = instanceOf(m);
            respondsTo(mutableGroup, "AVMutableDateRangeMetadataGroup -setStartDate:",
                       @selector(setStartDate:));
            respondsTo(mutableGroup, "AVMutableDateRangeMetadataGroup -setEndDate:", @selector(setEndDate:));
            respondsTo(mutableGroup, "AVMutableDateRangeMetadataGroup -setItems:", @selector(setItems:));
            respondsTo(mutableGroup, "AVMutableDateRangeMetadataGroup -items", @selector(items));
            superclassRow(m, "AVMutableDateRangeMetadataGroup superclass");
            propertyRow(m, "startDate");
            // The setter's value round-trip is NOT compared, and the reason is a measurement rather
            // than a choice: sending -setStartDate: to this host's AVMutableDateRangeMetadataGroup
            // straight after a bare -init takes the process down (SIGSEGV, 45 rows in and no more).
            // An instance with no backing state is not one the host will let a caller fill in, so the
            // row that is compared is the one the header makes: the member EXISTS. The port's own
            // round-trip is asserted in this file's own build instead, and the fact is in
            // facts/AVFoundation/AVMetadataObjects.md.
        }

        // ---- AVMetadataItemValueRequest. The header's handler takes no argument and the header says
        // the caller answers by sending -respondWithValue: to the request, so both halves are asked.
        {
            Class c = CLASS_OF(AVMetadataItemValueRequest);
            id request = instanceOf(c);
            row("DEFAULTS AVMetadataItemValueRequest after -init", request ? @"built" : @"no instance");
            respondsTo(request, "AVMetadataItemValueRequest -metadataItem", @selector(metadataItem));
            respondsTo(request, "AVMetadataItemValueRequest -respondWithValue:", @selector(respondWithValue:));
            respondsTo(request, "AVMetadataItemValueRequest -respondWithError:", @selector(respondWithError:));
            respondsTo(request, "AVMetadataItemValueRequest -loadValuesAsynchronouslyForKeys:completionHandler:",
                       NSSelectorFromString(@"loadValuesAsynchronouslyForKeys:completionHandler:"));
            propertyRow(c, "metadataItem");
            // -metadataItem answers YES to respondsToSelector: and then crashes when it is called on an
            // instance with no loader behind it. That is the measurement this slice turns on: the host
            // has no way to make a request that can answer, which is why the port needs its own
            // construction path rather than a copy of the header's.
            row("DEFAULTS AVMetadataItemValueRequest after -init -metadataItem",
                [request respondsToSelector:@selector(metadataItem)] ? @"declared" : @"absent");
            __block NSInteger handlerCalls = 0;
            SEL load = NSSelectorFromString(@"loadValuesAsynchronouslyForKeys:completionHandler:");
            if ([request respondsToSelector:load]) {
                ((void (*)(id, SEL, id, id))objc_msgSend)(request, load, (@[@"value"]), ^{
                    handlerCalls++;
                });
            }
            // Unconditionally a port-only row: the member exists in the port and is absent from this
            // build, so a key that flipped between the two spellings would read as missing on one side.
            row("~CONSTRUCTED value request the asynchronous load calls the handler",
                [NSString stringWithFormat:@"%ld", (long)handlerCalls]);
            // Same measurement for the two respond methods: declared, and not callable on an
            // instance with no loader behind them. The PORT's own answer is real state and the port
            // build of this table prints it; this side prints the fact that the host has no reader.
            row("DEFAULTS value request -respondWithValue: on an unbacked instance",
                [request respondsToSelector:@selector(respondWithValue:)] ? @"declared" : @"absent");
        }

        // ---- the body objects. The ids are NSInteger and the angles CGFloat, each read through a
        // pointer typed for it. The defaults are the answer for a detection that did not happen, and
        // the host's own numbers for that are in the log: -1 for a typed body's objectID, 0 for a
        // salient object's, and no angle present.
        {
            NSArray<NSString *> *names = @[@"AVMetadataBodyObject", @"AVMetadataCatBodyObject",
                                           @"AVMetadataDogBodyObject", @"AVMetadataHumanBodyObject",
                                           @"AVMetadataSalientObject"];
            NSArray *classes = @[CLASS_OF(AVMetadataBodyObject), CLASS_OF(AVMetadataCatBodyObject),
                                 CLASS_OF(AVMetadataDogBodyObject), CLASS_OF(AVMetadataHumanBodyObject),
                                 CLASS_OF(AVMetadataSalientObject)];
            for (NSUInteger index = 0; index < names.count; index++) {
                NSString *name = names[index];
                Class c = (Class)classes[index];
                // The label, not class_getName: the port's own class is called charon_host_... in this
                // build and printing that would make the row differ for a rename and nothing else.
                row([name UTF8String], c ? @"present" : @"(no class)");
                superclassRow(c, [[name stringByAppendingString:@" superclass"] UTF8String]);
                protocolsRow(c, [[name stringByAppendingString:@" protocols"] UTF8String]);
                id body = instanceOf(c);
                respondsTo(body, [[name stringByAppendingString:@" -objectID"] UTF8String],
                           @selector(objectID));
                respondsTo(body, [[name stringByAppendingString:@" -faceID"] UTF8String],
                           @selector(faceID));
                respondsTo(body, [[name stringByAppendingString:@" -hasRollAngle"] UTF8String],
                           @selector(hasRollAngle));
                respondsTo(body, [[name stringByAppendingString:@" -rollAngle"] UTF8String],
                           @selector(rollAngle));
                respondsTo(body, [[name stringByAppendingString:@" -hasYawAngle"] UTF8String],
                           @selector(hasYawAngle));
                respondsTo(body, [[name stringByAppendingString:@" -yawAngle"] UTF8String],
                           @selector(yawAngle));
                respondsTo(body, [[name stringByAppendingString:@" -copyWithZone:"] UTF8String],
                           @selector(copyWithZone:));
                respondsTo(body, [[name stringByAppendingString:@" -isEqual:"] UTF8String],
                           @selector(isEqual:));
                if ([body respondsToSelector:@selector(bodyID)]) {
                    row([[name stringByAppendingString:@" DEFAULTS bodyID"] UTF8String],
                        [NSString stringWithFormat:@"%ld", (long)((NSInteger (*)(id, SEL))objc_msgSend)(body, @selector(bodyID))]);
                }
                if ([body respondsToSelector:@selector(objectID)]) {
                    row([[name stringByAppendingString:@" DEFAULTS objectID"] UTF8String],
                        [NSString stringWithFormat:@"%ld", (long)((NSInteger (*)(id, SEL))objc_msgSend)(body, @selector(objectID))]);
                }
                if ([body respondsToSelector:@selector(faceID)]) {
                    row([[name stringByAppendingString:@" DEFAULTS faceID"] UTF8String],
                        [NSString stringWithFormat:@"%ld", (long)((NSInteger (*)(id, SEL))objc_msgSend)(body, @selector(faceID))]);
                }
                if ([body respondsToSelector:@selector(hasRollAngle)]) {
                    BOOL has = ((BOOL (*)(id, SEL))objc_msgSend)(body, @selector(hasRollAngle));
                    CGFloat angle = ((CGFloat (*)(id, SEL))objc_msgSend)(body, @selector(rollAngle));
                    row([[name stringByAppendingString:@" DEFAULTS rollAngle"] UTF8String],
                        [NSString stringWithFormat:@"has=%@ angle=%.1f", has ? @"YES" : @"NO", (double)angle]);
                }
                if ([body respondsToSelector:@selector(hasYawAngle)]) {
                    BOOL has = ((BOOL (*)(id, SEL))objc_msgSend)(body, @selector(hasYawAngle));
                    CGFloat angle = ((CGFloat (*)(id, SEL))objc_msgSend)(body, @selector(yawAngle));
                    row([[name stringByAppendingString:@" DEFAULTS yawAngle"] UTF8String],
                        [NSString stringWithFormat:@"has=%@ angle=%.1f", has ? @"YES" : @"NO", (double)angle]);
                }
            }
        }

        // ---- AVMetadataItem's own members, which are a category on the release's class.
        {
            Class c = CLASS_OF(AVMetadataItem);
            id item = instanceOf(c);
            respondsTo(item, "AVMetadataItem -startDate", @selector(startDate));
            classRespondsTo(c, "AVMetadataItem +metadataItemsFromArray:filteredByIdentifier:",
                            NSSelectorFromString(@"metadataItemsFromArray:filteredByIdentifier:"));
            classRespondsTo(c, "AVMetadataItem +metadataItemsFromArray:filteredByMetadataItemFilter:",
                            NSSelectorFromString(@"metadataItemsFromArray:filteredByMetadataItemFilter:"));
            classRespondsTo(c, "AVMetadataItem +metadataItemWithPropertiesOfMetadataItem:valueLoadingHandler:",
                            NSSelectorFromString(@"metadataItemWithPropertiesOfMetadataItem:valueLoadingHandler:"));
            row("DEFAULTS AVMetadataItem after -init -startDate",
                describeDate(guarded(item, @selector(startDate))));
            // The two filters, by what they answer. Items cannot be given identifiers on either side -
            // -key and -keySpace are readonly and no public initializer sets them - so the comparable
            // inputs are the empty array, which the header says answers an empty array, and nil, which
            // its nullable says answers nil rather than an empty array.
            SEL byIdentifier = NSSelectorFromString(@"metadataItemsFromArray:filteredByIdentifier:");
            SEL byFilter = NSSelectorFromString(@"metadataItemsFromArray:filteredByMetadataItemFilter:");
            row("AVMetadataItem filter(identifier) over an empty array",
                describe(((id (*)(id, SEL, id, id))objc_msgSend)(c, byIdentifier, @[], @"mdta/none")));
            id nilAnswer = ((id (*)(id, SEL, id, id))objc_msgSend)(c, byIdentifier, nil, @"mdta/none");
            row("AVMetadataItem filter(identifier) over nil", nilAnswer ? describe(nilAnswer) : @"(nil)");
            id shared = [CLASS_OF(AVMetadataItemFilter)
                respondsToSelector:NSSelectorFromString(@"metadataItemFilterForSharing")]
                ? ((id (*)(id, SEL))objc_msgSend)(CLASS_OF(AVMetadataItemFilter),
                                                  NSSelectorFromString(@"metadataItemFilterForSharing"))
                : nil;
            row("AVMetadataItem the shared filter is available", shared ? @"yes" : @"no");
            row("AVMetadataItem filter(shared filter) over an empty array",
                describe(((id (*)(id, SEL, id, id))objc_msgSend)(c, byFilter, @[], shared)));
            id filterNil = ((id (*)(id, SEL, id, id))objc_msgSend)(c, byFilter, nil, shared);
            row("AVMetadataItem filter(shared filter) over nil", filterNil ? describe(filterNil) : @"(nil)");
            // The 9.0 member: a new item built from a source, with the handler the header names.
            SEL withProperties =
                NSSelectorFromString(@"metadataItemWithPropertiesOfMetadataItem:valueLoadingHandler:");
            __block NSInteger handlerCalls = 0;
            void (^reader)(id, NSString *, id *) = ^(id object, NSString *key, id *outValue) {
                handlerCalls++;
                if (outValue) {
                    *outValue = @"a value";
                }
            };
            id built = ((id (*)(id, SEL, id, id))objc_msgSend)(c, withProperties, item, reader);
            row("AVMetadataItem +metadataItemWithPropertiesOfMetadataItem: answers a mutable item",
                built ? [NSString stringWithFormat:@"yes, %@", NSStringFromClass([built class])] : @"(nil)");
            row("AVMetadataItem +metadataItemWithPropertiesOfMetadataItem: ran the handler",
                [NSString stringWithFormat:@"%ld time(s)", (long)handlerCalls]);
            // startDate, read back through the mutable spelling after a set, and through the immutable
            // one on an item nobody set: both must answer, from one store.
            id mutable = instanceOf(CLASS_OF(AVMutableMetadataItem));
            respondsTo(mutable, "AVMutableMetadataItem -startDate", @selector(startDate));
            respondsTo(mutable, "AVMutableMetadataItem -setStartDate:", @selector(setStartDate:));
            if ([mutable respondsToSelector:@selector(setStartDate:)]) {
                ((void (*)(id, SEL, id))objc_msgSend)(mutable, @selector(setStartDate:),
                                                      [NSDate dateWithTimeIntervalSince1970:1000000000]);
            }
            row("DEFAULTS AVMutableMetadataItem after -setStartDate:",
                describeDate(guarded(mutable, @selector(startDate))));
        }

        // ---- the port's OWN construction. Every row here starts with ~: it is a row about a
        // Charon-prefixed initializer, so there is no Apple counterpart to compare it to, and the
        // join holds these rows against the unmutated baseline. They exist so that a mutation of an
        // initializer has something to break - the four findings of the last round were that every
        // mutant passed, and two of the five were aimed at initializer lines this table never read.
        {
            SEL groupInit = NSSelectorFromString(@"charon_initWithItems:timeRange:");
            id group = instanceOf(CLASS_OF(AVMetadataGroup));
            if ([group respondsToSelector:groupInit]) {
                AVMetadataItem *first = (AVMetadataItem *)[[AVMetadataItem alloc] init];
                AVMetadataItem *second = (AVMetadataItem *)[[AVMetadataItem alloc] init];
                // Its own instance per group, and never twice on one: -charon_initWithItems:timeRange:
                // is an initializer, so a second call re-initialises the receiver. The first version of
                // this row built both groups from one object, so "equals a different group" was
                // comparing an object with itself, answered YES, and taught the copyeq mutant nothing.
                id made = ((id (*)(id, SEL, id, CMTimeRange))objc_msgSend)(instanceOf(CLASS_OF(AVMetadataGroup)),
                                                                          groupInit, (@[first, second]),
                                                                          CMTimeRangeMake(CMTimeMake(5, 1),
                                                                                           CMTimeMake(7, 1)));
                row("~CONSTRUCTED group items", describe(guarded(made, @selector(items))));
                row("~CONSTRUCTED group timeRange", describeRange(guardedRange(made, @selector(timeRange))));
                id copied = guarded(made, @selector(copyWithZone:));
                row("~CONSTRUCTED group copy items", describe(guarded(copied, @selector(items))));
                row("~CONSTRUCTED group copy equals the original",
                    copied ? ([copied isEqual:made] ? @"yes" : @"NO") : @"(no copy)");
                row("~CONSTRUCTED group copy is a different object",
                    (copied && copied != made) ? @"yes" : @"NO");
                // -isEqual: against a group that is NOT the same: an -isEqual: that always answers YES
                // is invisible to the copy row above, because a copy of an equal group is equal either
                // way. This row is what sees it, and it is why the copyeq mutation has a target.
                id other = ((id (*)(id, SEL, id, CMTimeRange))objc_msgSend)(instanceOf(CLASS_OF(AVMetadataGroup)),
                                                                           groupInit, (@[first]),
                                                                           CMTimeRangeMake(CMTimeMake(9, 1),
                                                                                            CMTimeMake(1, 1)));
                // The diagnosis of the copyeq row, kept as rows because a diagnostic nobody can see
                // is a diagnostic that does not happen. These name what the two groups actually hold
                // and WHICH class implements -isEqual: for the object the row asks, which is the
                // question the YES turned on: the port's class and Apple's are two classes in one
                // binary, and a row that reached the wrong one would be measuring Apple.
                row("~DIAG made class", [NSString stringWithFormat:@"%@", NSStringFromClass([made class])]);
                row("~DIAG other class", other ? [NSString stringWithFormat:@"%@", NSStringFromClass([other class])] : @"(nil)");
                row("~DIAG made items", describe(guarded(made, @selector(items))));
                row("~DIAG other items", describe(guarded(other, @selector(items))));
                row("~DIAG made timeRange", describeRange(guardedRange(made, @selector(timeRange))));
                row("~DIAG other timeRange", describeRange(guardedRange(other, @selector(timeRange))));
                // The IMP as a name, read the way the runtime reports one: class_getMethodName on the
                // class that was asked, and the IMP's own address against the two candidates below.
                // A function pointer is not a Class, so it is printed as a pointer and compared as one.
                row("~DIAG made isEqual: reaches the port's implementation",
                    class_getMethodImplementation([made class], @selector(isEqual:))
                        == class_getMethodImplementation(CLASS_OF(AVMetadataGroup), @selector(isEqual:))
                        ? @"yes" : @"NO");
                row("~DIAG made isEqual: reaches Apple's implementation",
                    class_getMethodImplementation([made class], @selector(isEqual:))
                        == class_getMethodImplementation(NSClassFromString(@"AVMetadataGroup"), @selector(isEqual:))
                        ? @"yes" : @"no");
                row("~DIAG other is a group", [other isKindOfClass:[made class]] ? @"yes" : @"NO");
                row("~CONSTRUCTED group equals a different group",
                    other ? ([made isEqual:other] ? @"YES" : @"no") : @"(no second group)");
                row("~CONSTRUCTED group is not equal to a plain object",
                    [made isEqual:@"not a group"] ? @"YES" : @"no");
            }

            // An INSTANCE, not the Class: -respondsToSelector: sent to a class object asks its
            // metaclass, which does not carry the instance methods, so testing the class silently
            // ran zero rows. That is how four of the five construction blocks below printed nothing
            // and the first version of this looked like it had rows to mutate when it had five.
            id dated = instanceOf(CLASS_OF(AVDateRangeMetadataGroup));
            SEL datedInit = NSSelectorFromString(@"charon_initWithItems:startDate:endDate:");
            if ([dated respondsToSelector:datedInit]) {
                NSDate *from = [NSDate dateWithTimeIntervalSince1970:1000000000];
                NSDate *to = [NSDate dateWithTimeIntervalSince1970:1600000000];
                id made = ((id (*)(id, SEL, id, id, id))objc_msgSend)(dated, datedInit, @[], from, to);
                row("~CONSTRUCTED date range startDate", describeDate(guarded(made, @selector(startDate))));
                row("~CONSTRUCTED date range endDate", describeDate(guarded(made, @selector(endDate))));
                // The round trip the host cannot be asked for: sending -setStartDate: to this host's
                // AVMutableDateRangeMetadataGroup after a bare -init segfaults, so there is no Apple
                // answer to compare and the row is the port's own.
                id mutable = instanceOf(CLASS_OF(AVMutableDateRangeMetadataGroup));
                if ([mutable respondsToSelector:@selector(setStartDate:)]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(mutable, @selector(setStartDate:), from);
                    row("~CONSTRUCTED mutable date range after -setStartDate:",
                        describeDate(guarded(mutable, @selector(startDate))));
                    ((void (*)(id, SEL, id))objc_msgSend)(mutable, @selector(setEndDate:), to);
                    row("~CONSTRUCTED mutable date range after -setEndDate:",
                        describeDate(guarded(mutable, @selector(endDate))));
                }
            }

            id body = instanceOf(CLASS_OF(AVMetadataBodyObject));
            SEL bodyInit = NSSelectorFromString(@"charon_initWithBodyID:objectID:faceID:rollAngle:yawAngle:");
            if ([body respondsToSelector:bodyInit]) {
                id made = ((id (*)(id, SEL, NSInteger, NSInteger, NSInteger, CGFloat, CGFloat))objc_msgSend)(
                    body, bodyInit, 3, 11, 5, (CGFloat)12.5, (CGFloat)-7.25);
                row("~CONSTRUCTED body bodyID", [NSString stringWithFormat:@"%ld", (long)((NSInteger (*)(id, SEL))objc_msgSend)(made, @selector(bodyID))]);
                row("~CONSTRUCTED body objectID", [NSString stringWithFormat:@"%ld", (long)((NSInteger (*)(id, SEL))objc_msgSend)(made, @selector(objectID))]);
                row("~CONSTRUCTED body faceID", [NSString stringWithFormat:@"%ld", (long)((NSInteger (*)(id, SEL))objc_msgSend)(made, @selector(faceID))]);
                row("~CONSTRUCTED body hasRollAngle",
                    [NSString stringWithFormat:@"%@", ((BOOL (*)(id, SEL))objc_msgSend)(made, @selector(hasRollAngle)) ? @"YES" : @"NO"]);
                row("~CONSTRUCTED body rollAngle",
                    [NSString stringWithFormat:@"%.2f", (double)((CGFloat (*)(id, SEL))objc_msgSend)(made, @selector(rollAngle))]);
                row("~CONSTRUCTED body yawAngle",
                    [NSString stringWithFormat:@"%.2f", (double)((CGFloat (*)(id, SEL))objc_msgSend)(made, @selector(yawAngle))]);
                id copied = guarded(made, @selector(copyWithZone:));
                row("~CONSTRUCTED body copy equals the original",
                    copied ? ([copied isEqual:made] ? @"yes" : @"NO") : @"(no copy)");
            }

            for (NSString *name in @[@"AVMetadataCatBodyObject", @"AVMetadataDogBodyObject",
                                     @"AVMetadataHumanBodyObject", @"AVMetadataSalientObject"]) {
                id typed = instanceOf(NSClassFromString(name));
                SEL typedInit = NSSelectorFromString(@"charon_initWithObjectID:faceID:rollAngle:yawAngle:");
                if ([typed respondsToSelector:typedInit]) {
                    id made = ((id (*)(id, SEL, NSInteger, NSInteger, CGFloat, CGFloat))objc_msgSend)(
                        typed, typedInit, 11, 5, (CGFloat)1.5, (CGFloat)2.5);
                    row([[name stringByAppendingString:@" ~CONSTRUCTED objectID"] UTF8String],
                        [NSString stringWithFormat:@"%ld", (long)((NSInteger (*)(id, SEL))objc_msgSend)(made, @selector(objectID))]);
                    row([[name stringByAppendingString:@" ~CONSTRUCTED rollAngle"] UTF8String],
                        [NSString stringWithFormat:@"%.2f", (double)((CGFloat (*)(id, SEL))objc_msgSend)(made, @selector(rollAngle))]);
                }
            }

            id request = instanceOf(CLASS_OF(AVMetadataItemValueRequest));
            SEL requestInit = NSSelectorFromString(@"charon_initWithSpecifier:");
            if ([request respondsToSelector:requestInit]) {
                id made = ((id (*)(id, SEL, id))objc_msgSend)(request, requestInit, @"a specifier");
                row("~CONSTRUCTED value request specifier", describe(guarded(made, @selector(specifier))));
                if ([made respondsToSelector:@selector(respondWithValue:)]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(made, @selector(respondWithValue:), @"answered");
                    row("~CONSTRUCTED value request after -respondWithValue:",
                        describe(guarded(made, NSSelectorFromString(@"charon_responseValue"))));
                }
                if ([made respondsToSelector:@selector(respondWithError:)]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(made, @selector(respondWithError:),
                                                          [NSError errorWithDomain:NSURLErrorDomain code:7 userInfo:nil]);
                    row("~CONSTRUCTED value request after -respondWithError:",
                        describe(guarded(made, NSSelectorFromString(@"charon_responseError"))));
                }
            }
        }

    }
    return 0;
}
