#import "CharonUserNotifications.h"

@interface UNNotificationContent ()
- (instancetype)initCharonWithContent:(UNNotificationContent *)content;
@end

@implementation UNNotificationContent {
@protected
    NSArray *_attachments;
    NSNumber *_badge;
    NSString *_body;
    NSString *_categoryIdentifier;
    NSString *_launchImageName;
    UNNotificationSound *_sound;
    NSString *_subtitle;
    NSString *_threadIdentifier;
    NSString *_title;
    NSDictionary *_userInfo;
    NSString *_summaryArgument;
    NSUInteger _summaryArgumentCount;
    NSString *_targetContentIdentifier;
    UNNotificationInterruptionLevel _interruptionLevel;
    double _relevanceScore;
    NSString *_filterCriteria;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _attachments = @[];
        _categoryIdentifier = @"";
        _launchImageName = @"";
        _threadIdentifier = @"";
        _userInfo = @{};
        _summaryArgument = @"";
        _interruptionLevel = UNNotificationInterruptionLevelActive;
    }
    return self;
}

- (instancetype)initCharonWithContent:(UNNotificationContent *)content
{
    if ((self = [super init])) {
        _attachments = [content.attachments copy];
        _badge = [content.badge copy];
        _body = [content.body copy];
        _categoryIdentifier = [content.categoryIdentifier copy];
        _launchImageName = [content.launchImageName copy];
        _sound = content.sound;
        _subtitle = [content.subtitle copy];
        _threadIdentifier = [content.threadIdentifier copy];
        _title = [content.title copy];
        _userInfo = [content.userInfo copy];
        _summaryArgument = [content.summaryArgument copy];
        _summaryArgumentCount = content.summaryArgumentCount;
        _targetContentIdentifier = [content.targetContentIdentifier copy];
        _interruptionLevel = content.interruptionLevel;
        _relevanceScore = content.relevanceScore;
        _filterCriteria = [content.filterCriteria copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [self init])) {
        NSSet *plist = [NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSString class], [NSNumber class],
                                             [NSDate class], [NSData class], nil];
        _attachments = [coder decodeObjectOfClasses:[NSSet setWithObject:[NSArray class]] forKey:@"attachments"] ?: @[];
        _badge = [coder decodeObjectOfClass:[NSNumber class] forKey:@"badge"];
        _body = [coder decodeObjectOfClass:[NSString class] forKey:@"body"];
        _categoryIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"categoryIdentifier"] ?: @"";
        _launchImageName = [coder decodeObjectOfClass:[NSString class] forKey:@"launchImageName"] ?: @"";
        _sound = [coder decodeObjectOfClass:[UNNotificationSound class] forKey:@"sound"];
        _subtitle = [coder decodeObjectOfClass:[NSString class] forKey:@"subtitle"];
        _threadIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"threadIdentifier"] ?: @"";
        _title = [coder decodeObjectOfClass:[NSString class] forKey:@"title"];
        _userInfo = [coder decodeObjectOfClasses:plist forKey:@"userInfo"];
        _summaryArgument = [coder decodeObjectOfClass:[NSString class] forKey:@"summaryArgument"];
        _summaryArgumentCount = (NSUInteger)[coder decodeInt64ForKey:@"summaryArgumentCount"];
        _targetContentIdentifier = [coder decodeObjectOfClass:[NSString class] forKey:@"targetContentIdentifier"];
        _interruptionLevel = (UNNotificationInterruptionLevel)[coder decodeIntegerForKey:@"interruptionLevel"];
        _relevanceScore = [coder decodeDoubleForKey:@"relevanceScore"];
        _filterCriteria = [coder decodeObjectOfClass:[NSString class] forKey:@"filterCriteria"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_attachments forKey:@"attachments"];
    [coder encodeObject:_badge forKey:@"badge"];
    [coder encodeObject:_body forKey:@"body"];
    [coder encodeObject:_categoryIdentifier forKey:@"categoryIdentifier"];
    [coder encodeObject:_launchImageName forKey:@"launchImageName"];
    [coder encodeObject:_sound forKey:@"sound"];
    [coder encodeObject:_subtitle forKey:@"subtitle"];
    [coder encodeObject:_threadIdentifier forKey:@"threadIdentifier"];
    [coder encodeObject:_title forKey:@"title"];
    [coder encodeObject:_userInfo forKey:@"userInfo"];
    [coder encodeObject:_summaryArgument forKey:@"summaryArgument"];
    [coder encodeInt64:(int64_t)_summaryArgumentCount forKey:@"summaryArgumentCount"];
    [coder encodeObject:_targetContentIdentifier forKey:@"targetContentIdentifier"];
    [coder encodeInteger:(NSInteger)_interruptionLevel forKey:@"interruptionLevel"];
    [coder encodeDouble:_relevanceScore forKey:@"relevanceScore"];
    [coder encodeObject:_filterCriteria forKey:@"filterCriteria"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[UNMutableNotificationContent allocWithZone:zone] initCharonWithContent:self];
}

- (NSArray *)attachments
{
    return _attachments;
}

- (NSNumber *)badge
{
    return _badge;
}

- (NSString *)body
{
    return _body;
}

- (NSString *)categoryIdentifier
{
    return _categoryIdentifier;
}

- (NSString *)launchImageName
{
    return _launchImageName;
}

