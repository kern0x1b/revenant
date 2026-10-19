// matrix.m - UIPrinter's answers, one line per measurement, over unreachable, malformed and absent URLs.
//
// One source, built twice by run.sh: against Mac Catalyst's own UIKit, and against the port's UIPrinter compiled with
// its class renamed, so both live in one process. The two outputs must be equal, line for line, except the open: lines,
// which name a difference on purpose (facts/UIKit/UIPrinter.md). Labels name the URLs and the answers and never a class,
// so the two builds print the same text. No printer answers the compared cases: every URL is one nothing listens on,
// one with no host, a file, nil, or a live IPP queue that does not exist (the Mac's CUPS answers client-error-not-found).

#import <UIKit/UIKit.h>

static NSString *const kLabels[] = { @"unreachable", @"nohost", @"file", @"nil", @"dns", @"queue-missing",
                                     @"https-unreachable", @"ipps-unreachable" };
static NSString *const kURLs[] = {
    @"ipp://127.0.0.1:9/ipp/print", @"ipp:///ipp/print", @"file:///no/such/dir/none.txt", nil,
    @"ipp://nonexistent.invalid:631/ipp", @"ipp://localhost:631/printers/no_such_queue",
    @"https://127.0.0.1:9/ipp/print", @"ipps://127.0.0.1:9/ipp/print",
};
#define NCASES 8

static void print_printer(const char *label, UIPrinter *p)
{
    if (!p) {
        printf("%s: no printer\n", label);
        return;
    }
    printf("%s: URL=%s displayName=%s location=%s model=%s jobs=%ld color=%d duplex=%d\n", label,
           p.URL ? [[p.URL absoluteString] UTF8String] : "nil",
           p.displayName ? [p.displayName UTF8String] : "nil",
           p.displayLocation ? [p.displayLocation UTF8String] : "nil",
           p.makeAndModel ? [p.makeAndModel UTF8String] : "nil",
           (long)p.supportedJobTypes, p.supportsColor, p.supportsDuplex);
}

// UIPrintServiceExtension, measured on its own: the base class answers no destinations for any print info.
static void print_extension(void)
{
    UIPrintServiceExtension *extension = [[UIPrintServiceExtension alloc] init];
    printf("extension-alloc-init: %d\n", extension != nil);
    NSArray *none = [extension printerDestinationsForPrintInfo:nil];
    printf("extension-nil-info: array=%d count=%lu\n", [none isKindOfClass:[NSArray class]], (unsigned long)[none count]);
    NSArray *fresh = [extension printerDestinationsForPrintInfo:[UIPrintInfo printInfo]];
    printf("extension-printinfo: array=%d count=%lu\n", [fresh isKindOfClass:[NSArray class]], (unsigned long)[fresh count]);
}

static void print_destination(const char *label, UIPrinterDestination *d)
{
    if (!d) {
        printf("%s: no destination\n", label);
        return;
    }
    printf("%s: URL=%s displayName=%s txtRecord=%s\n", label,
           d.URL ? [[d.URL absoluteString] UTF8String] : "nil",
           d.displayName ? [d.displayName UTF8String] : "nil",
           d.txtRecord ? "set" : "nil");
}

static void print_destinations(void)
{
    NSURL *url = [NSURL URLWithString:@"ipp://printer.local:631/ipp/print"];
    print_destination("destination-url", [[UIPrinterDestination alloc] initWithURL:url]);
    print_destination("destination-nil-url", [[UIPrinterDestination alloc] initWithURL:nil]);
    print_destination("destination-bare-init", [[UIPrinterDestination alloc] init]);
    printf("destination-secure-coding: %d\n", [UIPrinterDestination supportsSecureCoding]);

    UIPrinterDestination *d = [[UIPrinterDestination alloc] initWithURL:url];
    d.displayName = @"Office";
    d.txtRecord = [NSData dataWithBytes:"ty=x" length:4];
    print_destination("destination-set", d);

    // open: the host's archive does not decode, so this is an open difference, not a line the two must match
    NSError *error = nil;
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:d requiringSecureCoding:YES error:&error];
    printf("open:archive: written=%d error=%d\n", archive != nil, error != nil);
    if (archive) {
        NSError *decodeError = nil;
        UIPrinterDestination *back = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIPrinterDestination class]
                                                                       fromData:archive error:&decodeError];
        printf("open:roundtrip: decoded=%d URL=%s displayName=%s error=%s\n", back != nil,
               back.URL ? [[back.URL absoluteString] UTF8String] : "nil",
               back.displayName ? [back.displayName UTF8String] : "nil",
               decodeError ? [[decodeError localizedDescription] UTF8String] : "none");
    }
}

