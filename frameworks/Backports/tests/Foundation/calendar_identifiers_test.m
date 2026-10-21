#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    revenant_expect_string("NSCalendarIdentifierIslamicTabular", NSCalendarIdentifierIslamicTabular, revenant_negative ? @"islamic-civil" : @"islamic-tbla");
    revenant_expect_string("NSCalendarIdentifierIslamicUmmAlQura", NSCalendarIdentifierIslamicUmmAlQura, @"islamic-umalqura");
    return revenant_finish();
}
