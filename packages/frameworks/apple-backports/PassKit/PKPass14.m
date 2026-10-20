#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>

@interface PKPass (RevenantReleaseJSON)
- (NSDictionary *)dictionaryRepresentation;
@end

@interface PKPass (RevenantPassMembers)
@property (nonatomic, readonly, copy) NSDictionary *userInfo;
@property (nonatomic, readonly) PKPassType passType;
@property (nonatomic, readonly) NSArray<NSDate *> *relevantDates;
@end

@implementation PKPass (RevenantPassMembers)

- (NSDictionary *)userInfo
{
    NSDictionary *json = [self dictionaryRepresentation];
    return json ?: @{};
}

- (PKPassType)passType
{
    NSString *declared = [[self dictionaryRepresentation] objectForKey:@"passType"];
    if ([declared isKindOfClass:[NSString class]] && [declared isEqualToString:@"payment"]) {
        return PKPassTypeSecureElement;
    }
    return PKPassTypeBarcode;
}

- (NSArray<NSDate *> *)relevantDates
{
    NSArray *declared = [[self dictionaryRepresentation] objectForKey:@"relevantDates"];
    if (![declared isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray *dates = [NSMutableArray array];
    for (id entry in declared) {
        NSString *text = nil;
        if ([entry isKindOfClass:[NSDictionary class]]) {
            id value = [entry objectForKey:@"date"];
            text = [value isKindOfClass:[NSString class]] ? value : nil;
        } else if ([entry isKindOfClass:[NSString class]]) {
            text = entry;
        }
        if (text.length == 0) {
            continue;
        }
        NSDateFormatter *iso = [[NSDateFormatter alloc] init];
        iso.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
        iso.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        NSDate *date = [iso dateFromString:text];
        if (date) {
            [dates addObject:date];
        }
    }
    return dates;
}

@end
