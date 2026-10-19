// differential.m -- the port's noise sources held against what the host's own GameplayKit answers.
//
// The host is the oracle and it is measured, not called: the port's classes and the host's have the
// same names, so loading both into one process would answer one of the two for the other. measure.m
// prints what the host answers; every expectation below is one of its numbers, and the check's name says
// which line it came from.

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>
#import <objc/runtime.h>

static int checksRun = 0;
static int checksFailed = 0;

static void host(BOOL ok, NSString *what)
{
    checksRun++;
    if (!ok) {
        checksFailed++;
        printf("FAIL host: %s\n", [what UTF8String]);
    }
}

static void contract(BOOL ok, NSString *what, NSString *detail)
{
    checksRun++;
    if (!ok) {
        checksFailed++;
        printf("FAIL contract: %s -- %s\n", [what UTF8String], [detail UTF8String]);
    }
}

int main(void)
{
    @autoreleasepool {
        // Each factory hands back the class it names, with the numbers it was given. A factory that
        // answered a shared class instead would be one value wrong in eight places.
        {
            GKPerlinNoiseSource *perlin = [GKPerlinNoiseSource perlinNoiseSourceWithFrequency:1.5 octaveCount:3
                                                                                      persistence:0.25 lacunarity:2.5 seed:11];
            host([perlin isMemberOfClass:[GKPerlinNoiseSource class]] && perlin.frequency == 1.5 &&
                 perlin.octaveCount == 3 && perlin.persistence == 0.25 && perlin.lacunarity == 2.5 && perlin.seed == 11,
                 @"the perlin factory answers a perlin source with the five numbers, as the host's does");
            GKBillowNoiseSource *billow = [GKBillowNoiseSource billowNoiseSourceWithFrequency:1.0 octaveCount:2
                                                                                 persistence:0.5 lacunarity:2.0 seed:7];
            host([billow isMemberOfClass:[GKBillowNoiseSource class]] && billow.frequency == 1.0 &&
                 billow.octaveCount == 2 && billow.persistence == 0.5 && billow.lacunarity == 2.0 && billow.seed == 7,
                 @"the billow factory answers a billow source with the five numbers, as the host's does");
            GKRidgedNoiseSource *ridged = [GKRidgedNoiseSource ridgedNoiseSourceWithFrequency:1.0 octaveCount:2
                                                                              lacunarity:2.0 seed:7];
            host([ridged isMemberOfClass:[GKRidgedNoiseSource class]] && ridged.frequency == 1.0 &&
                 ridged.octaveCount == 2 && ridged.lacunarity == 2.0 && ridged.seed == 7,
                 @"the ridged factory answers a ridged source with the three numbers, as the host's does");
            GKVoronoiNoiseSource *voronoi = [GKVoronoiNoiseSource voronoiNoiseWithFrequency:1.0 displacement:0.5
                                                                           distanceEnabled:YES seed:4];
            host([voronoi isMemberOfClass:[GKVoronoiNoiseSource class]] && voronoi.frequency == 1.0 &&
                 voronoi.displacement == 0.5 && voronoi.isDistanceEnabled && voronoi.seed == 4,
                 @"the voronoi factory answers a voronoi source with the four numbers, as the host's does");
            GKConstantNoiseSource *constant = [GKConstantNoiseSource constantNoiseWithValue:0.375];
            host([constant isMemberOfClass:[GKConstantNoiseSource class]] && constant.value == 0.375,
                 @"the constant factory answers a constant source with the value, as the host's does");
            GKCheckerboardNoiseSource *checkerboard = [GKCheckerboardNoiseSource checkerboardNoiseWithSquareSize:2.0];
            host([checkerboard isMemberOfClass:[GKCheckerboardNoiseSource class]] && checkerboard.squareSize == 2.0,
                 @"the checkerboard factory answers a checkerboard source with the square size, as the host's does");
            GKCylindersNoiseSource *cylinders = [GKCylindersNoiseSource cylindersNoiseWithFrequency:1.0];
            host([cylinders isMemberOfClass:[GKCylindersNoiseSource class]] && cylinders.frequency == 1.0,
                 @"the cylinders factory answers a cylinders source with the frequency, as the host's does");
            GKSpheresNoiseSource *spheres = [GKSpheresNoiseSource spheresNoiseWithFrequency:1.0];
            host([spheres isMemberOfClass:[GKSpheresNoiseSource class]] && spheres.frequency == 1.0,
                 @"the spheres factory answers a spheres source with the frequency, as the host's does");
        }
        // A property set after the fact is read back, a negative seed included.
        {
            GKPerlinNoiseSource *perlin = [[GKPerlinNoiseSource alloc] initWithFrequency:2.0 octaveCount:1
                                                                           persistence:0.5 lacunarity:2.0 seed:9];
            host([perlin isMemberOfClass:[GKPerlinNoiseSource class]] && perlin.frequency == 2.0 &&
                 perlin.octaveCount == 1 && perlin.persistence == 0.5 && perlin.lacunarity == 2.0 && perlin.seed == 9,
                 @"the perlin initialiser answers what it was given, as the host's does");
            perlin.frequency = 4.0;
            perlin.octaveCount = 5;
            perlin.persistence = 0.75;
            perlin.lacunarity = 3.0;
            perlin.seed = -3;
            host(perlin.frequency == 4.0 && perlin.octaveCount == 5 && perlin.persistence == 0.75 &&
                 perlin.lacunarity == 3.0 && perlin.seed == -3,
                 @"all five numbers are read back after being set, a negative seed included, as the host's are");
            GKBillowNoiseSource *billow = [[GKBillowNoiseSource alloc] initWithFrequency:1.0 octaveCount:2
                                                                              persistence:0.5 lacunarity:2.0 seed:1];
            billow.persistence = 0.9;
            billow.frequency = 6.0;
            host(billow.persistence == 0.9 && billow.frequency == 6.0,
                 @"a billow source's persistence and frequency are read back after being set, as the host's are");
            GKVoronoiNoiseSource *voronoi = [[GKVoronoiNoiseSource alloc] initWithFrequency:1.0 displacement:0.5
                                                                           distanceEnabled:YES seed:4];
            voronoi.displacement = 0.125;
            voronoi.distanceEnabled = NO;
            voronoi.seed = -11;
            host(voronoi.displacement == 0.125 && !voronoi.isDistanceEnabled && voronoi.seed == -11,
                 @"a voronoi source's displacement, distance flag and seed are read back, as the host's are");
        }
        // The hierarchy, as the host answers it: all nine under the root, three under coherent.
        {
            GKPerlinNoiseSource *perlin = [GKPerlinNoiseSource perlinNoiseSourceWithFrequency:1 octaveCount:1
                                                                               persistence:1 lacunarity:1 seed:0];
            GKBillowNoiseSource *billow = [GKBillowNoiseSource billowNoiseSourceWithFrequency:1 octaveCount:1
                                                                              persistence:1 lacunarity:1 seed:0];
            GKRidgedNoiseSource *ridged = [GKRidgedNoiseSource ridgedNoiseSourceWithFrequency:1 octaveCount:1
                                                                           lacunarity:1 seed:0];
            GKVoronoiNoiseSource *voronoi = [GKVoronoiNoiseSource voronoiNoiseWithFrequency:1 displacement:0
                                                                         distanceEnabled:NO seed:0];
            GKConstantNoiseSource *constant = [GKConstantNoiseSource constantNoiseWithValue:0];
            GKCylindersNoiseSource *cylinders = [GKCylindersNoiseSource cylindersNoiseWithFrequency:1];
            GKSpheresNoiseSource *spheres = [GKSpheresNoiseSource spheresNoiseWithFrequency:1];
            GKCheckerboardNoiseSource *checkerboard = [GKCheckerboardNoiseSource checkerboardNoiseWithSquareSize:1];
            host([perlin isKindOfClass:[GKCoherentNoiseSource class]] &&
                 [billow isKindOfClass:[GKCoherentNoiseSource class]] &&
                 [ridged isKindOfClass:[GKCoherentNoiseSource class]],
                 @"perlin, billow and ridged are coherent sources, as they are on the host");
            host([voronoi isKindOfClass:[GKNoiseSource class]] && [constant isKindOfClass:[GKNoiseSource class]] &&
                 [cylinders isKindOfClass:[GKNoiseSource class]] && [spheres isKindOfClass:[GKNoiseSource class]] &&
                 [checkerboard isKindOfClass:[GKNoiseSource class]],
                 @"voronoi, constant, cylinders, spheres and checkerboard are noise sources, as they are on the host");
        }
        // A base instance is a GKNoiseSource and answers neither number.
        {
            GKNoiseSource *base = [[GKNoiseSource alloc] init];
            host([base isMemberOfClass:[GKNoiseSource class]] &&
                 ![base respondsToSelector:@selector(frequency)] && ![base respondsToSelector:@selector(value)],
                 @"a base source is a GKNoiseSource and answers neither a frequency nor a value, as the host's does");
        }
        // Nothing validates a value: zeros and a negative constant are kept as given.
        {
            GKPerlinNoiseSource *perlin = [[GKPerlinNoiseSource alloc] initWithFrequency:0 octaveCount:0
                                                                           persistence:0 lacunarity:0 seed:0];
            host(perlin.frequency == 0.0 && perlin.octaveCount == 0 && perlin.persistence == 0.0 &&
                 perlin.lacunarity == 0.0 && perlin.seed == 0,
                 @"a source of five zeros is kept as given, as the host keeps it");
            GKConstantNoiseSource *constant = [GKConstantNoiseSource constantNoiseWithValue:-2.5];
            host(constant.value == -2.5, @"a constant of -2.5 is kept, as the host keeps it");
            GKCheckerboardNoiseSource *checkerboard = [GKCheckerboardNoiseSource checkerboardNoiseWithSquareSize:0];
            host(checkerboard.squareSize == 0.0, @"a square size of zero is kept, as the host keeps it");
        }
        // The property each of the two declaring subclasses binds: persistence is theirs, and it is
        // the same storage every coherent source uses, so a billow source and a perlin source of the
        // same numbers answer the same -- and neither can be moved by writing through the other.
        {
            GKPerlinNoiseSource *perlin = [[GKPerlinNoiseSource alloc] initWithFrequency:1 octaveCount:1
                                                                           persistence:0.5 lacunarity:1 seed:0];
            GKBillowNoiseSource *billow = [[GKBillowNoiseSource alloc] initWithFrequency:1 octaveCount:1
                                                                          persistence:0.5 lacunarity:1 seed:0];
            contract(perlin.persistence == 0.5 && billow.persistence == 0.5,
                     @"a perlin source and a billow source of the same numbers agree on persistence",
                     [NSString stringWithFormat:@"%g and %g", perlin.persistence, billow.persistence]);
            perlin.persistence = 0.25;
            contract(billow.persistence == 0.5 && perlin.persistence == 0.25,
                     @"writing one source's persistence does not move the other's",
                     [NSString stringWithFormat:@"the billow source reads %g", billow.persistence]);
        }
    }
    printf("%d checks, %d failed\n", checksRun, checksFailed);
    return checksFailed == 0 ? 0 : 1;
}
