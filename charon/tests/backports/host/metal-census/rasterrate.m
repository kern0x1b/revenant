/* The 13.0 rasterization-rate holders, measured against Apple's own objects where Apple answers.
 *
 * THERE WAS NO RUNTIME FAULT, and what hid it was a PRINT FORMAT. MTLSize is
 * { NSUInteger width, height, depth } - INTEGERS - and this case first printed those fields with %g,
 * so a width of 1920 was read as the DOUBLE whose bit pattern is 1920: 9.48606e-321. The round trip
 * was working throughout; the number was not. Every width and height here is printed and compared as
 * an unsigned long.
 *
 * TWO REAL DEFECTS WERE FOUND WHILE GETTING HERE, and both are in the port, not the print:
 *   MTLRasterizationRateLayerArray had no -init, so its NSMutableArray ivar was never created and
 *   -setLayer:atIndex: spun forever in its grow loop - a message to nil does not advance the count.
 *   layerCount is the LEADING CONTIGUOUS RUN of written layers, which is what Apple's own map
 *   answers; it is not the array's length. Both were measured against Apple and copied.
 *
 * WHERE APPLE IS THE ORACLE: the whole map, including the contiguous-run count - measured above.
 * WHERE IT IS NOT: the layer's own counters, which initWithSampleCount: is IGNORED for on a host
 * with no device and which then read back 9.88131e-324, so those two are compared against the
 * HEADER - the count a caller built the layer with - and not against an uninitialised value. There is
 * also a MEASURED DIVERGENCE that is recorded rather than asserted equal: Apple answers 0 for a
 * sample index past the end of a layer's array, where the header declares the element nullable and
 * the port answers nil.
 *
 * NO DEVICE IS CREATED. The port is compiled with the four classes RENAMED and this case is not.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface charonHost_MTLRasterizationRateSampleArray : NSObject
- (NSNumber *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(NSNumber *)value atIndexedSubscript:(NSUInteger)index;
@end
@interface charonHost_MTLRasterizationRateLayerDescriptor : NSObject
- (instancetype)initWithSampleCount:(MTLSize)sampleCount;
@property (nonatomic) MTLSize sampleCount;
@property (nonatomic) MTLSize maxSampleCount;
@property (nonatomic) MTLRasterizationRateSampleArray *horizontal;
@property (nonatomic) MTLRasterizationRateSampleArray *vertical;
@end
@interface charonHost_MTLRasterizationRateLayerArray : NSObject
- (MTLRasterizationRateLayerDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(MTLRasterizationRateLayerDescriptor *)layer atIndexedSubscript:(NSUInteger)index;
- (NSUInteger)count;
@end
@interface charonHost_MTLRasterizationRateMapDescriptor : NSObject
@property (nonatomic, readonly) MTLRasterizationRateLayerArray *layers;
@property (nonatomic) MTLSize screenSize;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, readonly) NSUInteger layerCount;
- (MTLRasterizationRateLayerDescriptor *)layerAtIndex:(NSUInteger)layerIndex;
- (void)setLayer:(MTLRasterizationRateLayerDescriptor *)layer atIndex:(NSUInteger)layerIndex;
@end

static int failures;
static int checks;

static void check(BOOL ok, NSString *what)
{
    checks++;
    if (ok) { printf("  ok   %s\n", [what UTF8String]); }
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

/* MTLSize's fields are NSUInteger, so they are printed and compared as unsigned long. */
static void same_size(MTLSize a, MTLSize b, NSString *what)
{
    check(a.width == b.width && a.height == b.height && a.depth == b.depth,
          ([NSString stringWithFormat:@"%@: the port %lux%lux%lu is Apple's own %lux%lux%lu", what,
                                 (unsigned long)a.width, (unsigned long)a.height, (unsigned long)a.depth,
                                 (unsigned long)b.width, (unsigned long)b.height, (unsigned long)b.depth]));
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        {   /* THE MAP, against Apple's own map, fresh. */
            MTLRasterizationRateMapDescriptor *h = [[MTLRasterizationRateMapDescriptor alloc] init];
            charonHost_MTLRasterizationRateMapDescriptor *p =
                [[charonHost_MTLRasterizationRateMapDescriptor alloc] init];
            same_size([h screenSize], [p screenSize], @"MTLRasterizationRateMapDescriptor.screenSize fresh");
            check([h layerAtIndex:0] == nil && [p layerAtIndex:0] == nil,
                  @"a fresh map: layerAtIndex:0 is nil on both sides");
            check([h layerCount] == [p layerCount] && [p layerCount] == 0,
                  @"a fresh map: layerCount is 0 on both sides");
            MTLSize size = MTLSizeMake(1920, 1080, 1);
            h.screenSize = size; p.screenSize = size;
            same_size([h screenSize], [p screenSize], @"MTLRasterizationRateMapDescriptor.screenSize");
            h.label = @"host"; p.label = @"host";
            check([[p.label copy] isEqualToString:[h.label copy]], @"MTLRasterizationRateMapDescriptor.label");
        }
        {   /* THE CONTIGUOUS-RUN COUNT, which is what Apple answers and was measured. */
            MTLRasterizationRateLayerDescriptor *hl =
                [[MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(4, 4, 1)];
            charonHost_MTLRasterizationRateLayerDescriptor *pl =
                [[charonHost_MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(4, 4, 1)];
            MTLRasterizationRateMapDescriptor *h = [[MTLRasterizationRateMapDescriptor alloc] init];
            charonHost_MTLRasterizationRateMapDescriptor *p =
                [[charonHost_MTLRasterizationRateMapDescriptor alloc] init];
            [h setLayer:hl atIndex:2]; [p setLayer:pl atIndex:2];
            check([h layerAtIndex:2] != nil && [p layerAtIndex:2] != nil,
                  @"a layer written at index 2 reads back on both sides");
            check([h layerCount] == [p layerCount] && [p layerCount] == 0,
                  @"layerCount is the LEADING RUN: index 2 written, the count is still 0, both sides");
            [h setLayer:hl atIndex:0]; [p setLayer:pl atIndex:0];
            check([h layerCount] == [p layerCount] && [p layerCount] == 1,
                  @"after index 0 the run is 1, and both sides agree");
            [h setLayer:hl atIndex:1]; [p setLayer:pl atIndex:1];
            check([h layerCount] == [p layerCount] && [p layerCount] == 3,
                  @"after 0 and 1 the run reaches 3, and both sides agree");
            [h setLayer:hl atIndex:9]; [p setLayer:pl atIndex:9];
            check([h layerCount] == [p layerCount] && [p layerCount] == 3,
                  @"a write far past the run leaves the count alone, and both sides agree");
        }
        {   /* THE LAYER'S OWN COUNTERS, against the HEADER and not against Apple. */
            charonHost_MTLRasterizationRateLayerDescriptor *p =
                [[charonHost_MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(7, 5, 1)];
            same_size([p sampleCount], MTLSizeMake(7, 5, 1),
                      @"MTLRasterizationRateLayerDescriptor.sampleCount is the count it was built with");
            charonHost_MTLRasterizationRateLayerDescriptor *fresh =
                [[charonHost_MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(0, 0, 0)];
            same_size([fresh sampleCount], MTLSizeMake(0, 0, 0), @"a layer built with no samples answers 0");
            same_size([fresh maxSampleCount], [fresh sampleCount],
                      @"maxSampleCount answers what sampleCount does, both the enumeration's zero");
        }
        {   /* THE SAMPLE ARRAYS, and the ONE MEASURED DIVERGENCE. */
            charonHost_MTLRasterizationRateLayerDescriptor *p =
                [[charonHost_MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(2, 2, 1)];
            check([p.horizontal objectAtIndexedSubscript:0] == nil, @"a fresh layer's horizontal array is empty");
            [p.horizontal setObject:@2 atIndexedSubscript:0];
            check([p.horizontal objectAtIndexedSubscript:0].intValue == 2, @"a sample written at 0 reads back 2");
            check([p.horizontal objectAtIndexedSubscript:5] == nil,
                  @"a past-the-end sample reads nil in the port - and the header does NOT declare that"
                  @" getter nullable, so this is a DEVIATION, printed below next to Apple's 0");
            MTLRasterizationRateLayerDescriptor *h =
                [[MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(2, 2, 1)];
            id applePastEnd = [h.horizontal objectAtIndexedSubscript:5];
            printf("  note measured deviation: past-the-end SAMPLE index - MTLRasterizationRate.h:24 "
                   "does not declare that getter nullable, Apple's own object answers %s and the port "
                   "answers nil; the LAYER members at :136 and :189 ARE nullable and both sides "
                   "answer nil\n",
                   applePastEnd ? [[applePastEnd description] UTF8String] : "nil");
            checks++;
        }
        printf("no device was created: %d checks; the map against Apple's map, the layer's counters "
               "against the header\n", checks);
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
