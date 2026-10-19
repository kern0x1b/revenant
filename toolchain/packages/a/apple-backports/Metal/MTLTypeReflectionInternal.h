#import "RevenantMetal.h"

NS_ASSUME_NONNULL_BEGIN

extern id _Nullable RevenantTypedNode(NSDictionary *_Nullable node, Class wanted);

extern MTLDataType RevenantDataTypeFromScalar(NSString *_Nullable scalar);

extern MTLArgumentAccess RevenantAccessFromWord(NSString *_Nullable word);

@interface MTLType (RevenantTypeTreeStorage)

- (instancetype)initWithNode:(NSDictionary *)node;

@property (nonatomic, readonly, strong, nullable) NSDictionary *revenantNode;
@property (nonatomic, readonly, strong, nullable) MTLType *revenantElement;
@property (nonatomic, readonly, strong) NSMutableArray<MTLStructMember *> *revenantMemberList;
@property (nonatomic, readonly, copy) NSString *revenantKind;
- (MTLDataType)revenantDataType;
- (NSUInteger)revenantSize;
- (NSUInteger)revenantAlignment;

@end

@interface MTLStructMember (RevenantTypeTreeStorage)
- (void)revenantSetName:(NSString *)name offset:(NSUInteger)offset node:(nullable NSDictionary *)node;
@property (nonatomic, readonly, copy) NSString *revenantMemberName;
@property (nonatomic, readonly) NSUInteger revenantMemberOffset;
@property (nonatomic, readonly, strong, nullable) NSDictionary *revenantMemberNode;
- (MTLDataType)revenantDataType;
- (MTLDataType)dataType;
- (NSUInteger)offset;
- (MTLStructType *_Nullable)revenantStructType;
- (MTLArrayType *_Nullable)revenantArrayType;
- (MTLTextureReferenceType *_Nullable)revenantTextureReferenceType;
- (MTLPointerType *_Nullable)revenantPointerType;
- (NSUInteger)argumentIndex;
@end

@interface RevenantMetalFunction (RevenantArgumentNode)
@property (nonatomic, readonly, strong, nullable) NSDictionary *revenantArgumentNode;
@end

@interface MTLArgument (RevenantTypeTreeStorage)
- (instancetype)initWithNode:(NSDictionary *)node;
- (NSUInteger)revenantArgumentIndex;
@end

@interface RevenantMetalTypeTree : NSObject
+ (instancetype)treeWithContentsOfFile:(NSString *)path;
- (NSArray<NSDictionary *> *)functions;
- (NSDictionary *_Nullable)functionNamed:(NSString *)name;
- (NSArray<NSDictionary *> *)argumentsOfFunction:(NSDictionary *)function;
@end

NS_ASSUME_NONNULL_END
