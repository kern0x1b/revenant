#import <UIKit/UIKit.h>
#include <stdio.h>

typedef id (*Fn1)(id, SEL, id);
typedef id (*Fn2)(id, SEL, id, id);
typedef id (*Fn3)(id, SEL, id, id, id);
typedef id (*PlainFn)(id, SEL);

static void report(const char *side, const char *check, NSString *value)
{
    printf("%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *present(id object)
{
    return object ? @"set" : @"nil";
}

static id send0(id receiver, NSString *name)
{
    SEL sel = NSSelectorFromString(name);
    return ((PlainFn)[receiver methodForSelector:sel])(receiver, sel);
}

static void run(const char *side, Class cls)
{
    report(side, "item-superclass", NSStringFromClass([cls superclass]));

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(2, 2), NO, 1);
    UIImage *icon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(3, 3), NO, 1);
    UIImage *otherIcon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    SEL plainFactory = NSSelectorFromString(@"suggestionWithLocalizedSuggestion:descriptionString:iconImage:");
    SEL suggestionOnly = NSSelectorFromString(@"suggestionWithLocalizedSuggestion:");
    SEL attributedFactory = NSSelectorFromString(@"suggestionWithLocalizedAttributedSuggestion:descriptionString:iconImage:");

    id full = ((Fn3)[cls methodForSelector:plainFactory])(cls, plainFactory, @"apple", @"fruit", icon);
    report(side, "plain-suggestion", send0(full, @"localizedSuggestion"));
    report(side, "plain-description", send0(full, @"localizedDescription"));
    report(side, "plain-icon-kept", [send0(full, @"iconImage") isEqual:icon] ? @"yes" : @"no");
    report(side, "plain-attributed-nil", present(send0(full, @"localizedAttributedSuggestion")));
    report(side, "plain-represented-nil", present(send0(full, @"representedObject")));

    NSMutableString *mutableSuggestion = [NSMutableString stringWithString:@"cherry"];
    NSMutableString *mutableDescription = [NSMutableString stringWithString:@"red"];
    id copied = ((Fn3)[cls methodForSelector:plainFactory])(cls, plainFactory, mutableSuggestion, mutableDescription, nil);
    [mutableSuggestion appendString:@"-changed"];
    [mutableDescription appendString:@"-changed"];
    report(side, "suggestion-copied-from-mutable", yes_no([[copied localizedSuggestion] isEqualToString:@"cherry"]));
    report(side, "description-copied-from-mutable", yes_no([[copied localizedDescription] isEqualToString:@"red"]));

    id plain = ((Fn1)[cls methodForSelector:suggestionOnly])(cls, suggestionOnly, @"pear");
    report(side, "one-argument-description-nil", present(send0(plain, @"localizedDescription")));
    report(side, "one-argument-icon-nil", present(send0(plain, @"iconImage")));

    NSAttributedString *text = [[NSAttributedString alloc] initWithString:@"banana"];
    id attributed = ((Fn3)[cls methodForSelector:attributedFactory])(cls, attributedFactory, text, @"fruit", icon);
    report(side, "attributed-suggestion-text", send0(attributed, @"localizedSuggestion"));
    report(side, "attributed-kept-identity", send0(attributed, @"localizedAttributedSuggestion") == text ? @"yes" : @"no");
    report(side, "attributed-description", send0(attributed, @"localizedDescription"));

    SEL initOne = NSSelectorFromString(@"initWithLocalizedSuggestion:");
    id allocated = [cls alloc];
    id nilSuggestion = ((Fn1)[allocated methodForSelector:initOne])(allocated, initOne, nil);
    report(side, "nil-suggestion-object", nilSuggestion ? @"object" : @"nil");
    report(side, "nil-suggestion-text", present(send0(nilSuggestion, @"localizedSuggestion")));

    id a = ((Fn3)[cls methodForSelector:plainFactory])(cls, plainFactory, @"apple", @"fruit", icon);
    id b = ((Fn3)[cls methodForSelector:plainFactory])(cls, plainFactory, @"apple", @"fruit", icon);
    report(side, "equal-same-values", yes_no([a isEqual:b]));
    report(side, "hash-same-values", yes_no([a hash] == [b hash]));
    report(side, "equal-self", yes_no([a isEqual:a]));
    report(side, "equal-nil", yes_no([a isEqual:nil]));
    report(side, "equal-string", yes_no([a isEqual:@"apple"]));
    report(side, "equal-different-description", yes_no([a isEqual:((Fn3)[cls methodForSelector:plainFactory])(cls, plainFactory, @"apple", @"other", icon)]));
    report(side, "equal-different-icon", yes_no([a isEqual:((Fn3)[cls methodForSelector:plainFactory])(cls, plainFactory, @"apple", @"fruit", otherIcon)]));
    report(side, "equal-attributed-to-plain", yes_no([attributed isEqual:((Fn3)[cls methodForSelector:plainFactory])(cls, plainFactory, @"banana", @"fruit", icon)]));
    report(side, "equal-two-nil-suggestions", yes_no([nilSuggestion isEqual:((Fn1)[[cls alloc] methodForSelector:initOne])([cls alloc], initOne, nil)]));
    report(side, "equal-nil-description-to-none", yes_no([((Fn3)[cls methodForSelector:plainFactory])(cls, plainFactory, @"apple", nil, nil) isEqual:((Fn1)[cls methodForSelector:suggestionOnly])(cls, suggestionOnly, @"apple")]));

    [a setRepresentedObject:@"payload"];
    report(side, "represented-kept", [send0(a, @"representedObject") isEqual:@"payload"] ? @"yes" : @"no");
    report(side, "equal-differs-by-represented", yes_no([a isEqual:b]));
    [b setRepresentedObject:@"payload"];
    report(side, "equal-same-represented", yes_no([a isEqual:b]));
    [b setRepresentedObject:nil];

    report(side, "hidden-setter-absent", [cls instancesRespondToSelector:NSSelectorFromString(@"setLocalizedSuggestion:")] ? @"no" : @"yes");
    report(side, "copy-absent", [cls instancesRespondToSelector:@selector(copyWithZone:)] ? @"no" : @"yes");

    id bare = send0([cls alloc], @"init");
    report(side, "runtime-init-suggestion-nil", present(send0(bare, @"localizedSuggestion")));
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        run("host", NSClassFromString(@"UISearchSuggestionItem"));
        run("port", [UISearchSuggestionItem class]);
    }
    return 0;
}