// UIPrinterPickerController. The host selects a placeholder at once and completes with userDidSelect YES before
// presentAnimated: returns, so its presentation lines are open differences (facts/UIKit/UIPrinterPickerController.md).
@interface CharonPickerParent : UIViewController <UIPrinterPickerControllerDelegate>
@end

@implementation CharonPickerParent
- (UIViewController *)printerPickerControllerParentViewController:(UIPrinterPickerController *)picker
{
    return self;
}
@end

static void pump(NSTimeInterval seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

static void print_picker(void)
{
    printf("picker-class: exists=%d\n", [UIPrinterPickerController class] != nil);

    UIPrinter *initial = [UIPrinter printerWithURL:[NSURL URLWithString:@"ipp://127.0.0.1:9/ipp/print"]];
    UIPrinterPickerController *picker = [UIPrinterPickerController printerPickerControllerWithInitiallySelectedPrinter:initial];
    printf("open:picker-initial-selected: set=%d same=%d url=%s\n", picker.selectedPrinter != nil, picker.selectedPrinter == initial,
           picker.selectedPrinter.URL ? [[picker.selectedPrinter.URL absoluteString] UTF8String] : "nil");
    printf("picker-initial-selected: set=%d\n", picker.selectedPrinter != nil);
    printf("picker-same-object-again: %d\n", picker == [UIPrinterPickerController printerPickerControllerWithInitiallySelectedPrinter:initial]);

    UIPrinterPickerController *none = [UIPrinterPickerController printerPickerControllerWithInitiallySelectedPrinter:nil];
    printf("open:picker-nil-initial: set=%d url=%s\n", none.selectedPrinter != nil,
           none.selectedPrinter.URL ? "set" : "nil");

    CharonPickerParent *parent = [[CharonPickerParent alloc] init];
    picker.delegate = parent;
    __block int calls = 0, selected = -1, sameController = 0;
    __block NSError *error = nil;
    BOOL presented = [picker presentAnimated:NO completionHandler:^(UIPrinterPickerController *done, BOOL didSelect, NSError *e) {
        calls++;
        selected = didSelect;
        sameController = done == picker;
        error = e;
    }];
    printf("open:picker-present: returned=%d calls-before-return=%d userDidSelect=%d\n", presented, calls, selected);
    pump(0.5);
    printf("open:picker-present-after: calls=%d userDidSelect=%d\n", calls, selected);
    [picker dismissAnimated:NO];
    pump(0.5);
    printf("open:picker-dismiss: calls=%d userDidSelect=%d same=%d error=%d\n", calls, selected, sameController, error != nil);
    printf("open:picker-completion-count: calls=%d\n", calls);
}

// one contactPrinter: call, with what the handler got and whether it ran before the call returned
static void print_contact(const char *prefix, const char *label, NSURL *url)
{
    UIPrinter *p = [UIPrinter printerWithURL:url];
    __block BOOL done = NO, available = NO, onMain = NO;
    __block int calls = 0;
    [p contactPrinter:^(BOOL reached) {
        calls++;
        available = reached;
        onMain = [NSThread isMainThread];
        done = YES;
    }];
    int early = calls;
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:35];
    while (!done && [limit timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    printf("%s%s-contact: calls=%d before-return=%d available=%d main=%d\n", prefix, label, calls, early, available, onMain);
}

int main(void)
{
    @autoreleasepool {
        print_extension();
        print_destinations();
        print_picker();

        for (int i = 0; i < NCASES; i++) {
            NSURL *url = kURLs[i] ? [NSURL URLWithString:kURLs[i]] : nil;
            UIPrinter *p = [UIPrinter printerWithURL:url];
            print_printer([[NSString stringWithFormat:@"%@-printer", kLabels[i]] UTF8String], p);
            printf("%s-same-object-again: %d\n", [kLabels[i] UTF8String], p == [UIPrinter printerWithURL:url]);
        }

        for (int i = 0; i < NCASES; i++)
            print_contact("", [kLabels[i] UTF8String], kURLs[i] ? [NSURL URLWithString:kURLs[i]] : nil);

        // open: the Mac's own live queue. The host answers NO for it, and the port answers YES on a successful IPP status
        // (facts/UIKit/UIPrinter.md). The queue's name is this Mac's; the line is informational.
        print_contact("open:", "live-queue", [NSURL URLWithString:@"ipp://localhost:631/printers/Canon_TS3400_series"]);

        // a nil handler: the call returns and nothing is reached
        [[UIPrinter printerWithURL:[NSURL URLWithString:kURLs[0]]] contactPrinter:nil];
        printf("nil-handler: returned\n");
    }
    return 0;
}
