#import <ModelIO/ModelIO.h>
#import <objc/runtime.h>
#import "../charon_alias.h"

// A zone of a real capacity, with the allocator that made it, as MDLMeshBuffer9.m's allocator hands
// out. What is in this file and why it is not a class implementation is the measurement below.
//
// MDLMeshBufferZoneDefault is Apple's class from 11.0 on, and the release's own from 9.0 - carried,
// with six methods of its own - while exporting no symbol for it until 11.0. Measured with
// apple.objc.inventory and apple.dyld over the caches this package is built for: 9.0, 9.1, 9.2, 9.3,
// 9.3.5, 9.3.6 (armv7) and 10.0.1, 10.1, 10.2, 10.3, 10.3.4 (armv7s) all carry the class in ModelIO's
// __objc_classlist - superclass NSObject, own methods -initWithCapacity:allocator:, -capacity,
// -allocator, -reserveMemory:allocator:, -cancelMemory: and -cxx_destruct, adopting MDLMeshBufferZone -
// and no image of any of them exports _OBJC_CLASS_$_MDLMeshBufferZoneDefault or its metaclass, while
// _OBJC_CLASS_$_MDLMeshBufferDataAllocator, _OBJC_CLASS_$_MDLMeshBufferData and _OBJC_CLASS_$_MDLMeshBufferMap
// are exported by ModelIO from 9.0 on. 11.0 (arm64) exports the class and its metaclass.
//
// So a band of 9.0 to 10.3.4 that linked the class implementation this file used to hold would have
// two classes of one name in every process, and the runtime keeps the one it registered first, which
// is the release's - the port's would be reachable only through the symbol its own dylib exports, and
// NSClassFromString would answer the other. The name is therefore an ALIAS, which is what
// modules/apple/backports.lua's own check asks for when it reads this reading ("the release carries
// MDLMeshBufferZoneDefault in ModelIO without exporting it: alias it through charon_alias.h"), and
// what NSTextList and NSTextTab already are for the same one (UIFoundation carries NSTextList from 6.0
// and exports it from 9.0).
//
// The members are a CATEGORY on Charon's own name, which ld64 merges into the proxy: a class
// implementation here would be that second class on every band from 9.0 on. A category cannot add an
// instance variable, and neither can the class behind an alias (attach.c lays the proxy out from the
// release's class and takes that write back when the two instance sizes differ), so the zone's own
// two values are an associated object - the shape CarPlay's CPListItem row and
// NSURLSessionStreamTask's task already use.
//
// What each band answers, all three measured above: from 11.0 the release exports the name, the band
// reexports the symbol and links neither this object nor the proxy, and the release's own class
// answers. On 9.0 to 10.3.4 the release's class answers -capacity and -allocator and this category is
// not attached there at all - attach.c adds a category method only where the class does not answer the
// selector - so a zone is Apple's own zone with Apple's own answers, and nothing in this band makes
// one: MDLMeshBuffer9.o is out of those bands too, the release exporting the allocator that would.
// Below 9.0 the release has no ModelIO at all, the proxy IS the class, and the category answers the
// capacity the allocator was asked to make.

// The zone's own state, made when it is first asked for, which is what a zone made by NSObject's -init
// on a release that has no ModelIO reads: no capacity asked for is zero, and no allocator is nil.
@interface CharonMeshBufferZoneState : NSObject
@property (nonatomic, assign) NSUInteger capacity;
@property (nonatomic, strong) id<MDLMeshBufferAllocator> allocator;
@end

@implementation CharonMeshBufferZoneState

@synthesize capacity = _capacity;
@synthesize allocator = _allocator;

@end

// The class the release's name stands for, and nothing else: its superclass is the release's own
// (NSObject, measured at every release that carries the class), which is what CHARON_ALIAS declares it
// with, and the release's name is exported to it.
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

// What the allocator writes into a zone it has just made, so a zone carries the capacity it was asked
// for and the allocator that made it.
- (void)charon_setCapacity:(NSUInteger)capacity allocator:(id<MDLMeshBufferAllocator>)allocator
{
    CharonMeshBufferZoneState *state = [self charon_zoneState];
    state.capacity = capacity;
    state.allocator = allocator;
}

// The class adopts MDLMeshBufferZone - the SDK's own declaration of MDLMeshBufferZoneDefault - and a
// class behind an alias cannot say so: CHARON_ALIAS declares the proxy with a superclass and nothing
// else, and a category's protocol list belongs to the category, not to the class. Measured with
// `otool -o` over a class with a category declaring <P>: baseProtocols 0x0 on the class, count 1 on
// the category. So the proxy is given the conformance here, before the library's loader re-parents it
// and before anything asks. Where the release carries the class the macro's +conformsToProtocol:
// answers the release's own class instead, which is that class's own YES.
+ (void)load
{
    class_addProtocol(self, @protocol(MDLMeshBufferZone));
}

@end