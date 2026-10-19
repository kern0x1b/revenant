#import <Foundation/Foundation.h>
#import <GameplayKit/GameplayKit.h>
#import <objc/runtime.h>

int main(void)
{
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
    {
        GKNoiseSource *base = [[GKNoiseSource alloc] init];
        printf("base: class=%s frequency=%d value=%d\n", class_getName([base class]),
               (int)[base respondsToSelector:@selector(frequency)], (int)[base respondsToSelector:@selector(value)]);
    }
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
