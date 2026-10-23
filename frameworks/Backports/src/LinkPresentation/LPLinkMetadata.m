#import "RevenantLinkPresentation.h"

@implementation LPLinkMetadata {
    NSString *_summary;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (LPLinkMetadata *)revenant_metadataFromHTML:(NSString *)html originalURL:(NSURL *)originalURL finalURL:(NSURL *)finalURL imageURL:(NSURL **)imageURL iconURL:(NSURL **)iconURL
{
    NSDictionary *parsed = revenant_link_parse_html(html);
    NSDictionary *meta = parsed[@"meta"];
    NSURL *base = finalURL ?: originalURL;
    LPLinkMetadata *metadata = [[self alloc] init];
    metadata.originalURL = originalURL;
    metadata.URL = revenant_link_resolve(meta[@"og:url"], base) ?: base;
    metadata.title = revenant_link_first(@[meta[@"og:title"] ?: @"", meta[@"twitter:title"] ?: @"", parsed[@"title"] ?: @""]);
    metadata->_summary = revenant_link_first(@[meta[@"og:description"] ?: @"", meta[@"twitter:description"] ?: @"", meta[@"description"] ?: @""]);
    metadata.remoteVideoURL = revenant_link_resolve(revenant_link_first(@[meta[@"og:video:url"] ?: @"", meta[@"og:video:secure_url"] ?: @"", meta[@"og:video"] ?: @""]), base);
    if (imageURL) {
        *imageURL = revenant_link_resolve(revenant_link_first(@[meta[@"og:image:url"] ?: @"", meta[@"og:image:secure_url"] ?: @"", meta[@"og:image"] ?: @"", meta[@"twitter:image"] ?: @"", meta[@"twitter:image:src"] ?: @""]), base);
    }
    if (iconURL) {
        *iconURL = revenant_link_resolve(parsed[@"icon"], base);
    }
    return metadata;
}

- (id)copyWithZone:(NSZone *)zone
{
    LPLinkMetadata *copy = [[[self class] allocWithZone:zone] init];
    copy.originalURL = self.originalURL;
    copy.URL = self.URL;
    copy.title = self.title;
    copy.iconProvider = self.iconProvider;
    copy.imageProvider = self.imageProvider;
    copy.videoProvider = self.videoProvider;
    copy.remoteVideoURL = self.remoteVideoURL;
    copy->_summary = _summary;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        self.originalURL = [coder decodeObjectOfClass:[NSURL class] forKey:@"originalURL"];
        self.URL = [coder decodeObjectOfClass:[NSURL class] forKey:@"URL"];
        self.title = [coder decodeObjectOfClass:[NSString class] forKey:@"title"];
        self.remoteVideoURL = [coder decodeObjectOfClass:[NSURL class] forKey:@"remoteVideoURL"];
        _summary = [coder decodeObjectOfClass:[NSString class] forKey:@"summary"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.originalURL forKey:@"originalURL"];
    [coder encodeObject:self.URL forKey:@"URL"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.remoteVideoURL forKey:@"remoteVideoURL"];
    [coder encodeObject:_summary forKey:@"summary"];
}

@end
