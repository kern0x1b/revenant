#import <CoreSpotlight/CoreSpotlight.h>
#import <CoreSpotlight/CSSearchableItemAttributeSet_General.h>

@interface CSSearchableItemAttributeSet ()

@property (nullable, copy) NSString *displayName;
@property (nullable, copy) NSArray<NSString *> *alternateNames;
@property (nullable, copy) NSString *path;
@property (nullable, strong) NSURL *contentURL;
@property (nullable, strong) NSURL *thumbnailURL;
@property (nullable, copy) NSData *thumbnailData;
@property (nullable, copy) NSString *relatedUniqueIdentifier;
@property (nullable, strong) NSDate *metadataModificationDate;
@property (nullable, copy) NSString *contentType;
@property (nullable, copy) NSArray<NSString *> *contentTypeTree;
@property (nullable, copy) NSArray<NSString *> *keywords;
@property (nullable, copy) NSString *title;
@property (nullable, copy) NSString *version;
@property (nullable, strong) NSNumber *supportsPhoneCall;
@property (nullable, strong) NSNumber *supportsNavigation;
@property (nullable, copy) NSString *containerTitle;
@property (nullable, copy) NSString *containerDisplayName;
@property (nullable, copy) NSString *containerIdentifier;
@property (nullable, strong) NSNumber *containerOrder;

@end

@implementation CSSearchableItemAttributeSet

@synthesize displayName = _displayName;
@synthesize alternateNames = _alternateNames;
@synthesize path = _path;
@synthesize contentURL = _contentURL;
@synthesize thumbnailURL = _thumbnailURL;
@synthesize thumbnailData = _thumbnailData;
@synthesize relatedUniqueIdentifier = _relatedUniqueIdentifier;
@synthesize metadataModificationDate = _metadataModificationDate;
@synthesize contentType = _contentType;
@synthesize contentTypeTree = _contentTypeTree;
@synthesize keywords = _keywords;
@synthesize title = _title;
@synthesize version = _version;
@synthesize supportsPhoneCall = _supportsPhoneCall;
@synthesize supportsNavigation = _supportsNavigation;
@synthesize containerTitle = _containerTitle;
@synthesize containerDisplayName = _containerDisplayName;
@synthesize containerIdentifier = _containerIdentifier;
@synthesize containerOrder = _containerOrder;

- (instancetype)initWithItemContentType:(NSString *)itemContentType
{
    if ((self = [super init]))
        self.contentType = itemContentType;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    CSSearchableItemAttributeSet *copy = [[CSSearchableItemAttributeSet allocWithZone:zone] initWithItemContentType:self.contentType];
    copy.displayName = self.displayName;
    copy.alternateNames = self.alternateNames;
    copy.path = self.path;
    copy.contentURL = self.contentURL;
    copy.thumbnailURL = self.thumbnailURL;
    copy.thumbnailData = self.thumbnailData;
    copy.relatedUniqueIdentifier = self.relatedUniqueIdentifier;
    copy.metadataModificationDate = self.metadataModificationDate;
    copy.contentTypeTree = self.contentTypeTree;
    copy.keywords = self.keywords;
    copy.title = self.title;
    copy.version = self.version;
    copy.supportsPhoneCall = self.supportsPhoneCall;
    copy.supportsNavigation = self.supportsNavigation;
    copy.containerTitle = self.containerTitle;
    copy.containerDisplayName = self.containerDisplayName;
    copy.containerIdentifier = self.containerIdentifier;
    copy.containerOrder = self.containerOrder;
    return copy;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

// Under -requiresSecureCoding (the search bundle decodes this way inside searchd) a container's
// elements must be allowed too, not only the container's own class.
static NSSet *CharonStringArrayClasses(void)
{
    return [NSSet setWithObjects:[NSArray class], [NSString class], nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        self.displayName = [coder decodeObjectOfClass:[NSString class] forKey:@"displayName"];
        self.alternateNames = [coder decodeObjectOfClasses:CharonStringArrayClasses() forKey:@"alternateNames"];
        self.path = [coder decodeObjectOfClass:[NSString class] forKey:@"path"];
        self.contentURL = [coder decodeObjectOfClass:[NSURL class] forKey:@"contentURL"];
        self.thumbnailURL = [coder decodeObjectOfClass:[NSURL class] forKey:@"thumbnailURL"];
        self.thumbnailData = [coder decodeObjectOfClass:[NSData class] forKey:@"thumbnailData"];
        self.relatedUniqueIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"relatedUniqueIdentifier"];
        self.metadataModificationDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"metadataModificationDate"];
        self.contentType = [coder decodeObjectOfClass:[NSString class] forKey:@"contentType"];
        self.contentTypeTree = [coder decodeObjectOfClasses:CharonStringArrayClasses() forKey:@"contentTypeTree"];
        self.keywords = [coder decodeObjectOfClasses:CharonStringArrayClasses() forKey:@"keywords"];
        self.title = [coder decodeObjectOfClass:[NSString class] forKey:@"title"];
        self.version = [coder decodeObjectOfClass:[NSString class] forKey:@"version"];
        self.supportsPhoneCall = [coder decodeObjectOfClass:[NSNumber class] forKey:@"supportsPhoneCall"];
        self.supportsNavigation = [coder decodeObjectOfClass:[NSNumber class] forKey:@"supportsNavigation"];
        self.containerTitle = [coder decodeObjectOfClass:[NSString class] forKey:@"containerTitle"];
        self.containerDisplayName = [coder decodeObjectOfClass:[NSString class] forKey:@"containerDisplayName"];
        self.containerIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"containerIdentifier"];
        self.containerOrder = [coder decodeObjectOfClass:[NSNumber class] forKey:@"containerOrder"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.displayName forKey:@"displayName"];
    [coder encodeObject:self.alternateNames forKey:@"alternateNames"];
    [coder encodeObject:self.path forKey:@"path"];
    [coder encodeObject:self.contentURL forKey:@"contentURL"];
    [coder encodeObject:self.thumbnailURL forKey:@"thumbnailURL"];
    [coder encodeObject:self.thumbnailData forKey:@"thumbnailData"];
    [coder encodeObject:self.relatedUniqueIdentifier forKey:@"relatedUniqueIdentifier"];
    [coder encodeObject:self.metadataModificationDate forKey:@"metadataModificationDate"];
    [coder encodeObject:self.contentType forKey:@"contentType"];
    [coder encodeObject:self.contentTypeTree forKey:@"contentTypeTree"];
    [coder encodeObject:self.keywords forKey:@"keywords"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.version forKey:@"version"];
    [coder encodeObject:self.supportsPhoneCall forKey:@"supportsPhoneCall"];
    [coder encodeObject:self.supportsNavigation forKey:@"supportsNavigation"];
    [coder encodeObject:self.containerTitle forKey:@"containerTitle"];
    [coder encodeObject:self.containerDisplayName forKey:@"containerDisplayName"];
    [coder encodeObject:self.containerIdentifier forKey:@"containerIdentifier"];
    [coder encodeObject:self.containerOrder forKey:@"containerOrder"];
}

@end
