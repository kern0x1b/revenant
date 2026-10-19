#import <ModelIO/ModelIO.h>
#import <objc/runtime.h>
#import "../charon_alias.h"

@interface CharonMeshBufferZoneState : NSObject
@property (nonatomic, assign) NSUInteger capacity;
@property (nonatomic, strong) id<MDLMeshBufferAllocator> allocator;
@end

@implementation CharonMeshBufferZoneState

@synthesize capacity = _capacity;
@synthesize allocator = _allocator;

@end

CHARON_ALIAS(MDLMeshBufferZoneDefault)

@interface CHARON_ALIAS_CLASS(MDLMeshBufferZoneDefault) (CharonZone)
- (void)charon_setCapacity:(NSUInteger)capacity allocator:(id<MDLMeshBufferAllocator>)allocator;
@end

@implementation CHARON_ALIAS_CLASS(MDLMeshBufferZoneDefault) (CharonZone)

static const void *CharonMeshBufferZoneStateKey = &CharonMeshBufferZoneStateKey;

- (CharonMeshBufferZoneState *)charon_zoneState
{
    CharonMeshBufferZoneState *state = objc_getAssociatedObject(self, CharonMeshBufferZoneStateKey);
    if (!state) {
        state = [[CharonMeshBufferZoneState alloc] init];
        objc_setAssociatedObject(self, CharonMeshBufferZoneStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

- (NSUInteger)capacity
{
    return [self charon_zoneState].capacity;
}

- (id<MDLMeshBufferAllocator>)allocator
{
    return [self charon_zoneState].allocator;
}

- (void)charon_setCapacity:(NSUInteger)capacity allocator:(id<MDLMeshBufferAllocator>)allocator
{
    CharonMeshBufferZoneState *state = [self charon_zoneState];
    state.capacity = capacity;
    state.allocator = allocator;
}

+ (void)load
{
    class_addProtocol(self, @protocol(MDLMeshBufferZone));
}

@end
