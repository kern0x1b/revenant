#import "../Foundation/check.h"
#import "RevenantMetalResidency.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    revenant_check((RevenantMetalResidencyPlanFor(false, false, false, 1) == RevenantMetalResidencyReadback) != revenant_negative, "an 8-bit colour texture is kept as a readback snapshot", @"an 8-bit colour texture is not kept as a readback snapshot");
    revenant_check((RevenantMetalResidencyPlanFor(false, false, false, 2) == RevenantMetalResidencyLost) != revenant_negative, "a 16-bit colour texture is lost, because OpenGL ES 2.0 reads only 8-bit channels back", @"a 16-bit colour texture is not marked lost");
    revenant_check((RevenantMetalResidencyPlanFor(false, false, true, 1) == RevenantMetalResidencyLost) != revenant_negative, "a depth or stencil texture is lost", @"a depth or stencil texture is not marked lost");
    revenant_check((RevenantMetalResidencyPlanFor(true, false, false, 1) == RevenantMetalResidencySurface) != revenant_negative, "an IOSurface-backed texture is restored from its surface", @"an IOSurface-backed texture is not restored from its surface");
    revenant_check((RevenantMetalResidencyPlanFor(false, true, false, 1) == RevenantMetalResidencyImage) != revenant_negative, "a CoreVideo texture is recreated from its image", @"a CoreVideo texture is not recreated from its image");
    revenant_check(RevenantMetalGenerationIsCurrent(4, 4) != revenant_negative, "a resource of the current generation is current", @"a resource of the current generation is not current");
    revenant_check((!RevenantMetalGenerationIsCurrent(4, 5)) != revenant_negative, "a resource of an earlier generation is stale", @"a resource of an earlier generation is current");

    return revenant_finish();
}
