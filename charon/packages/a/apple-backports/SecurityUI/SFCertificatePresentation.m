#import "CharonSecurityUI.h"

// The sheet a trust object is shown in. It is the port's own: a plain UIViewController with labels
// laid out in -viewDidLayoutSubviews, presented through the release's own modal presentation, which
// iOS 5 gave UIKit and which this release has. The lines are read out of the trust object itself
// with the Security calls that have been public since iOS 2, so what the sheet says is the trust's
// own content and not a rendering of it.

@interface CharonCertificateSheetController : UIViewController
@property (nonatomic, copy) NSString *sheetTitle;
@property (nonatomic, copy) NSString *sheetMessage;
@property (nonatomic, copy) NSArray<NSString *> *lines;
@property (nonatomic, strong) NSURL *helpURL;
@property (nonatomic, copy) void (^dismissHandler)(void);

// The trust's own content, read with the Security calls this release already carries. A NULL trust
// is what a caller that reached the unavailable -init holds, and then there is nothing to describe,
// so the sheet shows its title and message alone. It is a class method of the controller that draws
// the lines rather than a function of the file, so that what a sheet shows and what a test can ask
// for are one call and not two that agree by accident.
+ (NSArray<NSString *> *)linesForTrust:(SecTrustRef)trust;
@end

@implementation CharonCertificateSheetController {
    UILabel *_titleLabel;
    UILabel *_messageLabel;
    NSMutableArray<UILabel *> *_lineLabels;
    UIButton *_learnMore;
}

