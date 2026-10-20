#import "RevenantLists.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

static NSString *const RevenantTraitsKey = @"traitCollection";
static NSString *const RevenantFlagsKey = @"flags";
static NSString *const RevenantCustomKey = @"customStates";

@implementation UIViewConfigurationState {
@private
    UITraitCollection *_traitCollection;
    NSUInteger _flags;
    NSMutableDictionary *_customStates;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithTraitCollection:(UITraitCollection *)traitCollection
{
    if (!traitCollection)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid parameter not satisfying: traitCollection != nil"];
    if ((self = [super init])) {
        _traitCollection = traitCollection;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithTraitCollection:[[UITraitCollection alloc] init]];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    UITraitCollection *traits = [coder decodeObjectOfClass:[UITraitCollection class] forKey:RevenantTraitsKey];
    if ((self = [self initWithTraitCollection:traits ?: [[UITraitCollection alloc] init]])) {
        _flags = (NSUInteger)[coder decodeIntegerForKey:RevenantFlagsKey];
        NSSet *classes = [NSSet setWithObjects:[NSDictionary class], [NSString class], [NSNumber class], [NSArray class], [NSData class], [NSDate class], [NSNull class], nil];
        NSDictionary *custom = [coder decodeObjectOfClasses:classes forKey:RevenantCustomKey];
        if (custom)
            _customStates = [custom mutableCopy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_traitCollection forKey:RevenantTraitsKey];
    [coder encodeInteger:(NSInteger)_flags forKey:RevenantFlagsKey];
    if (_customStates)
        [coder encodeObject:_customStates forKey:RevenantCustomKey];
}

- (id)copyWithZone:(NSZone *)zone
{
    UIViewConfigurationState *copy = [[[self class] allocWithZone:zone] initWithTraitCollection:_traitCollection];
    copy->_flags = _flags;
    if (_customStates)
        copy->_customStates = [_customStates mutableCopy];
    return copy;
}

- (UITraitCollection *)traitCollection
{
    return _traitCollection;
}

- (void)setTraitCollection:(UITraitCollection *)traitCollection
{
    _traitCollection = traitCollection;
}

- (BOOL)revenant_flag:(NSUInteger)bit
{
    return (_flags & bit) != 0;
}

- (void)revenant_setFlag:(NSUInteger)bit value:(BOOL)value
{
    _flags = value ? (_flags | bit) : (_flags & ~bit);
}

- (BOOL)isDisabled
{
    return [self revenant_flag:1];
}

- (void)setDisabled:(BOOL)disabled
{
    [self revenant_setFlag:1 value:disabled];
}

- (BOOL)isHighlighted
{
    return [self revenant_flag:2];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [self revenant_setFlag:2 value:highlighted];
}

- (BOOL)isSelected
{
    return [self revenant_flag:4];
}

- (void)setSelected:(BOOL)selected
{
    [self revenant_setFlag:4 value:selected];
}

- (BOOL)isFocused
{
    return [self revenant_flag:8];
}

- (BOOL)isPinned
{
    return [self revenant_flag:16];
}

- (void)setPinned:(BOOL)pinned
{
    [self revenant_setFlag:16 value:pinned];
}

- (void)setFocused:(BOOL)focused
{
    [self revenant_setFlag:8 value:focused];
}

- (NSUInteger)revenant_flags
{
    return _flags;
}

- (id)customStateForKey:(UIConfigurationStateCustomKey)key
{
    return _customStates[key];
}

- (void)setCustomState:(id)customState forKey:(UIConfigurationStateCustomKey)key
{
    if (!_customStates)
        _customStates = [[NSMutableDictionary alloc] init];
    if (customState)
        _customStates[key] = customState;
    else
        [_customStates removeObjectForKey:key];
}

- (id)objectForKeyedSubscript:(UIConfigurationStateCustomKey)key
{
    return [self customStateForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(UIConfigurationStateCustomKey)key
{
    [self setCustomState:object forKey:key];
}

- (NSDictionary *)revenant_customStates
{
    return _customStates;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UIViewConfigurationState class]])
        return NO;
    UIViewConfigurationState *other = object;
    return [_traitCollection isEqual:other->_traitCollection] && (_flags & 31) == (other->_flags & 31) && (_customStates == other->_customStates || [_customStates isEqual:other->_customStates]);
}

- (NSUInteger)hash
{
    return [_traitCollection hash] ^ ((_flags & 31) * 0x9e3779b1u) ^ [_customStates hash];
}

- (NSString *)revenant_descriptionTail
{
    NSMutableString *text = [NSMutableString string];
    if ([self isDisabled])
        [text appendString:@"; Disabled"];
    if ([self isHighlighted])
        [text appendString:@"; Highlighted"];
    if ([self isSelected])
        [text appendString:@"; Selected"];
    if ([self isFocused])
        [text appendString:@"; Focused"];
    return text;
}

- (NSString *)description
{
    NSMutableString *text = [NSMutableString stringWithFormat:@"<%@: %p; traitCollection = %@", [self class], self, _traitCollection];
    [text appendString:[self revenant_descriptionTail]];
    [text appendString:[self revenant_customTail]];
    [text appendString:@">"];
    return text;
}

- (NSString *)revenant_customTail
{
    return _customStates ? [NSString stringWithFormat:@"; Custom = %@", _customStates] : @"";
}

@end

@implementation UICellConfigurationState {
@private
    UICellConfigurationDragState _dragState;
    UICellConfigurationDropState _dropState;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithTraitCollection:(UITraitCollection *)traitCollection
{
    return [super initWithTraitCollection:traitCollection];
}

- (id)copyWithZone:(NSZone *)zone
{
    UICellConfigurationState *copy = [super copyWithZone:zone];
    copy->_dragState = _dragState;
    copy->_dropState = _dropState;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _dragState = (UICellConfigurationDragState)[coder decodeIntegerForKey:@"cellDragState"];
        _dropState = (UICellConfigurationDropState)[coder decodeIntegerForKey:@"cellDropState"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeInteger:_dragState forKey:@"cellDragState"];
    [coder encodeInteger:_dropState forKey:@"cellDropState"];
}

- (BOOL)isEditing
{
    return [self revenant_flag:16];
}

- (void)setEditing:(BOOL)editing
{
    [self revenant_setFlag:16 value:editing];
}

- (BOOL)isExpanded
{
    return [self revenant_flag:32];
}

- (void)setExpanded:(BOOL)expanded
{
    [self revenant_setFlag:32 value:expanded];
}

- (BOOL)isSwiped
{
    return [self revenant_flag:64];
}

- (void)setSwiped:(BOOL)swiped
{
    [self revenant_setFlag:64 value:swiped];
}

- (BOOL)isReordering
{
    return [self revenant_flag:128];
}

- (void)setReordering:(BOOL)reordering
{
    [self revenant_setFlag:128 value:reordering];
}

- (UICellConfigurationDragState)cellDragState
{
    return _dragState;
}

- (void)setCellDragState:(UICellConfigurationDragState)cellDragState
{
    _dragState = cellDragState;
}

- (UICellConfigurationDropState)cellDropState
{
    return _dropState;
}

- (void)setCellDropState:(UICellConfigurationDropState)cellDropState
{
    _dropState = cellDropState;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[UICellConfigurationState class]] || ![super isEqual:object])
        return NO;
    UICellConfigurationState *other = object;
    return ([self revenant_flags] & 240) == ([other revenant_flags] & 240) && _dragState == other->_dragState && _dropState == other->_dropState;
}

- (NSUInteger)hash
{
    return [super hash] ^ (([self revenant_flags] & 240) << 8) ^ ((NSUInteger)_dragState << 16) ^ ((NSUInteger)_dropState << 20);
}

- (NSString *)revenant_descriptionTail
{
    NSMutableString *text = [NSMutableString stringWithString:[super revenant_descriptionTail]];
    if ([self isEditing])
        [text appendString:@"; Editing"];
    if ([self isExpanded])
        [text appendString:@"; Expanded"];
    if ([self isSwiped])
        [text appendString:@"; Swiped"];
    if ([self isReordering])
        [text appendString:@"; Reordering"];
    static NSString *const drags[] = {nil, @"Lifting", @"Dragging"};
    static NSString *const drops[] = {nil, @"Not Targeted", @"Targeted"};
    if (_dragState > 0 && _dragState < 3)
        [text appendFormat:@"; cellDragState = %@", drags[_dragState]];
    if (_dropState > 0 && _dropState < 3)
        [text appendFormat:@"; cellDropState = %@", drops[_dropState]];
    return text;
}

@end
