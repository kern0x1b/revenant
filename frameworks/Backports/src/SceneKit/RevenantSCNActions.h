#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, RevenantSCNActionKind) {
    RevenantSCNActionKindMoveBy,
    RevenantSCNActionKindMoveTo,
    RevenantSCNActionKindRotateBy,
    RevenantSCNActionKindRotateTo,
    RevenantSCNActionKindRotateByAngle,
    RevenantSCNActionKindRotateToAxisAngle,
    RevenantSCNActionKindScaleBy,
    RevenantSCNActionKindScaleTo,
    RevenantSCNActionKindFadeOpacityBy,
    RevenantSCNActionKindFadeOpacityTo,
    RevenantSCNActionKindHide,
    RevenantSCNActionKindUnhide,
    RevenantSCNActionKindWait,
    RevenantSCNActionKindRemoveFromParent,
    RevenantSCNActionKindRunBlock,
    RevenantSCNActionKindCustom,
    RevenantSCNActionKindSequence,
    RevenantSCNActionKindGroup,
    RevenantSCNActionKindRepeat,
    RevenantSCNActionKindFadeIn,
    RevenantSCNActionKindFadeOut,
    RevenantSCNActionKindWaitRandom,
};

typedef void (^RevenantSCNActionBlock)(SCNNode *node);
typedef void (^RevenantSCNActionCustomBlock)(SCNNode *node, CGFloat elapsedTime);

@interface SCNAction (RevenantSCNActions)
- (RevenantSCNActionKind)revenantKind;
- (SCNVector3)revenantVector;
- (SCNVector4)revenantAxisAngle;
- (CGFloat)revenantScalar;
- (BOOL)revenantShortestUnitArc;
- (nullable NSArray<SCNAction *> *)revenantChildren;
- (NSUInteger)revenantRepeatCount;
- (BOOL)revenantRepeatsForever;
- (nullable RevenantSCNActionBlock)revenantBlock;
- (nullable RevenantSCNActionCustomBlock)revenantCustomBlock;
- (nullable dispatch_queue_t)revenantQueue;
- (BOOL)revenantIsComposite;
- (BOOL)revenantContainsRandomWait;
@end

@interface RevenantSCNActionRun : NSObject
@property (nonatomic, readonly) SCNAction *action;
@property (nonatomic, readonly, nullable) NSString *key;
@property (nonatomic, readonly, nullable) void (^completion)(void);
@property (nonatomic) CFTimeInterval lastTime;
- (instancetype)initWithAction:(SCNAction *)action key:(nullable NSString *)key completion:(nullable void (^)(void))completion time:(CFTimeInterval)time;
- (BOOL)advanceBy:(NSTimeInterval)dt onNode:(SCNNode *)node leftover:(NSTimeInterval *)leftover;
@end

NS_ASSUME_NONNULL_END
