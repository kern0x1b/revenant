#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "RevenantAVMetadataConstruction.h"

#include <stdio.h>

static void row(const char *key, NSString *value)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    printf("%s | %s\n", key, [value UTF8String]);
    fflush(stdout);
}

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

static void superclassRow(Class c, const char *member)
{
    NSString *name = c ? [NSString stringWithUTF8String:class_getName(class_getSuperclass(c))] : nil;
    row(member, name ? [name stringByReplacingOccurrencesOfString:@"revenant_host_" withString:@""] : @"(no class)");
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

#define CLASS_OF(name) [name class]

int main(void)
{
    @autoreleasepool {
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
            SEL factory = NSSelectorFromString(@"revenant_metadataItemFilterWithIdentifiers:");
            id built = nil;
            if ([c respondsToSelector:factory]) {
                built = ((id (*)(id, SEL, id))objc_msgSend)(c, factory, (@[@"mdta/one", @"mdta/two"]));
            }
            row("~CONSTRUCTED filter built with two -allowList", describe(safe(built, @selector(allowList))));
            row("~CONSTRUCTED filter built with two -identifiers", describe(safe(built, @selector(identifiers))));
        }

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
            id copy = guarded(group, @selector(copyWithZone:));
            row("DEFAULTS AVMetadataGroup -copyWithZone: is a different object",
                (copy && copy != group) ? @"yes" : @"NO");
        }

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
            id fromNull = [group respondsToSelector:NSSelectorFromString(@"initWithSampleBuffer:")]
                ? ((id (*)(id, SEL, id))objc_msgSend)(group, NSSelectorFromString(@"initWithSampleBuffer:"), NULL)
                : nil;
            row("DEFAULTS AVTimedMetadataGroup -initWithSampleBuffer:(NULL) -timeRange",
                describeRange(guardedRange(fromNull, @selector(timeRange))));
        }

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
        }

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
            row("DEFAULTS AVMetadataItemValueRequest after -init -metadataItem",
                [request respondsToSelector:@selector(metadataItem)] ? @"declared" : @"absent");
            __block NSInteger handlerCalls = 0;
            SEL load = NSSelectorFromString(@"loadValuesAsynchronouslyForKeys:completionHandler:");
            if ([request respondsToSelector:load]) {
                ((void (*)(id, SEL, id, id))objc_msgSend)(request, load, (@[@"value"]), ^{
                    handlerCalls++;
                });
            }
            row("~CONSTRUCTED value request the asynchronous load calls the handler",
                [NSString stringWithFormat:@"%ld", (long)handlerCalls]);
            row("DEFAULTS value request -respondWithValue: on an unbacked instance",
                [request respondsToSelector:@selector(respondWithValue:)] ? @"declared" : @"absent");
        }

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

        {
            SEL groupInit = NSSelectorFromString(@"revenant_initWithItems:timeRange:");
            id group = instanceOf(CLASS_OF(AVMetadataGroup));
            if ([group respondsToSelector:groupInit]) {
                AVMetadataItem *first = (AVMetadataItem *)[[AVMetadataItem alloc] init];
                AVMetadataItem *second = (AVMetadataItem *)[[AVMetadataItem alloc] init];
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
                id other = ((id (*)(id, SEL, id, CMTimeRange))objc_msgSend)(instanceOf(CLASS_OF(AVMetadataGroup)),
                                                                           groupInit, (@[first]),
                                                                           CMTimeRangeMake(CMTimeMake(9, 1),
                                                                                            CMTimeMake(1, 1)));
                row("~DIAG made class", [NSString stringWithFormat:@"%@", NSStringFromClass([made class])]);
                row("~DIAG other class", other ? [NSString stringWithFormat:@"%@", NSStringFromClass([other class])] : @"(nil)");
                row("~DIAG made items", describe(guarded(made, @selector(items))));
                row("~DIAG other items", describe(guarded(other, @selector(items))));
                row("~DIAG made timeRange", describeRange(guardedRange(made, @selector(timeRange))));
                row("~DIAG other timeRange", describeRange(guardedRange(other, @selector(timeRange))));
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

            id dated = instanceOf(CLASS_OF(AVDateRangeMetadataGroup));
            SEL datedInit = NSSelectorFromString(@"revenant_initWithItems:startDate:endDate:");
            if ([dated respondsToSelector:datedInit]) {
                NSDate *from = [NSDate dateWithTimeIntervalSince1970:1000000000];
                NSDate *to = [NSDate dateWithTimeIntervalSince1970:1600000000];
                id made = ((id (*)(id, SEL, id, id, id))objc_msgSend)(dated, datedInit, @[], from, to);
                row("~CONSTRUCTED date range startDate", describeDate(guarded(made, @selector(startDate))));
                row("~CONSTRUCTED date range endDate", describeDate(guarded(made, @selector(endDate))));
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
            SEL bodyInit = NSSelectorFromString(@"revenant_initWithBodyID:objectID:faceID:rollAngle:yawAngle:");
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
                SEL typedInit = NSSelectorFromString(@"revenant_initWithObjectID:faceID:rollAngle:yawAngle:");
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
            SEL requestInit = NSSelectorFromString(@"revenant_initWithSpecifier:");
            if ([request respondsToSelector:requestInit]) {
                id made = ((id (*)(id, SEL, id))objc_msgSend)(request, requestInit, @"a specifier");
                row("~CONSTRUCTED value request specifier", describe(guarded(made, @selector(specifier))));
                if ([made respondsToSelector:@selector(respondWithValue:)]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(made, @selector(respondWithValue:), @"answered");
                    row("~CONSTRUCTED value request after -respondWithValue:",
                        describe(guarded(made, NSSelectorFromString(@"revenant_responseValue"))));
                }
                if ([made respondsToSelector:@selector(respondWithError:)]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(made, @selector(respondWithError:),
                                                          [NSError errorWithDomain:NSURLErrorDomain code:7 userInfo:nil]);
                    row("~CONSTRUCTED value request after -respondWithError:",
                        describe(guarded(made, NSSelectorFromString(@"revenant_responseError"))));
                }
            }
        }

    }
    return 0;
}
