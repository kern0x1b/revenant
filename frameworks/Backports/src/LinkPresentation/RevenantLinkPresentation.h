#if defined(REVENANT_HOST_BUILD)
#define LPLinkMetadata LPLinkMetadataRevenant
#define LPMetadataProvider LPMetadataProviderRevenant
#endif

#import <Foundation/Foundation.h>
#import <LinkPresentation/LinkPresentation.h>

extern NSString *revenant_link_charset(NSData *data);

extern NSString *revenant_link_text(NSData *data, NSString *charset);

extern NSDictionary *revenant_link_parse_html(NSString *html);

extern NSURL *revenant_link_resolve(NSString *reference, NSURL *base);

extern NSString *revenant_link_first(NSArray *values);

@interface LPLinkMetadata (RevenantParsing)

+ (LPLinkMetadata *)revenant_metadataFromHTML:(NSString *)html originalURL:(NSURL *)originalURL finalURL:(NSURL *)finalURL imageURL:(NSURL **)imageURL iconURL:(NSURL **)iconURL;

@end

@interface RevenantLinkFetch : NSObject

- (instancetype)initWithRequest:(NSURLRequest *)request;

- (void)startWithCompletion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion;

- (void)cancel;

@end
