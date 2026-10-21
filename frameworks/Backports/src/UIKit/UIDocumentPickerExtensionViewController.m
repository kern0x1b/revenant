#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@interface UIDocumentPickerExtensionViewController (RevenantHost)
- (void)revenant_setDocumentPickerMode:(UIDocumentPickerMode)mode originalURL:(NSURL *)originalURL validTypes:(NSArray<NSString *> *)validTypes;
@end

@implementation UIDocumentPickerExtensionViewController {
    UIDocumentPickerMode _documentPickerMode;
    NSURL *_originalURL;
    NSArray<NSString *> *_validTypes;
}

- (void)revenant_setDocumentPickerMode:(UIDocumentPickerMode)mode originalURL:(NSURL *)originalURL validTypes:(NSArray<NSString *> *)validTypes
{
    _documentPickerMode = mode;
    _originalURL = [originalURL copy];
    _validTypes = [validTypes copy];
}

- (void)prepareForPresentationInMode:(UIDocumentPickerMode)mode
{
}

- (UIDocumentPickerMode)documentPickerMode
{
    return _documentPickerMode;
}

- (NSURL *)originalURL
{
    return _originalURL;
}

- (NSArray<NSString *> *)validTypes
{
    return _validTypes;
}

- (NSString *)providerIdentifier
{
    return [NSBundle mainBundle].bundleIdentifier ?: @"";
}

@end
