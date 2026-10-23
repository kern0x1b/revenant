#import "RevenantLinkPresentation.h"

NSString *const LPErrorDomain = @"LPErrorDomain";

@implementation LPMetadataProvider {
    RevenantLinkFetch *_fetch;
    NSURLRequest *_request;
    void (^_completion)(LPLinkMetadata *, NSError *);
    BOOL _cancelled;
}

@synthesize shouldFetchSubresources = _shouldFetchSubresources;
@synthesize timeout = _timeout;

- (instancetype)init
{
    if ((self = [super init])) {
        _timeout = 30;
    }
    return self;
}

- (void)startFetchingMetadataForURL:(NSURL *)URL completionHandler:(void (^)(LPLinkMetadata *, NSError *))completionHandler
{
    [self startFetchingMetadataForRequest:[NSURLRequest requestWithURL:URL] completionHandler:completionHandler];
}

- (void)startFetchingMetadataForRequest:(NSURLRequest *)request completionHandler:(void (^)(LPLinkMetadata *, NSError *))completionHandler
{
    [_fetch cancel];
    _cancelled = NO;
    _completion = [completionHandler copy];
    _request = [request copy];
    _fetch = [[RevenantLinkFetch alloc] initWithRequest:[self timedRequest:request]];
    [_fetch startWithCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self finishPageWithData:data response:response error:error];
    }];
}

- (void)cancel
{
    _cancelled = YES;
    if (_fetch) {
        [_fetch cancel];
    } else {
        [self finishWithMetadata:nil error:nil];
    }
}

- (NSURLRequest *)timedRequest:(NSURLRequest *)base
{
    NSMutableURLRequest *request = [base mutableCopy];
    request.timeoutInterval = _timeout;
    return request;
}

- (NSError *)errorForFetchError:(NSError *)error
{
    NSInteger code = LPErrorMetadataFetchFailed;
    if (_cancelled || ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)) {
        code = LPErrorMetadataFetchCancelled;
    } else if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorTimedOut) {
        code = LPErrorMetadataFetchTimedOut;
    }
    return [NSError errorWithDomain:LPErrorDomain code:code userInfo:error ? @{NSUnderlyingErrorKey: error} : nil];
}

- (void)finishPageWithData:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error
{
    _fetch = nil;
    if (error || _cancelled) {
        [self finishWithMetadata:nil error:[self errorForFetchError:error]];
        return;
    }
    if ([response isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)response statusCode] >= 400) {
        [self finishWithMetadata:nil error:[self errorForFetchError:nil]];
        return;
    }
    NSString *html = revenant_link_text(data, response.textEncodingName ?: revenant_link_charset(data));
    NSURL *imageURL = nil;
    NSURL *iconURL = nil;
    LPLinkMetadata *metadata = [LPLinkMetadata revenant_metadataFromHTML:html originalURL:_request.URL finalURL:response.URL imageURL:&imageURL iconURL:&iconURL];
    if (!_shouldFetchSubresources) {
        [self finishWithMetadata:metadata error:nil];
        return;
    }
    [self fetchResource:imageURL completion:^(NSData *imageData) {
        if (imageData) {
            metadata.imageProvider = [[NSItemProvider alloc] initWithItem:imageData typeIdentifier:@"public.image"];
        }
        [self fetchResource:iconURL completion:^(NSData *iconData) {
            if (iconData) {
                metadata.iconProvider = [[NSItemProvider alloc] initWithItem:iconData typeIdentifier:@"public.image"];
            }
            [self finishWithMetadata:metadata error:nil];
        }];
    }];
}

- (void)fetchResource:(NSURL *)URL completion:(void (^)(NSData *))completion
{
    if (!URL || _cancelled) {
        completion(nil);
        return;
    }
    _fetch = [[RevenantLinkFetch alloc] initWithRequest:[self timedRequest:[NSURLRequest requestWithURL:URL]]];
    [_fetch startWithCompletion:^(NSData *data, NSURLResponse *response, NSError *error) {
        _fetch = nil;
        BOOL failed = error != nil || ([response isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)response statusCode] >= 400);
        completion(failed ? nil : data);
    }];
}

- (void)finishWithMetadata:(LPLinkMetadata *)metadata error:(NSError *)error
{
    void (^completion)(LPLinkMetadata *, NSError *) = _completion;
    _completion = nil;
    _fetch = nil;
    if (_cancelled) {
        metadata = nil;
        error = [NSError errorWithDomain:LPErrorDomain code:LPErrorMetadataFetchCancelled userInfo:nil];
    }
    if (completion) {
        completion(metadata, error);
    }
}

@end
