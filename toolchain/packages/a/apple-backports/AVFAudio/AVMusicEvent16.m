#import "CharonAVFAudio.h"

@implementation AVMusicEvent
@end

@implementation AVMusicUserEvent {
    NSData *_charon_data;
}

- (instancetype)initWithData:(NSData *)data
{
    if ((self = [super init])) {
        _charon_data = [data copy] ?: [NSData data];
    }
    return self;
}

- (UInt32)sizeInBytes
{
    return (UInt32)_charon_data.length;
}

@end

@implementation AVParameterEvent {
    UInt32 _charon_parameterID;
    UInt32 _charon_scope;
    UInt32 _charon_element;
    float _charon_value;
}

- (instancetype)initWithParameterID:(UInt32)parameterID scope:(UInt32)scope element:(UInt32)element value:(float)value
{
    if ((self = [super init])) {
        _charon_parameterID = parameterID;
        _charon_scope = scope;
        _charon_element = element;
        _charon_value = value;
    }
    return self;
}

- (void)setParameterID:(UInt32)parameterID
{
    _charon_parameterID = parameterID;
}

- (UInt32)parameterID
{
    return _charon_parameterID;
}

- (void)setScope:(UInt32)scope
{
    _charon_scope = scope;
}

- (UInt32)scope
{
    return _charon_scope;
}

- (void)setElement:(UInt32)element
{
    _charon_element = element;
}

- (UInt32)element
{
    return _charon_element;
}

- (void)setValue:(float)value
{
    _charon_value = value;
}

- (float)value
{
    return _charon_value;
}

@end
