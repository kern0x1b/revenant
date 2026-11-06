#include "../revenant_impl.h"
#import <UIKit/UIKit.h>

NSString *const BACKPORT_IMPL(UIDocumentBrowserErrorDomain) = @"UIDocumentBrowserErrorDomain";

@interface UIDocumentBrowserAction (RevenantHandler)
- (void (^)(NSArray<NSURL *> *))revenant_handler;
@end

@implementation UIDocumentBrowserAction {
    NSString *_identifier;
    NSString *_localizedTitle;
    UIDocumentBrowserActionAvailability _availability;
    void (^_handler)(NSArray<NSURL *> *);
    UIImage *_image;
    NSArray<NSString *> *_supportedContentTypes;
}

- (instancetype)initWithIdentifier:(NSString *)identifier localizedTitle:(NSString *)localizedTitle availability:(UIDocumentBrowserActionAvailability)availability handler:(void (^)(NSArray<NSURL *> *))handler
{
    if ((self = [super init])) {
        _identifier = [identifier copy];
        _localizedTitle = [localizedTitle copy];
        _availability = availability;
        _handler = [handler copy];
        _supportedContentTypes = @[];
    }
    return self;
}

- (NSString *)identifier
{
    return _identifier;
}

- (NSString *)localizedTitle
{
    return _localizedTitle;
}

- (UIDocumentBrowserActionAvailability)availability
{
    return _availability;
}

- (UIImage *)image
{
    return _image;
}

- (void)setImage:(UIImage *)image
{
    _image = image;
}

- (NSArray<NSString *> *)supportedContentTypes
{
    return _supportedContentTypes;
}

- (void)setSupportedContentTypes:(NSArray<NSString *> *)supportedContentTypes
{
    _supportedContentTypes = [supportedContentTypes copy] ?: @[];
}

- (void (^)(NSArray<NSURL *> *))revenant_handler
{
    return _handler;
}

@end
