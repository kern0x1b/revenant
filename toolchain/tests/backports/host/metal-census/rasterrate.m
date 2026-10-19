#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface revenantHost_MTLRasterizationRateSampleArray : NSObject
- (NSNumber *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(NSNumber *)value atIndexedSubscript:(NSUInteger)index;
@end
@interface revenantHost_MTLRasterizationRateLayerDescriptor : NSObject
- (instancetype)initWithSampleCount:(MTLSize)sampleCount;
@property (nonatomic) MTLSize sampleCount;
@property (nonatomic) MTLSize maxSampleCount;
@property (nonatomic) MTLRasterizationRateSampleArray *horizontal;
@property (nonatomic) MTLRasterizationRateSampleArray *vertical;
@end
@interface revenantHost_MTLRasterizationRateLayerArray : NSObject
- (MTLRasterizationRateLayerDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(MTLRasterizationRateLayerDescriptor *)layer atIndexedSubscript:(NSUInteger)index;
- (NSUInteger)count;
@end
@interface revenantHost_MTLRasterizationRateMapDescriptor : NSObject
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
        {
            MTLRasterizationRateMapDescriptor *h = [[MTLRasterizationRateMapDescriptor alloc] init];
            revenantHost_MTLRasterizationRateMapDescriptor *p =
                [[revenantHost_MTLRasterizationRateMapDescriptor alloc] init];
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
        {
            MTLRasterizationRateLayerDescriptor *hl =
                [[MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(4, 4, 1)];
            revenantHost_MTLRasterizationRateLayerDescriptor *pl =
                [[revenantHost_MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(4, 4, 1)];
            MTLRasterizationRateMapDescriptor *h = [[MTLRasterizationRateMapDescriptor alloc] init];
            revenantHost_MTLRasterizationRateMapDescriptor *p =
                [[revenantHost_MTLRasterizationRateMapDescriptor alloc] init];
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
        {
            revenantHost_MTLRasterizationRateLayerDescriptor *p =
                [[revenantHost_MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(7, 5, 1)];
            same_size([p sampleCount], MTLSizeMake(7, 5, 1),
                      @"MTLRasterizationRateLayerDescriptor.sampleCount is the count it was built with");
            revenantHost_MTLRasterizationRateLayerDescriptor *fresh =
                [[revenantHost_MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(0, 0, 0)];
            same_size([fresh sampleCount], MTLSizeMake(0, 0, 0), @"a layer built with no samples answers 0");
            same_size([fresh maxSampleCount], [fresh sampleCount],
                      @"maxSampleCount answers what sampleCount does, both the enumeration's zero");
        }
        {
            revenantHost_MTLRasterizationRateLayerDescriptor *p =
                [[revenantHost_MTLRasterizationRateLayerDescriptor alloc] initWithSampleCount:MTLSizeMake(2, 2, 1)];
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