@synthesize sheetTitle = _sheetTitle;
@synthesize sheetMessage = _sheetMessage;
@synthesize lines = _lines;
@synthesize helpURL = _helpURL;
@synthesize dismissHandler = _dismissHandler;

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.94f alpha:1.0f];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.0f)];
    _titleLabel.text = self.sheetTitle.length ? self.sheetTitle : NSLocalizedString(@"Certificate", nil);
    _titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.numberOfLines = 0;
    [self.view addSubview:_titleLabel];

    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.0f)];
    _messageLabel.text = self.sheetMessage;
    _messageLabel.numberOfLines = 0;
    _messageLabel.font = [UIFont systemFontOfSize:13.0f];
    _messageLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_messageLabel];

    _lineLabels = [NSMutableArray array];
    for (NSString *line in self.lines) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 0.0f, 0.0f)];
        label.text = line;
        label.numberOfLines = 0;
        label.font = [UIFont systemFontOfSize:12.0f];
        label.backgroundColor = [UIColor clearColor];
        [self.view addSubview:label];
        [_lineLabels addObject:label];
    }

    if (self.helpURL) {
        _learnMore = [UIButton buttonWithType:UIButtonTypeSystem];
        [_learnMore setTitle:NSLocalizedString(@"Learn More", nil) forState:UIControlStateNormal];
        [_learnMore addTarget:self action:@selector(charon_openHelp) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_learnMore];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width - 32.0f;
    CGFloat y = 20.0f;
    for (UILabel *label in [[NSArray alloc] initWithObjects:_titleLabel, _messageLabel, nil]) {
        CGFloat height = [label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;
        label.frame = CGRectMake(16.0f, y, width, height);
        y += height + 8.0f;
    }
    for (UILabel *label in _lineLabels) {
        CGFloat height = [label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;
        label.frame = CGRectMake(16.0f, y, width, height);
        y += height + 6.0f;
    }
    if (_learnMore) {
        CGSize fit = [_learnMore sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
        _learnMore.frame = CGRectMake(16.0f, y + 8.0f, MIN(width, fit.width), 30.0f);
    }
}

- (void)charon_openHelp
{
    // -openURL: is the release's own, measured in its armv7 6.1.3 metadata; a help URL is opened the
    // way this release opens any URL.
    UIApplication *application = [UIApplication sharedApplication];
    if (application && self.helpURL)
        [application openURL:self.helpURL];
}

+ (NSArray<NSString *> *)linesForTrust:(SecTrustRef)trust
{
    if (!trust)
        return @[];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];

    SecCertificateRef leaf = SecTrustGetCertificateAtIndex(trust, 0);
    CFStringRef subject = leaf ? SecCertificateCopySubjectSummary(leaf) : NULL;
    if (subject) {
        [lines addObject:(__bridge_transfer NSString *)subject];
    }
    CFIndex count = SecTrustGetCertificateCount(trust);
    for (CFIndex index = 1; index < count; index++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, index);
        subject = certificate ? SecCertificateCopySubjectSummary(certificate) : NULL;
        if (subject)
            [lines addObject:[NSString stringWithFormat:@"- %@", (__bridge_transfer NSString *)subject]];
    }

    SecTrustResultType result = kSecTrustResultInvalid;
    if (SecTrustEvaluate(trust, &result) == errSecSuccess) {
        switch (result) {
            case kSecTrustResultProceed:
            case kSecTrustResultUnspecified:
                [lines addObject:NSLocalizedString(@"Trusted", nil)];
                break;
            case kSecTrustResultRecoverableTrustFailure:
                [lines addObject:NSLocalizedString(@"Not trusted yet", nil)];
                break;
            case kSecTrustResultDeny:
            default:
                [lines addObject:NSLocalizedString(@"Not trusted", nil)];
                break;
        }
    }

#ifndef CHARON_HOST_DIFFERENTIAL
    // macCatalyst has no SecTrustCopyProperties - the call is API_UNAVAILABLE there, not deprecated -
    // so a host build cannot compile this line, and the host is the oracle for the other two lines of a
    // sheet. The lines it contributes are the trust's own dates and policy, and the device test
    // (tests/backports/emulate) is what covers them; see facts/SecurityUI/SFCertificatePresentation.md.
    NSArray *properties = (__bridge_transfer NSArray *)SecTrustCopyProperties(trust);
    for (NSDictionary *property in properties) {
        NSString *label = property[@"label"];
        id value = property[@"value"];
        if ([label isKindOfClass:[NSString class]] && value && value != [NSNull null])
            [lines addObject:[NSString stringWithFormat:@"%@: %@", label, value]];
    }
#endif
    return lines;
}

@end

@interface SFCertificatePresentation ()
@property (nonatomic, weak) UIViewController *presentation;
@property (nonatomic, strong) CharonCertificateSheetController *sheet;
@end

@implementation SFCertificatePresentation

@synthesize presentation = _presentation;
@synthesize sheet = _sheet;
@synthesize trust = _trust;
@synthesize title = _title;
@synthesize message = _message;
@synthesize helpURL = _helpURL;

- (instancetype)initWithTrust:(SecTrustRef)trust
{
    if ((self = [super init])) {
        // Retained only when there is something to retain: CFRetain(NULL) traps, and the header's
        // unavailable -init below is the one caller that passes NULL. Found by the host differential's
        // sheet.trustOfUnavailableInit case, which trapped before this guard.
        if (trust)
            _trust = (SecTrustRef)CFRetain(trust);
    }
    return self;
}

// The header marks -init unavailable and there is no other way to make one, so a caller that
// reaches it anyway gets a presentation with no trust to show: the sheet then carries its title and
// message alone. Nothing is invented to fill the gap.
// The designated initialiser's parameter is nonnull in the header, and NULL is exactly the point:
// this is the one caller the header says not to write, and the one that has to be answered.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
- (instancetype)init
{
    return [self initWithTrust:NULL];
}
#pragma clang diagnostic pop

- (void)dealloc
{
    [_sheet dismissViewControllerAnimated:NO completion:nil];
    if (_trust)
        CFRelease(_trust);
}

- (void)presentSheetInViewController:(UIViewController *)viewController dismissHandler:(void (^)(void))dismissHandler
{
    if (!viewController)
        return;
    [self dismissSheet];

    CharonCertificateSheetController *sheet = [[CharonCertificateSheetController alloc] init];
    sheet.sheetTitle = self.title;
    sheet.sheetMessage = self.message;
    sheet.lines = [[CharonCertificateSheetController class] linesForTrust:self.trust];
    sheet.helpURL = self.helpURL;
    sheet.dismissHandler = dismissHandler;
    sheet.modalPresentationStyle = UIModalPresentationFormSheet;
    _sheet = sheet;
    _presentation = viewController;
    [viewController presentViewController:sheet animated:YES completion:nil];
}

- (void)dismissSheet
{
    CharonCertificateSheetController *sheet = _sheet;
    UIViewController *presentation = _presentation;
    _sheet = nil;
    _presentation = nil;
    if (sheet.presentingViewController) {
        [presentation dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    // Nothing was ever presented, so there is no animation to wait for: the dismiss handler still
    // runs, once, as the header's dismissHandler is promised to.
    void (^dismissHandler)(void) = sheet.dismissHandler;
    sheet.dismissHandler = nil;
    if (dismissHandler)
        dispatch_async(dispatch_get_main_queue(), dismissHandler);
}

@end
