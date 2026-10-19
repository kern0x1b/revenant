#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>

typedef NSString *(*NameFunction)(CGColorRef);
static NameFunction nameOf;

static NSString *nameFor(unsigned r, unsigned g, unsigned b)
{
    static CGColorSpaceRef space;
    if (!space) space = CGColorSpaceCreateDeviceRGB();
    double parts[4] = {r / 255.0, g / 255.0, b / 255.0, 1.0};
    CGColorRef colour = CGColorCreate(space, parts);
    NSString *name = nameOf(colour);
    CGColorRelease(colour);
    return name ?: @"(nil)";
}

static uint64_t state;
static uint32_t next(void)
{
    state ^= state << 13; state ^= state >> 7; state ^= state << 17;
    return (uint32_t)(state >> 32);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 3) { fprintf(stderr, "usage: probe-dense <out.tsv> <seed>\n"); return 2; }
        const char *out = argv[1];
        state = (uint64_t)strtoull(argv[2], NULL, 10) | 1;

        void *implementation = dlsym(RTLD_DEFAULT, "AXNameFromColor");
        if (!implementation) { fprintf(stderr, "the host has no AXNameFromColor\n"); return 2; }
        Dl_info info;
        dladdr(implementation, &info);
        printf("probe\tAXNameFromColor is in %s\n", info.dli_fname);
        nameOf = (NameFunction)implementation;

        FILE *file = fopen(out, "w");
        if (!file) { perror("fopen"); return 1; }
        fprintf(file, "#probe\tAXNameFromColor in %s\tseed %s\n", info.dli_fname, argv[2]);

        NSMutableDictionary<NSString *, NSString *> *first = [NSMutableDictionary dictionary];
        NSMutableSet<NSString *> *vocabulary = [NSMutableSet set];
        const unsigned side = 17;
        unsigned grid = 0, changed = 0;
        for (unsigned r = 0; r < side; r++)
            for (unsigned g = 0; g < side; g++)
                for (unsigned b = 0; b < side; b++) {
                    unsigned step = side > 1 ? 255 / (side - 1) : 255;
                    unsigned rgb[3] = {r * step, g * step, b * step};
                    NSString *name = nameFor(rgb[0], rgb[1], rgb[2]);
                    [vocabulary addObject:name];
                    fprintf(file, "g\t%u\t%u\t%u\t%s\n", rgb[0], rgb[1], rgb[2], name.UTF8String);
                    [first setObject:name forKey:[NSString stringWithFormat:@"%u,%u,%u",
                                                rgb[0], rgb[1], rgb[2]]];
                    grid++;
                }
        for (unsigned r = 0; r < side; r++)
            for (unsigned g = 0; g < side; g++)
                for (unsigned b = 0; b < side; b++) {
                    unsigned step = side > 1 ? 255 / (side - 1) : 255;
                    unsigned here[3] = {r * step, g * step, b * step};
                    NSString *mine = nameFor(here[0], here[1], here[2]);
                    const int delta[6][3] = {{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}};
                    for (int d = 0; d < 6; d++) {
                        int nr = here[0] + delta[d][0] * (int)step;
                        int ng = here[1] + delta[d][1] * (int)step;
                        int nb = here[2] + delta[d][2] * (int)step;
                        if (nr < 0 || nr > 255 || ng < 0 || ng > 255 || nb < 0 || nb > 255) continue;
                        if ([nameFor((unsigned)nr, (unsigned)ng, (unsigned)nb) isEqualToString:mine]) continue;
                        changed++;
                        for (int e = -1; e <= 1; e++)
                            for (int f = -1; f <= 1; f++)
                                for (int h = -1; h <= 1; h++) {
                                    int ar = nr + e, ag = ng + f, ab = nb + h;
                                    if (ar < 0 || ar > 255 || ag < 0 || ag > 255 || ab < 0 || ab > 255) continue;
                                    [vocabulary addObject:nameFor((unsigned)ar, (unsigned)ag, (unsigned)ab)];
                                    fprintf(file, "b\t%d\t%d\t%d\t%s\n", ar, ag, ab,
                                            nameFor((unsigned)ar, (unsigned)ag, (unsigned)ab).UTF8String);
                                }
                    }
                }
        unsigned random = 0;
        for (unsigned i = 0; i < 20000; i++) {
            unsigned rgb[3] = {next() & 0xFF, next() & 0xFF, next() & 0xFF};
            NSString *name = nameFor(rgb[0], rgb[1], rgb[2]);
            [vocabulary addObject:name];
            fprintf(file, "r\t%u\t%u\t%u\t%s\n", rgb[0], rgb[1], rgb[2], name.UTF8String);
            random++;
        }
        struct { unsigned r, g, b; } edges[] = {
            {0,0,0},{255,255,255},{128,128,128},{200,200,200},{1,1,1},{254,254,254},
            {255,0,0},{0,255,0},{0,0,255},{255,255,0},{0,255,255},{255,0,255},
            {128,0,0},{0,128,0},{0,0,128},{255,165,0},{165,42,42},{255,192,203},
            {128,128,0},{0,128,128},{128,0,128},
        };
        unsigned edge = 0;
        for (unsigned i = 0; i < sizeof(edges)/sizeof(edges[0]); i++) {
            NSString *name = nameFor(edges[i].r, edges[i].g, edges[i].b);
            [vocabulary addObject:name];
            fprintf(file, "e\t%u\t%u\t%u\t%s\n", edges[i].r, edges[i].g, edges[i].b, name.UTF8String);
            edge++;
        }
        fclose(file);
        printf("fit\tgrid %u\tboundary-neighbour points %u\trandom %u\tedge %u\n", grid, changed, random, edge);
        printf("vocabulary\t%lu\n", (unsigned long)vocabulary.count);
        NSArray<NSString *> *sorted = [vocabulary.allObjects sortedArrayUsingSelector:@selector(compare:)];
        printf("first\t%s\nlast\t%s\n", sorted.firstObject.UTF8String, sorted.lastObject.UTF8String);
    }
    return 0;
}
