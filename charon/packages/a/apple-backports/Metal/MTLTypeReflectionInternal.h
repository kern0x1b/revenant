#import "CharonMetal.h"

NS_ASSUME_NONNULL_BEGIN

extern id _Nullable CharonTypedNode(NSDictionary *_Nullable node, Class wanted);

extern MTLDataType CharonDataTypeFromScalar(NSString *_Nullable scalar);

extern MTLArgumentAccess CharonAccessFromWord(NSString *_Nullable word);

@interface MTLType (CharonTypeTreeStorage)

- (instancetype)initWithNode:(NSDictionary *)node;

@property (nonatomic, readonly, strong, nullable) NSDictionary *charonNode;
@property (nonatomic, readonly, strong, nullable) MTLType *charonElement;
@property (nonatomic, readonly, strong) NSMutableArray<MTLStructMember *> *charonMemberList;
@property (nonatomic, readonly, copy) NSString *charonKind;
- (MTLDataType)charonDataType;
- (NSUInteger)charonSize;
- (NSUInteger)charonAlignment;

@end

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

@interface CharonMetalFunction (CharonArgumentNode)
@property (nonatomic, readonly, strong, nullable) NSDictionary *charonArgumentNode;
@end

@interface MTLArgument (CharonTypeTreeStorage)
- (instancetype)initWithNode:(NSDictionary *)node;
- (NSUInteger)charonArgumentIndex;
@end

@interface CharonMetalTypeTree : NSObject
+ (instancetype)treeWithContentsOfFile:(NSString *)path;
- (NSArray<NSDictionary *> *)functions;
- (NSDictionary *_Nullable)functionNamed:(NSString *)name;
- (NSArray<NSDictionary *> *)argumentsOfFunction:(NSDictionary *)function;
@end

NS_ASSUME_NONNULL_END
