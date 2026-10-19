// MTLTypeReflectionInternal.h — what the type tree's two objects share, and what neither installs.
//
// The reader is split because an object carries the API of ONE release, decided by the cache ladder:
// MTLType, MTLPointerType and MTLTextureReferenceType are exported from 11.0, and MTLArgument,
// MTLStructMember, MTLStructType and MTLArrayType from 8.0. release-split measured it on the object
// itself: "1 file(s) mix more than one release's symbols".
//
// So there are two objects and they must agree, and this is where they agree. It is NOT installed -
// it is a private header of the package, included by both objects and by nothing else, and the
// neighbours' private headers are the same: a header whose whole content is used by one .m and its
// siblings is not something an application should be able to import.
//
// THREE things live here, and each exists because a cross-object reference needs a name for it:
//
//   1. The two helpers, declared EXTERNAL rather than static, because a static function cannot cross a
//      translation unit and the 8.0 object and the 11.0 object both need them. They are the port's own
//      names - Charon- prefixed - and they are hidden by the library's -fvisibility=hidden, so
//      exporting them costs an application nothing.
//   2. The initialiser, which MTLType owns and the other object's subclasses are BUILT BY. Every
//      subclass in the other object is created through it, so it cannot be static either.
//   3. The accessors for MTLType's storage. The storage is a class extension's ivars, and a class
//      extension's ivars belong to the translation unit that declares them - a subclass in ANOTHER
//      object cannot read them, whatever @protected says. So the object that implements MTLType
//      publishes accessors, and the other object asks through those.
//
// Nothing here invents a value: the storage is MTLType's own, the helpers are the two that were
// already there, and the initialiser is the one the 11.0 object defines.

#import "CharonMetal.h"

NS_ASSUME_NONNULL_BEGIN

// The node MTLType is built from, and the element and member lists it keeps. @return is `id` on
// purpose: each of the four typed accessors returns a DIFFERENT subclass, and a helper typed as the
// base is what the gate's -Werror=incompatible-pointer-types caught.
extern id _Nullable CharonTypedNode(NSDictionary *_Nullable node, Class wanted);

// The data type the AIR named, and MTLDataTypeNone where it named none.
extern MTLDataType CharonDataTypeFromScalar(NSString *_Nullable scalar);

// The three access the header's own enumerators have, and the same rule in both objects: a key this
// build does not know is the enumeration's zero, never read-write.
extern MTLArgumentAccess CharonAccessFromWord(NSString *_Nullable word);

@interface MTLType (CharonTypeTreeStorage)

// MTLType's own initialiser, implemented in the object that implements MTLType. Every subclass in
// EITHER object is built through it.
- (instancetype)initWithNode:(NSDictionary *)node;

// The node, the element and the member list, read through accessors rather than through the class
// extension's ivars - which is the whole reason this header exists.
@property (nonatomic, readonly, strong, nullable) NSDictionary *charonNode;
@property (nonatomic, readonly, strong, nullable) MTLType *charonElement;
@property (nonatomic, readonly, strong) NSMutableArray<MTLStructMember *> *charonMemberList;
@property (nonatomic, readonly, copy) NSString *charonKind;
- (MTLDataType)charonDataType;
- (NSUInteger)charonSize;
- (NSUInteger)charonAlignment;

@end

// MTLStructMember's storage and its accessors: implemented in MTLTypeReflection8.m, beside the ivars.
// An extension's ivars are defined by the @implementation that sees them, so they cannot be declared in
// one object and used from another: that is a link error (gate-613-3), not a compile one.
@interface MTLStructMember (CharonTypeTreeStorage)
- (void)charonSetName:(NSString *)name offset:(NSUInteger)offset node:(nullable NSDictionary *)node;
@property (nonatomic, readonly, copy) NSString *charonMemberName;
@property (nonatomic, readonly) NSUInteger charonMemberOffset;
@property (nonatomic, readonly, strong, nullable) NSDictionary *charonMemberNode;
- (MTLDataType)charonDataType;
- (MTLDataType)dataType;
- (NSUInteger)offset;
- (MTLStructType *_Nullable)charonStructType;
- (MTLArrayType *_Nullable)charonArrayType;
- (MTLTextureReferenceType *_Nullable)charonTextureReferenceType;
- (MTLPointerType *_Nullable)charonPointerType;
- (NSUInteger)argumentIndex;
@end

// MTLArgument's node, and the typed accessors over it, implemented in the 8.0 object.
// The plist node a function was built from, which is the argument list its attributes come from. It
// is declared here because the attribute helper lives in another translation unit and reads it, and
// a declaration in the file that IMPLEMENTS the accessor is not visible to a function elsewhere.
@interface CharonMetalFunction (CharonArgumentNode)
@property (nonatomic, readonly, strong, nullable) NSDictionary *charonArgumentNode;
@end

@interface MTLArgument (CharonTypeTreeStorage)
- (instancetype)initWithNode:(NSDictionary *)node;
- (NSUInteger)charonArgumentIndex;
@end

// The tree: the property list, read once. It belongs to the 8.0 object with the argument it hands out.
@interface CharonMetalTypeTree : NSObject
+ (instancetype)treeWithContentsOfFile:(NSString *)path;
- (NSArray<NSDictionary *> *)functions;
- (NSDictionary *_Nullable)functionNamed:(NSString *)name;
- (NSArray<NSDictionary *> *)argumentsOfFunction:(NSDictionary *)function;
@end

NS_ASSUME_NONNULL_END
