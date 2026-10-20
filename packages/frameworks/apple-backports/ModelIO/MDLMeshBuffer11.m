#import <ModelIO/ModelIO.h>
#import <objc/runtime.h>
#import "../revenant_alias.h"

@interface RevenantMeshBufferZoneState : NSObject
@property (nonatomic, assign) NSUInteger capacity;
@property (nonatomic, strong) id<MDLMeshBufferAllocator> allocator;
@end

@implementation RevenantMeshBufferZoneState

@synthesize capacity = _capacity;
@synthesize allocator = _allocator;

@end

REVENANT_ALIAS(MDLMeshBufferZoneDefault)

@interface REVENANT_ALIAS_CLASS(MDLMeshBufferZoneDefault) (RevenantZone)
- (void)revenant_setCapacity:(NSUInteger)capacity allocator:(id<MDLMeshBufferAllocator>)allocator;
@end

@implementation REVENANT_ALIAS_CLASS(MDLMeshBufferZoneDefault) (RevenantZone)

static const void *RevenantMeshBufferZoneStateKey = &RevenantMeshBufferZoneStateKey;

- (RevenantMeshBufferZoneState *)revenant_zoneState
{
    RevenantMeshBufferZoneState *state = objc_getAssociatedObject(self, RevenantMeshBufferZoneStateKey);
    if (!state) {
        state = [[RevenantMeshBufferZoneState alloc] init];
        objc_setAssociatedObject(self, RevenantMeshBufferZoneStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

- (NSUInteger)capacity
{
    return [self revenant_zoneState].capacity;
}

- (id<MDLMeshBufferAllocator>)allocator
{
    return [self revenant_zoneState].allocator;
}

- (void)revenant_setCapacity:(NSUInteger)capacity allocator:(id<MDLMeshBufferAllocator>)allocator
{
    RevenantMeshBufferZoneState *state = [self revenant_zoneState];
    state.capacity = capacity;
    state.allocator = allocator;
}

+ (void)load
{
    class_addProtocol(self, @protocol(MDLMeshBufferZone));
}

@end
