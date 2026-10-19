// CharonGK.h -- what GameplayKit's classes need from each other. Nothing here is API: every
// declaration is a CharonGK* name or carries a charon_ selector prefix, and the build module leaves
// both out of what it weighs a release against and out of what it exports.

#import <GameplayKit/GameplayKit.h>

// The bounded draw every source in the random family shares: a 32-bit value reduced to
// [0, upperBound). A power of two comes from the high bits of the draw, so every value below the
// bound is equally likely and no draw is ever rejected; anything else is a remainder of the draw.
// This is the host's own rule, measured: for a linear congruential source seeded with 1, whose draws
// are 384748, 3144033421, 3745587449, 1612966641, 3411513126, 1563994289, 1331515492, 4062437312,
// bounds 2 to 20 answer 0 1 0 3 4 0 0 7 8 1 4 0 0 13 0 4 16 17 8 and 1 1 2 2 2 5 5 5 7 11 ...
// while 100, 1000, 65535, 65536 and 65537 answer 48 748 57073 5 57063, and every one of those is
// the remainder of the same draws.
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

// The float every source answers -nextUniform with: the high 24 bits of the draw over 2^24, so the
// value is never 1 and 0 is one draw in 2^24. Measured over forty draws of the host's own linear
// congruential source seeded with 1: 0x0005deec gives 0x38bbc001 where (draw >> 8) / 2^24 gives
// 0x38bbc000, 0xbb61488d gives 0x3f3b6149 where 0x3f3b6148, 0xdf411159 gives 0x3f5f4113 where
// 0x3f5f4111 -- the host's own float arithmetic is up to two units in the last place away from the
// correctly rounded division, and the header says nothing about which way it rounds, so the port
// divides and the test holds the two together to within those two units.
static inline float CharonGKUniform(uint32_t draw)
{
    return (float)(draw >> 8) / 16777216.0f;
}

// The RC4 state every arc4-based source of this framework keeps, and the two steps of RC4 that
// produce it: the key schedule that stirs the box and the keystream that runs it. Written here
// because ARC4, the base class and the system source all run the same published algorithm over it.
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

// A 32-bit draw, most significant byte first, which is the order the host's own arc4 source reads
// its stream in: a source seeded with de ad be ef 00 7f gives 0xd72c65f2, 0xbce95698, 0xf38156fd
// and the fourth draw from this stream is 0xc4f2bbaf.
static inline uint32_t CharonGKRC4Draw(CharonGKRC4 *state)
{
    uint32_t draw = 0;
    for (int byte = 0; byte < 4; byte++) {
        draw = (draw << 8) | CharonGKRC4Byte(state);
    }
    return draw;
}

// What the base class of the random family hands to the sources that build on it. These are not API:
// the build module leaves a charon_ selector out of what a category adds and out of what the registry
// is weighed against, so the ARC4 source and the system source share the base class's box without
// the framework's own surface growing a name for it.
@interface GKRandomSource (CharonGKState)
- (instancetype)charon_primed;
- (CharonGKRC4 *)charon_rc4;
- (void)charon_stirWithBytes:(const uint8_t *)bytes length:(size_t)length;
- (void)charon_takeStateOf:(GKRandomSource *)other;
- (void)charon_dropDraws:(NSUInteger)count;
@end

// The archive keys the state of every random source of this framework is written under. They are
// this port's own: an archive a source writes is read by the same source, which is the contract
// NSSecureCoding gives, and the sequence a decoded source produces is the one it had when it was
// encoded. The seed an arc4 source was stirred with is deliberately not among them, which is what
// its own header says: the state buffers are encoded, the seed is not.
static NSString *const CharonGKRC4StateKey = @"CharonGKRC4State";
static NSString *const CharonGKRC4IndexKey = @"CharonGKRC4Index";
static NSString *const CharonGKRC4JockeyKey = @"CharonGKRC4Jockey";
static NSString *const CharonGKLinearSeedKey = @"CharonGKLinearSeed";
static NSString *const CharonGKMersenneSeedKey = @"CharonGKMersenneSeed";
static NSString *const CharonGKMersenneStateKey = @"CharonGKMersenneState";
static NSString *const CharonGKMersenneIndexKey = @"CharonGKMersenneIndex";

@interface CharonGKSystemRandom : GKRandomSource
@end

// What a goal asks its agent to do, and what a goal carries with it. The goals' own surface is their
// twelve factories, so which one of these a goal is, and the arguments its factory was given, are
// this port's own; GKAgent reads them back when it decides.
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

// The key a polygon obstacle's points go under in its archive: the points as they were given, in
// the order they were given, so that a decoded obstacle is the obstacle that was encoded.
static NSString *const CharonGKObstacleVerticesKey = @"CharonGKObstacleVertices";

// The key a graph and a node write their neighbours' class names under. A graph node is written as
// the class it is and nothing else: the header gives a node no state of its own beyond the position
// its subclass keeps, so an archive that carried more would be carrying this port's layout.
static NSString *const CharonGKGraphNodesKey = @"CharonGKGraphNodes";

// The key an entity's archive names its components under, and under which each component's own
// bytes go: the class's name after a full stop.
static NSString *const CharonGKEntityComponentsKey = @"CharonGKEntityComponents";

// The entity a component belongs to, which the property of the same name is weak and readonly: the
// entity sets it when the component is added and clears it when the component is taken off.
@interface GKComponent (CharonGKEntity)
- (void)charon_attachToEntity:(GKEntity *)entity;
@end

// The state machine a state belongs to, which the property of the same name is weak and readonly:
// the machine sets it when it is built and when it enters the state, and a state outlives nothing.
@interface GKState (CharonGKStateMachine)
- (void)charon_attachToStateMachine:(GKStateMachine *)machine;
@end

// The one shuffle of the random family: -[GKRandomSource arrayByShufflingObjectsInArray:] and the
// two methods NSArray carries for GameplayKit all reach this one, so that a band which leaves out
// the file the framework's own methods are in still has the shuffle.
@interface NSArray (CharonGKShuffle)
- (NSArray *)charon_shuffledArrayWithRandomSource:(id<GKRandom>)source;
@end

// The source a distribution draws through, so the shuffled distribution below it can ask for its
// own bounds -- a shuffle needs a draw from [0, i], not the next value of the range.
@interface GKRandomDistribution (CharonGKSource)
- (id<GKRandom>)charon_source;
@end
