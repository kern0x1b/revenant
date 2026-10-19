#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>
#import <UIKit/UIKit.h>

@interface PKPass (CharonPaymentPass9)
@property (nonatomic, copy, readonly) NSString *deviceName;
@end

@implementation PKPass (CharonPaymentPass9)

- (NSString *)deviceName
{
    return nil;
}

@end

@implementation PKAddPaymentPassRequestConfiguration

@dynamic cardDetails;
@dynamic productIdentifiers;
@dynamic requiresFelicaSecureElement;
@dynamic style;

- (nullable instancetype)initWithEncryptionScheme:(PKEncryptionScheme)encryptionScheme
{
    self = [super init];
    if (self) {
        _encryptionScheme = [encryptionScheme copy];
    }
    return self;
}

@end

@implementation PKAddPaymentPassRequest

- (instancetype)init
{
    return [super init];
}

@end

@implementation PKAddPaymentPassViewController

+ (BOOL)canAddPaymentPass
{
    return NO;
}

- (nullable instancetype)initWithRequestConfiguration:(PKAddPaymentPassRequestConfiguration *)configuration
                                             delegate:(nullable id<PKAddPaymentPassViewControllerDelegate>)delegate
{
    (void)configuration;
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    (void)nibNameOrNil;
    (void)nibBundleOrNil;
    return [self initWithRequestConfiguration:[[PKAddPaymentPassRequestConfiguration alloc] init]
                                    delegate:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    (void)coder;
    return [self initWithRequestConfiguration:[[PKAddPaymentPassRequestConfiguration alloc] init]
                                    delegate:nil];
}

@end