- (UNNotificationSound *)sound
{
    return _sound;
}

- (NSString *)subtitle
{
    return _subtitle;
}

- (NSString *)threadIdentifier
{
    return _threadIdentifier;
}

- (NSString *)title
{
    return _title;
}

- (NSDictionary *)userInfo
{
    return _userInfo;
}

- (NSString *)summaryArgument
{
    return _summaryArgument;
}

- (NSUInteger)summaryArgumentCount
{
    return _summaryArgumentCount;
}

- (NSString *)targetContentIdentifier
{
    return _targetContentIdentifier;
}

- (UNNotificationInterruptionLevel)interruptionLevel
{
    return _interruptionLevel;
}

- (double)relevanceScore
{
    return _relevanceScore;
}

- (NSString *)filterCriteria
{
    return _filterCriteria;
}

static BOOL charon_same(id a, id b)
{
    return a == b || [a isEqual:b];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UNNotificationContent class]])
        return NO;
    UNNotificationContent *other = object;
    return charon_same(_userInfo, other.userInfo) && charon_same(_title, other.title) && charon_same(_body, other.body)
        && charon_same(_subtitle, other.subtitle) && charon_same(_threadIdentifier, other.threadIdentifier)
        && charon_same(_sound, other.sound) && charon_same(_launchImageName, other.launchImageName)
        && charon_same(_categoryIdentifier, other.categoryIdentifier) && charon_same(_badge, other.badge)
        && charon_same(_attachments, other.attachments) && charon_same(_summaryArgument, other.summaryArgument)
        && _summaryArgumentCount == other.summaryArgumentCount && charon_same(_targetContentIdentifier, other.targetContentIdentifier)
        && _interruptionLevel == other.interruptionLevel && _relevanceScore == other.relevanceScore
        && charon_same(_filterCriteria, other.filterCriteria);
}

- (NSUInteger)hash
{
    return _title.hash ^ _body.hash ^ _subtitle.hash ^ _categoryIdentifier.hash ^ _threadIdentifier.hash ^ _badge.hash
         ^ _userInfo.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; title: %@, subtitle: %@, body: %@, categoryIdentifier: %@, "
                                      @"launchImageName: %@, threadIdentifier: %@, attachments: %@, badge: %@, sound: %@>",
                                      [self class], self, _title, _subtitle, _body, _categoryIdentifier, _launchImageName,
                                      _threadIdentifier, _attachments, _badge, _sound];
}

@end

@implementation UNMutableNotificationContent

- (id)copyWithZone:(NSZone *)zone
{
    return [[UNNotificationContent allocWithZone:zone] initCharonWithContent:self];
}

- (void)setAttachments:(NSArray *)attachments
{
    _attachments = [attachments copy] ?: @[];
}

- (void)setBadge:(NSNumber *)badge
{
    _badge = [badge copy];
}

- (void)setBody:(NSString *)body
{
    _body = [body copy];
}

- (void)setCategoryIdentifier:(NSString *)categoryIdentifier
{
    _categoryIdentifier = [categoryIdentifier copy] ?: @"";
}

- (void)setLaunchImageName:(NSString *)launchImageName
{
    _launchImageName = [launchImageName copy] ?: @"";
}

- (void)setSound:(UNNotificationSound *)sound
{
    _sound = [sound copy];
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitle = [subtitle copy];
}

- (void)setThreadIdentifier:(NSString *)threadIdentifier
{
    _threadIdentifier = [threadIdentifier copy] ?: @"";
}

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
}

- (void)setUserInfo:(NSDictionary *)userInfo
{
    _userInfo = [userInfo copy];
}

- (void)setSummaryArgument:(NSString *)summaryArgument
{
    _summaryArgument = [summaryArgument copy];
}

- (void)setSummaryArgumentCount:(NSUInteger)summaryArgumentCount
{
    _summaryArgumentCount = summaryArgumentCount;
}

- (void)setTargetContentIdentifier:(NSString *)targetContentIdentifier
{
    _targetContentIdentifier = [targetContentIdentifier copy];
}

- (void)setInterruptionLevel:(UNNotificationInterruptionLevel)interruptionLevel
{
    _interruptionLevel = interruptionLevel;
}

// The relevance is kept within [0, 1]: a value above one reads as one, and one below zero as zero.
- (void)setRelevanceScore:(double)relevanceScore
{
    _relevanceScore = MIN(1, MAX(0, relevanceScore));
}

- (void)setFilterCriteria:(NSString *)filterCriteria
{
    _filterCriteria = [filterCriteria copy];
}

@end

@implementation UNNotificationSound {
@private
    NSString *_name;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (instancetype)defaultSound
{
    return [[self alloc] initCharonWithName:nil];
}

+ (instancetype)soundNamed:(NSString *)name
{
    return [[self alloc] initCharonWithName:name];
}

- (instancetype)initCharonWithName:(NSString *)name
{
    if ((self = [super init]))
        _name = [name copy];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initCharonWithName:[coder decodeObjectOfClass:[NSString class] forKey:@"toneFileName"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name forKey:@"toneFileName"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)charon_fileName
{
    return _name;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    return [object isKindOfClass:[UNNotificationSound class]] && charon_same(_name, [object charon_fileName]);
}

- (NSUInteger)hash
{
    return _name.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>", [self class], self];
}

@end
