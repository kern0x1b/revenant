#import "CharonGK.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation GKNoiseSource
@end

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

@implementation GKPerlinNoiseSource

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

@implementation GKBillowNoiseSource

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
