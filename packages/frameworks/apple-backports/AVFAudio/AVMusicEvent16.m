#import "RevenantAVFAudio.h"

@implementation AVMusicEvent
@end

@implementation AVMusicUserEvent {
    NSData *_revenant_data;
}

- (instancetype)initWithData:(NSData *)data
{
    if ((self = [super init])) {
        _revenant_data = [data copy] ?: [NSData data];
    }
    return self;
}

- (UInt32)sizeInBytes
{
    return (UInt32)_revenant_data.length;
}

@end

@implementation AVParameterEvent {
    UInt32 _revenant_parameterID;
    UInt32 _revenant_scope;
    UInt32 _revenant_element;
    float _revenant_value;
}

- (instancetype)initWithParameterID:(UInt32)parameterID scope:(UInt32)scope element:(UInt32)element value:(float)value
{
    if ((self = [super init])) {
        _revenant_parameterID = parameterID;
        _revenant_scope = scope;
        _revenant_element = element;
        _revenant_value = value;
    }
    return self;
}

- (void)setParameterID:(UInt32)parameterID
{
    _revenant_parameterID = parameterID;
}

- (UInt32)parameterID
{
    return _revenant_parameterID;
}

- (void)setScope:(UInt32)scope
{
    _revenant_scope = scope;
}

- (UInt32)scope
{
    return _revenant_scope;
}

- (void)setElement:(UInt32)element
{
    _revenant_element = element;
}

- (UInt32)element
{
    return _revenant_element;
}

- (void)setValue:(float)value
{
    _revenant_value = value;
}

- (float)value
{
    return _revenant_value;
}

@end
