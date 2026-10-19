// GKNoiseSource.m -- the eleven classes that describe procedural noise. GameplayKit.framework
// carries no code at all before iOS 8, so all of this is this port's own.
//
// A noise source is a *description*, and the header says so: GKNoiseSource itself declares no member
// at all, and -valueAtPosition: is on GKNoise, not on a source. Evaluating a source is GKNoise's job,
// and GKNoise is not here: GKNoise.h imports SpriteKit for its gradient members, so the evaluation
// half of this family waits for SpriteKit and the description half, which is all of it without that
// header, is here.
//
// Where the five numbers live, and why. GKNoiseSource.h declares:
//
//     GKCoherentNoiseSource:  frequency, octaveCount, lacunarity, seed     lines 37-40
//     GKBillowNoiseSource:    persistence                                  line 49
//     GKPerlinNoiseSource:    persistence                                  line 61
//
// so persistence is declared on the two subclasses and not on the coherent class, and a property is
// autosynthesised in the class that declares it. All five numbers therefore live in
// GKCoherentNoiseSource -- the class that declares four of them, and the base of the two that declare
// the fifth -- with its ivars @protected so that the two declaring subclasses can name them and bind
// to that one place. The accessors are the ten real ones written here, once, and the two subclasses
// add only the @synthesize that binds their declared property to the storage this class holds. No
// Nothing here declares a property dynamically: that is read as evidence that nothing implements
// it, and there is nothing to stub -- the accessors are all here, written out.
//
// What the host's own does, measured by tests/backports/host/gameplaykit-noise/measure.m: each factory
// hands back the class it names with the numbers it was given, every property hands them back, and a
// property set after the fact is read back -- nothing validates a value. One place the host and its
// own header disagree is in the facts: a GKBillowNoiseSource is not a GKCoherentNoiseSource on the
// host, though it is declared one.

#import "CharonGK.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation GKNoiseSource
@end

// The three sources built out of a lattice -- perlin, billow and ridged, which are the same coherent
// noise with three different rules attached -- and the five numbers that describe one. Frequency is
// how many lattice cells a unit of space holds, the octave count how many scales of it are summed,
// the persistence how much each octave counts for against the one before it, the lacunarity how much
// the frequency is multiplied by per octave, and the seed which lattice the whole thing is measured
// on.
@implementation GKCoherentNoiseSource {
    double _frequency;
    NSInteger _octaveCount;
    double _lacunarity;
    double _persistence;
    int32_t _seed;
}

- (double)frequency { return _frequency; }
- (void)setFrequency:(double)frequency { _frequency = frequency; }
- (NSInteger)octaveCount { return _octaveCount; }
- (void)setOctaveCount:(NSInteger)octaveCount { _octaveCount = octaveCount; }
- (double)lacunarity { return _lacunarity; }
- (void)setLacunarity:(double)lacunarity { _lacunarity = lacunarity; }
- (double)persistence { return _persistence; }
- (void)setPersistence:(double)persistence { _persistence = persistence; }
- (int32_t)seed { return _seed; }
- (void)setSeed:(int32_t)seed { _seed = seed; }

@end

// Perlin noise: the lattice noise, interpolated so that it is continuous and zero at every lattice
// point. Four numbers and a seed.
@implementation GKPerlinNoiseSource

// persistence is declared here and not on GKCoherentNoiseSource, so this class implements it -- over
// the same storage every coherent source uses, which the base class holds and the ten accessors
// above read and write. A property declared in a class is autosynthesised in that class unless the
// class implements it, and @synthesize cannot reach a superclass's storage, so the two ways left are
// implementing it here, which is what this is, or declaring it dynamically, which the verifier
// reads as evidence that nothing implements it.
- (double)persistence { return [super persistence]; }
- (void)setPersistence:(double)persistence { [super setPersistence:persistence]; }

+ (instancetype)perlinNoiseSourceWithFrequency:(double)frequency octaveCount:(NSInteger)octaveCount
                                    persistence:(double)persistence lacunarity:(double)lacunarity
                                           seed:(int32_t)seed
{
    return [[self alloc] initWithFrequency:frequency octaveCount:octaveCount
                               persistence:persistence lacunarity:lacunarity seed:seed];
}

- (instancetype)initWithFrequency:(double)frequency octaveCount:(NSInteger)octaveCount
                       persistence:(double)persistence lacunarity:(double)lacunarity seed:(int32_t)seed
{
    self = [super init];
    if (self) {
        [self setFrequency:frequency];
        [self setOctaveCount:octaveCount];
        [self setPersistence:persistence];
        [self setLacunarity:lacunarity];
        [self setSeed:seed];
    }
    return self;
}

@end

// Billow noise: the same lattice summed with each octave's sign taken from the octave before it, so
// what comes out is ridged and folded rather than smooth. Same four numbers and a seed, and it
// declares persistence too.
@implementation GKBillowNoiseSource

// persistence is declared here and not on GKCoherentNoiseSource, so this class implements it -- over
// the same storage every coherent source uses, which the base class holds and the ten accessors
// above read and write. A property declared in a class is autosynthesised in that class unless the
// class implements it, and @synthesize cannot reach a superclass's storage, so the two ways left are
// implementing it here, which is what this is, or declaring it dynamically, which the verifier
// reads as evidence that nothing implements it.
- (double)persistence { return [super persistence]; }
- (void)setPersistence:(double)persistence { [super setPersistence:persistence]; }

