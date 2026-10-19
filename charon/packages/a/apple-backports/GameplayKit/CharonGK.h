#import <GameplayKit/GameplayKit.h>

static inline uint32_t CharonGKBounded(uint32_t draw, NSUInteger upperBound)
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

static inline float CharonGKUniform(uint32_t draw)
{
    return (float)(draw >> 8) / 16777216.0f;
}

typedef struct {
    uint8_t box[256];
    uint32_t i;
    uint32_t j;
} CharonGKRC4;

static inline void CharonGKRC4Stir(CharonGKRC4 *state, const uint8_t *key, size_t length)
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

static inline uint8_t CharonGKRC4Byte(CharonGKRC4 *state)
{
    state->i = (state->i + 1) & 0xff;
    state->j = (state->j + state->box[state->i]) & 0xff;
    uint8_t held = state->box[state->i];
    state->box[state->i] = state->box[state->j];
    state->box[state->j] = held;
    return state->box[(state->box[state->i] + state->box[state->j]) & 0xff];
}

static inline uint32_t CharonGKRC4Draw(CharonGKRC4 *state)
{
    uint32_t draw = 0;
    for (int byte = 0; byte < 4; byte++) {
        draw = (draw << 8) | CharonGKRC4Byte(state);
    }
    return draw;
}

@interface GKRandomSource (CharonGKState)
- (instancetype)charon_primed;
- (CharonGKRC4 *)charon_rc4;
- (void)charon_stirWithBytes:(const uint8_t *)bytes length:(size_t)length;
- (void)charon_takeStateOf:(GKRandomSource *)other;
- (void)charon_dropDraws:(NSUInteger)count;
@end

static NSString *const CharonGKRC4StateKey = @"CharonGKRC4State";
static NSString *const CharonGKRC4IndexKey = @"CharonGKRC4Index";
static NSString *const CharonGKRC4JockeyKey = @"CharonGKRC4Jockey";
static NSString *const CharonGKLinearSeedKey = @"CharonGKLinearSeed";
static NSString *const CharonGKMersenneSeedKey = @"CharonGKMersenneSeed";
static NSString *const CharonGKMersenneStateKey = @"CharonGKMersenneState";
static NSString *const CharonGKMersenneIndexKey = @"CharonGKMersenneIndex";

@interface CharonGKSystemRandom : GKRandomSource
@end

typedef NS_ENUM(NSInteger, CharonGKGoalKind) {
    CharonGKGoalSeek = 0,
    CharonGKGoalFlee,
    CharonGKGoalAvoidObstacles,
    CharonGKGoalAvoidAgents,
    CharonGKGoalSeparate,
    CharonGKGoalAlign,
    CharonGKGoalCohere,
    CharonGKGoalReachTargetSpeed,
    CharonGKGoalWander,
    CharonGKGoalIntercept,
    CharonGKGoalFollowPath,
    CharonGKGoalStayOnPath
};

@interface GKGoal (CharonGKGoal)
+ (instancetype)charon_goalOfKind:(CharonGKGoalKind)kind;
- (instancetype)initWithCharonKind:(CharonGKGoalKind)kind;
- (CharonGKGoalKind)charon_kind;
- (GKAgent *)charon_agent;
- (NSArray<GKObstacle *> *)charon_obstacles;
- (NSArray<GKAgent *> *)charon_agents;
- (GKPath *)charon_path;
- (NSTimeInterval)charon_maxPredictionTime;
- (float)charon_value;
- (float)charon_maxDistance;
- (float)charon_maxAngle;
- (BOOL)charon_forward;
@end

static NSString *const CharonGKObstacleVerticesKey = @"CharonGKObstacleVertices";

static NSString *const CharonGKGraphNodesKey = @"CharonGKGraphNodes";

static NSString *const CharonGKEntityComponentsKey = @"CharonGKEntityComponents";

@interface GKComponent (CharonGKEntity)
- (void)charon_attachToEntity:(GKEntity *)entity;
@end

@interface GKState (CharonGKStateMachine)
- (void)charon_attachToStateMachine:(GKStateMachine *)machine;
@end

@interface NSArray (CharonGKShuffle)
- (NSArray *)charon_shuffledArrayWithRandomSource:(id<GKRandom>)source;
@end

@interface GKRandomDistribution (CharonGKSource)
- (id<GKRandom>)charon_source;
@end
