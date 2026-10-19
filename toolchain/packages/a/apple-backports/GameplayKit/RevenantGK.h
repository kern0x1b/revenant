#import <GameplayKit/GameplayKit.h>

static inline uint32_t RevenantGKBounded(uint32_t draw, NSUInteger upperBound)
{
    if (upperBound < 2) {
        return 0;
    }
    if ((upperBound & (upperBound - 1)) == 0) {
        uint32_t bits = 0;
        for (NSUInteger size = upperBound; size > 1; size >>= 1) {
            bits++;
        }
        return bits >= 32 ? draw : draw >> (32 - bits);
    }
    uint32_t bound = (uint32_t)upperBound;
    return draw % bound;
}

static inline float RevenantGKUniform(uint32_t draw)
{
    return (float)(draw >> 8) / 16777216.0f;
}

typedef struct {
    uint8_t box[256];
    uint32_t i;
    uint32_t j;
} RevenantGKRC4;

static inline void RevenantGKRC4Stir(RevenantGKRC4 *state, const uint8_t *key, size_t length)
{
    for (uint32_t index = 0; index < 256; index++) {
        state->box[index] = (uint8_t)index;
    }
    uint32_t j = 0;
    size_t taken = 0;
    for (uint32_t index = 0; index < 256; index++) {
        j = (j + state->box[index] + key[taken]) & 0xff;
        if (++taken == length) {
            taken = 0;
        }
        uint8_t held = state->box[index];
        state->box[index] = state->box[j];
        state->box[j] = held;
    }
    state->i = 0;
    state->j = 0;
}

static inline uint8_t RevenantGKRC4Byte(RevenantGKRC4 *state)
{
    state->i = (state->i + 1) & 0xff;
    state->j = (state->j + state->box[state->i]) & 0xff;
    uint8_t held = state->box[state->i];
    state->box[state->i] = state->box[state->j];
    state->box[state->j] = held;
    return state->box[(state->box[state->i] + state->box[state->j]) & 0xff];
}

static inline uint32_t RevenantGKRC4Draw(RevenantGKRC4 *state)
{
    uint32_t draw = 0;
    for (int byte = 0; byte < 4; byte++) {
        draw = (draw << 8) | RevenantGKRC4Byte(state);
    }
    return draw;
}

@interface GKRandomSource (RevenantGKState)
- (instancetype)revenant_primed;
- (RevenantGKRC4 *)revenant_rc4;
- (void)revenant_stirWithBytes:(const uint8_t *)bytes length:(size_t)length;
- (void)revenant_takeStateOf:(GKRandomSource *)other;
- (void)revenant_dropDraws:(NSUInteger)count;
@end

static NSString *const RevenantGKRC4StateKey = @"RevenantGKRC4State";
static NSString *const RevenantGKRC4IndexKey = @"RevenantGKRC4Index";
static NSString *const RevenantGKRC4JockeyKey = @"RevenantGKRC4Jockey";
static NSString *const RevenantGKLinearSeedKey = @"RevenantGKLinearSeed";
static NSString *const RevenantGKMersenneSeedKey = @"RevenantGKMersenneSeed";
static NSString *const RevenantGKMersenneStateKey = @"RevenantGKMersenneState";
static NSString *const RevenantGKMersenneIndexKey = @"RevenantGKMersenneIndex";

@interface RevenantGKSystemRandom : GKRandomSource
@end

typedef NS_ENUM(NSInteger, RevenantGKGoalKind) {
    RevenantGKGoalSeek = 0,
    RevenantGKGoalFlee,
    RevenantGKGoalAvoidObstacles,
    RevenantGKGoalAvoidAgents,
    RevenantGKGoalSeparate,
    RevenantGKGoalAlign,
    RevenantGKGoalCohere,
    RevenantGKGoalReachTargetSpeed,
    RevenantGKGoalWander,
    RevenantGKGoalIntercept,
    RevenantGKGoalFollowPath,
    RevenantGKGoalStayOnPath
};

@interface GKGoal (RevenantGKGoal)
+ (instancetype)revenant_goalOfKind:(RevenantGKGoalKind)kind;
- (instancetype)initWithRevenantKind:(RevenantGKGoalKind)kind;
- (RevenantGKGoalKind)revenant_kind;
- (GKAgent *)revenant_agent;
- (NSArray<GKObstacle *> *)revenant_obstacles;
- (NSArray<GKAgent *> *)revenant_agents;
- (GKPath *)revenant_path;
- (NSTimeInterval)revenant_maxPredictionTime;
- (float)revenant_value;
- (float)revenant_maxDistance;
- (float)revenant_maxAngle;
- (BOOL)revenant_forward;
@end

static NSString *const RevenantGKObstacleVerticesKey = @"RevenantGKObstacleVertices";

static NSString *const RevenantGKGraphNodesKey = @"RevenantGKGraphNodes";

static NSString *const RevenantGKEntityComponentsKey = @"RevenantGKEntityComponents";

@interface GKComponent (RevenantGKEntity)
- (void)revenant_attachToEntity:(GKEntity *)entity;
@end

@interface GKState (RevenantGKStateMachine)
- (void)revenant_attachToStateMachine:(GKStateMachine *)machine;
@end

@interface NSArray (RevenantGKShuffle)
- (NSArray *)revenant_shuffledArrayWithRandomSource:(id<GKRandom>)source;
@end

@interface GKRandomDistribution (RevenantGKSource)
- (id<GKRandom>)revenant_source;
@end