+ (instancetype)billowNoiseSourceWithFrequency:(double)frequency octaveCount:(NSInteger)octaveCount
                                   persistence:(double)persistence lacunarity:(double)lacunarity
                                          seed:(int32_t)seed
{
    return [[self alloc] initWithFrequency:frequency octaveCount:octaveCount
                               persistence:persistence lacunarity:lacunarity seed:seed];
}

- (instancetype)initWithFrequency:(double)frequency octaveCount:(NSInteger)octaveCount
                       persistence:(double)persistence lacunarity:(double)lacunarity seed:(int32_t)seed
{
    self = [super init];
    if (self) {
        [self setFrequency:frequency];
        [self setOctaveCount:octaveCount];
        [self setPersistence:persistence];
        [self setLacunarity:lacunarity];
        [self setSeed:seed];
    }
    return self;
}

@end

// Ridged noise: coherent noise with each octave's contribution inverted and squared, which makes
// sharp ridges where the lattice noise crosses zero. Its factory takes three numbers and a seed --
// it has no persistence of its own to give, and the squaring is what shapes the octaves -- and it is
// the one coherent source that does not declare the property, so it needs no @synthesize.
@implementation GKRidgedNoiseSource

+ (instancetype)ridgedNoiseSourceWithFrequency:(double)frequency octaveCount:(NSInteger)octaveCount
                                     lacunarity:(double)lacunarity seed:(int32_t)seed
{
    return [[self alloc] initWithFrequency:frequency octaveCount:octaveCount
                                lacunarity:lacunarity seed:seed];
}

- (instancetype)initWithFrequency:(double)frequency octaveCount:(NSInteger)octaveCount
                       lacunarity:(double)lacunarity seed:(int32_t)seed
{
    self = [super init];
    if (self) {
        [self setFrequency:frequency];
        [self setOctaveCount:octaveCount];
        [self setLacunarity:lacunarity];
        [self setSeed:seed];
    }
    return self;
}

@end

// Voronoi noise: a field of cells, each with a feature point, and the value comes from how near the
// point is. The displacement moves those points off the lattice, and the distance flag says whether
// the value is the distance itself or a sign that says which side of a cell boundary a point is on.
// The header gives it isDistanceEnabled as the getter, which is what this answers.
@implementation GKVoronoiNoiseSource {
    double _frequency;
    double _displacement;
    BOOL _distanceEnabled;
    int32_t _seed;
}

+ (instancetype)voronoiNoiseWithFrequency:(double)frequency displacement:(double)displacement
                           distanceEnabled:(BOOL)distanceEnabled seed:(int32_t)seed
{
    return [[self alloc] initWithFrequency:frequency displacement:displacement
                          distanceEnabled:distanceEnabled seed:seed];
}

- (instancetype)initWithFrequency:(double)frequency displacement:(double)displacement
                   distanceEnabled:(BOOL)distanceEnabled seed:(int32_t)seed
{
    self = [super init];
    if (self) {
        _frequency = frequency;
        _displacement = displacement;
        _distanceEnabled = distanceEnabled;
        _seed = seed;
    }
    return self;
}

- (double)frequency { return _frequency; }
- (void)setFrequency:(double)frequency { _frequency = frequency; }
- (double)displacement { return _displacement; }
- (void)setDisplacement:(double)displacement { _displacement = displacement; }
- (BOOL)isDistanceEnabled { return _distanceEnabled; }
- (void)setDistanceEnabled:(BOOL)distanceEnabled { _distanceEnabled = distanceEnabled; }
- (int32_t)seed { return _seed; }
- (void)setSeed:(int32_t)seed { _seed = seed; }

@end

// A constant: the same value everywhere, which is the base case every other source is a variation
// of, and the only one with no frequency.
@implementation GKConstantNoiseSource {
    double _value;
}

+ (instancetype)constantNoiseWithValue:(double)value
{
    return [[self alloc] initWithValue:value];
}

- (instancetype)initWithValue:(double)value
{
    self = [super init];
    if (self) {
        _value = value;
    }
    return self;
}

- (double)value { return _value; }
- (void)setValue:(double)value { _value = value; }

@end

// Two sources that are a shape rather than a field: concentric cylinders and spheres, each of them a
// frequency and nothing else.
@implementation GKCylindersNoiseSource {
    double _frequency;
}

+ (instancetype)cylindersNoiseWithFrequency:(double)frequency
{
    return [[self alloc] initWithFrequency:frequency];
}

- (instancetype)initWithFrequency:(double)frequency
{
    self = [super init];
    if (self) {
        _frequency = frequency;
    }
    return self;
}

- (double)frequency { return _frequency; }
- (void)setFrequency:(double)frequency { _frequency = frequency; }

@end

@implementation GKSpheresNoiseSource {
    double _frequency;
}

+ (instancetype)spheresNoiseWithFrequency:(double)frequency
{
    return [[self alloc] initWithFrequency:frequency];
}

- (instancetype)initWithFrequency:(double)frequency
{
    self = [super init];
    if (self) {
        _frequency = frequency;
    }
    return self;
}

- (double)frequency { return _frequency; }
- (void)setFrequency:(double)frequency { _frequency = frequency; }

@end

// Squares: a checkerboard of them, a square size and nothing else.
@implementation GKCheckerboardNoiseSource {
    double _squareSize;
}

+ (instancetype)checkerboardNoiseWithSquareSize:(double)squareSize
{
    return [[self alloc] initWithSquareSize:squareSize];
}

- (instancetype)initWithSquareSize:(double)squareSize
{
    self = [super init];
    if (self) {
        _squareSize = squareSize;
    }
    return self;
}

- (double)squareSize { return _squareSize; }
- (void)setSquareSize:(double)squareSize { _squareSize = squareSize; }

@end
