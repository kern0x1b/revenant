#import "RevenantSecurityUI.h"

@interface RevenantCertificateSheetController : UIViewController
@property (nonatomic, copy) NSString *sheetTitle;
@property (nonatomic, copy) NSString *sheetMessage;
@property (nonatomic, copy) NSArray<NSString *> *lines;
@property (nonatomic, strong) NSURL *helpURL;
@property (nonatomic, copy) void (^dismissHandler)(void);

+ (NSArray<NSString *> *)linesForTrust:(SecTrustRef)trust;
@end

@implementation RevenantCertificateSheetController {
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
        [_learnMore addTarget:self action:@selector(revenant_openHelp) forControlEvents:UIControlEventTouchUpInside];
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

- (void)revenant_openHelp
{
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

#ifndef REVENANT_HOST_DIFFERENTIAL
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
@property (nonatomic, strong) RevenantCertificateSheetController *sheet;
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
        if (trust)
            _trust = (SecTrustRef)CFRetain(trust);
    }
    return self;
}

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

    RevenantCertificateSheetController *sheet = [[RevenantCertificateSheetController alloc] init];
    sheet.sheetTitle = self.title;
    sheet.sheetMessage = self.message;
    sheet.lines = [[RevenantCertificateSheetController class] linesForTrust:self.trust];
    sheet.helpURL = self.helpURL;
    sheet.dismissHandler = dismissHandler;
    sheet.modalPresentationStyle = UIModalPresentationFormSheet;
    _sheet = sheet;
    _presentation = viewController;
    [viewController presentViewController:sheet animated:YES completion:nil];
}

- (void)dismissSheet
{
    RevenantCertificateSheetController *sheet = _sheet;
    UIViewController *presentation = _presentation;
    _sheet = nil;
    _presentation = nil;
    if (sheet.presentingViewController) {
        [presentation dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    void (^dismissHandler)(void) = sheet.dismissHandler;
    sheet.dismissHandler = nil;
    if (dismissHandler)
        dispatch_async(dispatch_get_main_queue(), dismissHandler);
}

@end
