// measure.m -- what the host's own GameplayKit answers for the noise sources.
//
// The host is the oracle and it is measured, not called: the port's classes and the host's have the
// same names, so loading both in one process would answer one of the two for the other. Every number
// below is printed here and held to in differential.m, and every line says the call it came from.

#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>
#import <objc/runtime.h>

int main(void)
{
    // The factories: what class each one answers, and the numbers it was given.
    {
        GKPerlinNoiseSource *perlin = [GKPerlinNoiseSource perlinNoiseSourceWithFrequency:1.5 octaveCount:3
                                                                                  persistence:0.25 lacunarity:2.5 seed:11];
        printf("perlin factory: class=%s frequency=%g octaveCount=%ld persistence=%g lacunarity=%g seed=%d\n",
               class_getName([perlin class]), perlin.frequency, (long)perlin.octaveCount, perlin.persistence,
               perlin.lacunarity, (int)perlin.seed);
        GKBillowNoiseSource *billow = [GKBillowNoiseSource billowNoiseSourceWithFrequency:1.0 octaveCount:2
                                                                             persistence:0.5 lacunarity:2.0 seed:7];
        printf("billow factory: class=%s frequency=%g octaveCount=%ld persistence=%g lacunarity=%g seed=%d\n",
               class_getName([billow class]), billow.frequency, (long)billow.octaveCount, billow.persistence,
               billow.lacunarity, (int)billow.seed);
        GKRidgedNoiseSource *ridged = [GKRidgedNoiseSource ridgedNoiseSourceWithFrequency:1.0 octaveCount:2
                                                                              lacunarity:2.0 seed:7];
        printf("ridged factory: class=%s frequency=%g octaveCount=%ld lacunarity=%g seed=%d\n",
               class_getName([ridged class]), ridged.frequency, (long)ridged.octaveCount, ridged.lacunarity,
               (int)ridged.seed);
        GKVoronoiNoiseSource *voronoi = [GKVoronoiNoiseSource voronoiNoiseWithFrequency:1.0 displacement:0.5
                                                                       distanceEnabled:YES seed:4];
        printf("voronoi factory: class=%s frequency=%g displacement=%g distanceEnabled=%d seed=%d\n",
               class_getName([voronoi class]), voronoi.frequency, voronoi.displacement,
               (int)voronoi.isDistanceEnabled, (int)voronoi.seed);
        GKConstantNoiseSource *constant = [GKConstantNoiseSource constantNoiseWithValue:0.375];
        printf("constant factory: class=%s value=%g\n", class_getName([constant class]), constant.value);
        GKCheckerboardNoiseSource *checkerboard = [GKCheckerboardNoiseSource checkerboardNoiseWithSquareSize:2.0];
        printf("checkerboard factory: class=%s squareSize=%g\n", class_getName([checkerboard class]), checkerboard.squareSize);
        GKCylindersNoiseSource *cylinders = [GKCylindersNoiseSource cylindersNoiseWithFrequency:1.0];
        GKSpheresNoiseSource *spheres = [GKSpheresNoiseSource spheresNoiseWithFrequency:1.0];
        printf("cylinders factory: class=%s frequency=%g\n", class_getName([cylinders class]), cylinders.frequency);
        printf("spheres factory: class=%s frequency=%g\n", class_getName([spheres class]), spheres.frequency);
    }
    // A property set after the fact, and a negative seed: nothing validates a value.
    {
        GKPerlinNoiseSource *perlin = [[GKPerlinNoiseSource alloc] initWithFrequency:2.0 octaveCount:1
                                                                       persistence:0.5 lacunarity:2.0 seed:9];
        printf("perlin init: class=%s frequency=%g octaveCount=%ld persistence=%g lacunarity=%g seed=%d\n",
               class_getName([perlin class]), perlin.frequency, (long)perlin.octaveCount, perlin.persistence,
               perlin.lacunarity, (int)perlin.seed);
        perlin.frequency = 4.0;
        perlin.octaveCount = 5;
        perlin.persistence = 0.75;
        perlin.lacunarity = 3.0;
        perlin.seed = -3;
        printf("perlin set: frequency=%g octaveCount=%ld persistence=%g lacunarity=%g seed=%d\n",
               perlin.frequency, (long)perlin.octaveCount, perlin.persistence, perlin.lacunarity, (int)perlin.seed);
        GKBillowNoiseSource *billow = [[GKBillowNoiseSource alloc] initWithFrequency:1.0 octaveCount:2
                                                                          persistence:0.5 lacunarity:2.0 seed:1];
        billow.persistence = 0.9;
        billow.frequency = 6.0;
        printf("billow set: persistence=%g frequency=%g\n", billow.persistence, billow.frequency);
        GKVoronoiNoiseSource *voronoi = [[GKVoronoiNoiseSource alloc] initWithFrequency:1.0 displacement:0.5
                                                                       distanceEnabled:YES seed:4];
        voronoi.displacement = 0.125;
        voronoi.distanceEnabled = NO;
        voronoi.seed = -11;
        printf("voronoi set: displacement=%g distanceEnabled=%d seed=%d\n", voronoi.displacement,
               (int)voronoi.isDistanceEnabled, (int)voronoi.seed);
    }
    // A base instance answers none of them.
    {
        GKNoiseSource *base = [[GKNoiseSource alloc] init];
        printf("base: class=%s frequency=%d value=%d\n", class_getName([base class]),
               (int)[base respondsToSelector:@selector(frequency)], (int)[base respondsToSelector:@selector(value)]);
    }
    // The hierarchy, as the host answers it. Perlin and ridged are coherent sources here; billow is
    // not, although its header declares it one, and that is the recorded divergence.
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
        printf("hierarchy: perlin-coherent=%d ridged-coherent=%d billow-coherent=%d\n",
               (int)[perlin isKindOfClass:[GKCoherentNoiseSource class]],
               (int)[ridged isKindOfClass:[GKCoherentNoiseSource class]],
               (int)[billow isKindOfClass:[GKCoherentNoiseSource class]]);
        printf("hierarchy: voronoi-source=%d constant-source=%d cylinders-source=%d spheres-source=%d checkerboard-source=%d\n",
               (int)[voronoi isKindOfClass:[GKNoiseSource class]], (int)[constant isKindOfClass:[GKNoiseSource class]],
               (int)[cylinders isKindOfClass:[GKNoiseSource class]], (int)[spheres isKindOfClass:[GKNoiseSource class]],
               (int)[checkerboard isKindOfClass:[GKNoiseSource class]]);
    }
    // Nothing validates a value: a zero of everything is kept as given.
    {
        GKPerlinNoiseSource *perlin = [[GKPerlinNoiseSource alloc] initWithFrequency:0 octaveCount:0
                                                                       persistence:0 lacunarity:0 seed:0];
        printf("perlin zeros: frequency=%g octaveCount=%ld persistence=%g lacunarity=%g seed=%d\n",
               perlin.frequency, (long)perlin.octaveCount, perlin.persistence, perlin.lacunarity, (int)perlin.seed);
        GKConstantNoiseSource *constant = [GKConstantNoiseSource constantNoiseWithValue:-2.5];
        printf("constant negative: value=%g\n", constant.value);
        GKCheckerboardNoiseSource *checkerboard = [GKCheckerboardNoiseSource checkerboardNoiseWithSquareSize:0];
        printf("checkerboard zero: squareSize=%g\n", checkerboard.squareSize);
    }
    return 0;
}
