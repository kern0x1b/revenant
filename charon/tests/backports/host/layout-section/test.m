#import <UIKit/UIKit.h>
#include <stdio.h>

static void report(const char *check, NSString *value)
{
    printf("%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *number(long long value)
{
    return [NSString stringWithFormat:@"%lld", value];
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSCollectionLayoutSection *make_section(void)
{
    NSCollectionLayoutSize *size = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
                                                                  heightDimension:[NSCollectionLayoutDimension estimatedDimension:44]];
    NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:size];
    NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:size subitems:@[item]];
    return [NSCollectionLayoutSection sectionWithGroup:group];
}

static NSString *outcome(void (^change)(void))
{
    @try {
        change();
        return @"ok";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        NSCollectionLayoutSection *section = make_section();
        report("section-supplementary-default", number(section.supplementaryContentInsetsReference));
        report("section-follow-default", yes_no(section.supplementariesFollowContentInsets));
        report("section-content-default", number(section.contentInsetsReference));

        section = make_section();
        report("none-set", outcome(^{ section.supplementaryContentInsetsReference = UIContentInsetsReferenceNone; }));
        report("none-reference", number(section.supplementaryContentInsetsReference));
        report("none-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("flag-yes-set", outcome(^{ section.supplementariesFollowContentInsets = YES; }));
        report("flag-yes-reference", number(section.supplementaryContentInsetsReference));
        report("flag-yes-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("flag-no-set", outcome(^{ section.supplementariesFollowContentInsets = NO; }));
        report("flag-no-reference", number(section.supplementaryContentInsetsReference));
        report("flag-no-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("safe-set", outcome(^{ section.supplementaryContentInsetsReference = UIContentInsetsReferenceSafeArea; }));
        report("safe-reference", number(section.supplementaryContentInsetsReference));
        report("safe-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("automatic-set", outcome(^{ section.supplementaryContentInsetsReference = UIContentInsetsReferenceAutomatic; }));
        report("automatic-then-flag-no", outcome(^{ section.supplementariesFollowContentInsets = NO; }));
        report("automatic-then-flag-no-reference", number(section.supplementaryContentInsetsReference));

        section = make_section();
        report("none-then-flag-no", outcome(^{
            section.supplementaryContentInsetsReference = UIContentInsetsReferenceNone;
            section.supplementariesFollowContentInsets = NO;
        }));
        report("none-then-flag-no-reference", number(section.supplementaryContentInsetsReference));

        section = make_section();
        report("flag-no-then-none", outcome(^{
            section.supplementariesFollowContentInsets = NO;
            section.supplementaryContentInsetsReference = UIContentInsetsReferenceNone;
        }));
        report("flag-no-then-none-reference", number(section.supplementaryContentInsetsReference));
        report("flag-no-then-none-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("none-then-flag-yes", outcome(^{
            section.supplementaryContentInsetsReference = UIContentInsetsReferenceNone;
            section.supplementariesFollowContentInsets = YES;
        }));
        report("none-then-flag-yes-reference", number(section.supplementaryContentInsetsReference));
        report("none-then-flag-yes-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("safe-then-flag-yes", outcome(^{
            section.supplementaryContentInsetsReference = UIContentInsetsReferenceSafeArea;
            section.supplementariesFollowContentInsets = YES;
        }));
        report("safe-then-flag-yes-reference", number(section.supplementaryContentInsetsReference));
        report("safe-then-flag-yes-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("safe-then-flag-no", outcome(^{
            section.supplementaryContentInsetsReference = UIContentInsetsReferenceSafeArea;
            section.supplementariesFollowContentInsets = NO;
        }));
        report("safe-then-flag-no-reference", number(section.supplementaryContentInsetsReference));
        report("safe-then-flag-no-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("flag-no-then-safe", outcome(^{
            section.supplementariesFollowContentInsets = NO;
            section.supplementaryContentInsetsReference = UIContentInsetsReferenceSafeArea;
        }));
        report("flag-no-then-safe-reference", number(section.supplementaryContentInsetsReference));
        report("flag-no-then-safe-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("flag-yes-then-none", outcome(^{
            section.supplementariesFollowContentInsets = YES;
            section.supplementaryContentInsetsReference = UIContentInsetsReferenceNone;
        }));
        report("flag-yes-then-none-reference", number(section.supplementaryContentInsetsReference));
        report("flag-yes-then-none-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("flag-yes-then-flag-no", outcome(^{
            section.supplementariesFollowContentInsets = YES;
            section.supplementariesFollowContentInsets = NO;
        }));
        report("flag-yes-then-flag-no-reference", number(section.supplementaryContentInsetsReference));
        report("flag-yes-then-flag-no-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("flag-no-then-flag-yes", outcome(^{
            section.supplementariesFollowContentInsets = NO;
            section.supplementariesFollowContentInsets = YES;
        }));
        report("flag-no-then-flag-yes-reference", number(section.supplementaryContentInsetsReference));
        report("flag-no-then-flag-yes-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("none-then-automatic", outcome(^{
            section.supplementaryContentInsetsReference = UIContentInsetsReferenceNone;
            section.supplementaryContentInsetsReference = UIContentInsetsReferenceAutomatic;
        }));
        report("none-then-automatic-reference", number(section.supplementaryContentInsetsReference));
        report("none-then-automatic-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        report("flag-yes-then-automatic", outcome(^{
            section.supplementariesFollowContentInsets = YES;
            section.supplementaryContentInsetsReference = UIContentInsetsReferenceAutomatic;
        }));
        report("flag-yes-then-automatic-reference", number(section.supplementaryContentInsetsReference));
        report("flag-yes-then-automatic-follow", yes_no(section.supplementariesFollowContentInsets));

        section = make_section();
        section.contentInsetsReference = UIContentInsetsReferenceSafeArea;
        report("content-set-safe", number(section.contentInsetsReference));
        report("content-supplementary-unchanged", number(section.supplementaryContentInsetsReference));
        section.supplementaryContentInsetsReference = UIContentInsetsReferenceNone;
        NSCollectionLayoutSection *copied = [section copy];
        section.supplementaryContentInsetsReference = UIContentInsetsReferenceAutomatic;
        report("copy-supplementary", number(copied.supplementaryContentInsetsReference));
        report("copy-content", number(copied.contentInsetsReference));

        section = make_section();
        NSCollectionLayoutSection *twin = [section copy];
        report("equal-copy", yes_no([section isEqual:twin]));
        twin.supplementaryContentInsetsReference = UIContentInsetsReferenceNone;
        report("equal-after-reference", yes_no([section isEqual:twin]));
        twin.supplementaryContentInsetsReference = UIContentInsetsReferenceAutomatic;
        report("equal-after-reference-back", yes_no([section isEqual:twin]));
        twin.supplementariesFollowContentInsets = NO;
        report("equal-after-flag", yes_no([section isEqual:twin]));
    }
    return 0;
}
