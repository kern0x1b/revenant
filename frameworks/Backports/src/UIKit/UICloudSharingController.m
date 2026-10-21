#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface UICloudSharingController (RevenantInit)
- (instancetype)initRevenantWithShare:(CKShare *)share preparationHandler:(id)preparationHandler;
@end

@implementation UICloudSharingController {
    __weak id<UICloudSharingControllerDelegate> _delegate;
    CKShare *_share;
    id _preparationHandler;
    UICloudSharingPermissionOptions _availablePermissions;
}

- (instancetype)initRevenantWithShare:(CKShare *)share preparationHandler:(id)preparationHandler
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _share = share;
        _preparationHandler = [preparationHandler copy];
    }
    return self;
}

- (instancetype)initWithShare:(CKShare *)share container:(CKContainer *)container
{
    return [self initRevenantWithShare:share preparationHandler:nil];
}

- (instancetype)initWithPreparationHandler:(void (^)(UICloudSharingController *controller, void (^preparationCompletionHandler)(CKShare *, CKContainer *, NSError *)))preparationHandler
{
    return [self initRevenantWithShare:nil preparationHandler:preparationHandler];
}

- (id<UICloudSharingControllerDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id<UICloudSharingControllerDelegate>)delegate
{
    _delegate = delegate;
}

- (CKShare *)share
{
    return _share;
}

- (UICloudSharingPermissionOptions)availablePermissions
{
    return _availablePermissions;
}

- (void)setAvailablePermissions:(UICloudSharingPermissionOptions)availablePermissions
{
    _availablePermissions = availablePermissions;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [NSException raise:NSInternalInconsistencyException format:@"-[UICloudSharingController viewDidLoad]: this system has no iCloud sharing interface to show"];
}

@end
