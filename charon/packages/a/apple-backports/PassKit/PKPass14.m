// The members of the release's own PassKit that iOS 7 and later added, as categories on the
// release's own classes. The classes are not this port's: apple.objc.inventory against the armv7 dyld
// shared cache of 6.1.3 shows PKPass with 90 instance methods and PKPassLibrary with 34, and the
// ledger's own list of what is missing for them is nine properties and two constants. So this is
// nine properties over the release's objects, and not a second PKPass.
//
// The one thing this file does not do is answer a property whose answer is a Secure Element. The
// release has no `PKPaymentPass` and the device has no Secure Element, so `paymentPass` and
// `secureElementPass` are registry entries of status `absent` with those reasons and are not
// implemented here: a program that reaches them through the runtime gets no method, which is what an
// absent entry means, rather than a property that lies. `remotePass` is `absent` too, for another
// reason: the release DOES have a `PKRemotePass`, a `PKPass` subclass of 8 methods in the armv7 cache
// of 6.1.3 (facts/PassKit/PassKit.md, "Correction 2"), but its `PKPass` has no `-isRemotePass`, and
// the row's own reason says why the getter is not carried (PassKit/PKPaymentPass9.m).
#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>

// The release's own reading of a pass's JSON, which is in the armv7 cache of 6.1.3 (measured with
// apple.objc.inventory) and which the 16.4 header does not declare. Declared and not implemented
// here: the method is the release's.
@interface PKPass (CharonReleaseJSON)
- (NSDictionary *)dictionaryRepresentation;
@end

@interface PKPass (CharonPassMembers)
@property (nonatomic, readonly, copy) NSDictionary *userInfo;
@property (nonatomic, readonly) PKPassType passType;
@property (nonatomic, readonly) NSArray<NSDate *> *relevantDates;
@end

@implementation PKPass (CharonPassMembers)

// The pass's own JSON, which the release carries: -dictionaryRepresentation is in the 6.1.3 cache
// (measured) and is the release's own reading of the pass. Everything this category answers is read
// out of it, so the answer is Apple's own data about the pass and not this port's opinion of it.
- (NSDictionary *)userInfo
{
    NSDictionary *json = [self dictionaryRepresentation];
    return json ?: @{};
}

- (PKPassType)passType
{
    // The pass says which kind it is in its own JSON, under Apple's own "passType" key, and the SDK's
    // own PKPassType is the two kinds that distinction makes: a pass that lives in the Secure
    // Element (Apple's own "payment") and a pass that does not (everything else, which is a barcode).
    // A pass that says nothing is a barcode pass, which is what a pass with no payment key is.
    NSString *declared = [[self dictionaryRepresentation] objectForKey:@"passType"];
    if ([declared isKindOfClass:[NSString class]] && [declared isEqualToString:@"payment"]) {
        return PKPassTypeSecureElement;
    }
    return PKPassTypeBarcode;
}

// The dates the pass declares as relevant, out of the pass's own JSON: Apple's own key is a list of
// dictionaries with a "date" and an optional "relevantStyle", and the dates are the ones the pass
// itself names. A pass that names none has none.
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
