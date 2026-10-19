#import <UIKit/UIKit.h>

@implementation UIEventAttribution {
@private
    uint8_t _sourceIdentifier;
    NSURL *_destinationURL;
    NSURL *_reportEndpoint;
    NSString *_sourceDescription;
    NSString *_purchaser;
}

- (instancetype)initWithSourceIdentifier:(uint8_t)sourceIdentifier
                         destinationURL:(NSURL *)destinationURL
                     sourceDescription:(NSString *)sourceDescription
                              purchaser:(NSString *)purchaser
{
    if ((self = [super init])) {
        _sourceIdentifier = sourceIdentifier;
        _destinationURL = [destinationURL copy];
        _sourceDescription = [sourceDescription copy];
        _purchaser = [purchaser copy];
        _reportEndpoint = nil;
    }
    return self;
}

- (instancetype)init
{
    return [super init];
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (uint8_t)sourceIdentifier { return _sourceIdentifier; }
- (NSURL *)destinationURL { return _destinationURL; }
- (NSURL *)reportEndpoint { return _reportEndpoint; }
- (NSString *)sourceDescription { return _sourceDescription; }
- (NSString *)purchaser { return _purchaser; }

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

static BOOL revenant_event_objects_equal(id ours, id theirs)
{
    return ours == theirs || [ours isEqual:theirs];
}

static BOOL revenant_event_strings_equal(NSString *ours, NSString *theirs)
{
    return ours == theirs || [ours isEqualToString:theirs];
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[UIEventAttribution class]])
        return NO;
    UIEventAttribution *that = other;
    return _sourceIdentifier == that->_sourceIdentifier
        && revenant_event_objects_equal(_destinationURL, that->_destinationURL)
        && revenant_event_objects_equal(_reportEndpoint, that->_reportEndpoint)
        && revenant_event_strings_equal(_sourceDescription, that->_sourceDescription)
        && revenant_event_strings_equal(_purchaser, that->_purchaser);
}

- (NSUInteger)hash
{
    return (NSUInteger)_sourceIdentifier ^ [_destinationURL hash] ^ [_sourceDescription hash] ^ [_purchaser hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<UIEventAttribution: %p; sourceIdentifier = %u; destinationURL = %@; sourceDescription = %@; purchaser = %@>",
                                      self, (unsigned)_sourceIdentifier, _destinationURL, _sourceDescription, _purchaser];
}

@end

@implementation UIEventAttributionView

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.opaque = YES;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        self.opaque = YES;
        self.userInteractionEnabled = NO;
    }
    return self;
}

@end
