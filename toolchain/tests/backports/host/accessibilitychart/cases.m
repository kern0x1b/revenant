#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

static NSString *name(NSString *spelling);

@interface RevenantCaseAdopter : NSObject <AXChart, AXDataAxisDescriptor> {
    AXChartDescriptor *_chartDescriptor;
    NSString *_title;
    NSAttributedString *_attributedTitle;
}
@property (nonatomic, strong) AXChartDescriptor *accessibilityChartDescriptor;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSAttributedString *attributedTitle;
@end

@implementation RevenantCaseAdopter

@synthesize accessibilityChartDescriptor = _chartDescriptor;
@synthesize title = _title;
@synthesize attributedTitle = _attributedTitle;

- (NSString *)description
{
    return [NSString stringWithFormat:@"<RevenantCaseAdopter title %@ attributed %@ chart %@ series %lu>",
            _title ?: @"(none)",
            _attributedTitle ?: @"(none)",
            _chartDescriptor ? name(NSStringFromClass([_chartDescriptor class])) : @"(none)",
            (unsigned long)(_chartDescriptor ? _chartDescriptor.series.count : 0)];
}

@end

#ifndef AXCHART_PROTOCOL
#define AXCHART_PROTOCOL @"AXChart"
#endif
#ifndef AXDATAAXISDESCRIPTOR_PROTOCOL
#define AXDATAAXISDESCRIPTOR_PROTOCOL @"AXDataAxisDescriptor"
#endif

static NSString *name(NSString *spelling)
{
    if (spelling.length > [@"RevenantPort" length] &&
        [[spelling substringToIndex:[@"RevenantPort" length]] isEqualToString:@"RevenantPort"]) {
        return [spelling substringFromIndex:[@"RevenantPort" length]];
    }
    return spelling;
}

static void say(NSString *label, id value)
{
    NSString *text = [value description] ?: @"(nil)";
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    text = [text stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    text = [text stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
    while ([text rangeOfString:@"  "].location != NSNotFound) {
        text = [text stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    printf("%s\t%s\n", label.UTF8String, text.UTF8String);
}

static void sayClass(NSString *label, Class value)
{
    say(label, name(NSStringFromClass(value)));
}

static void same(NSString *label, id a, id b)
{
    say(label, (a != nil && a == b) ? @"shared" : (a == nil && b == nil ? @"both-nil" : @"copied"));
}

static void sayNumber(NSString *label, double value)
{
    printf("%s\t%g\n", label.UTF8String, value);
}

static void sayYes(NSString *label, BOOL value)
{
    printf("%s\t%s\n", label.UTF8String, value ? "yes" : "no");
}

static NSAttributedString *attributed(NSString *text)
{
    return [[NSAttributedString alloc] initWithString:text];
}

static NSString *(^describer(NSString *format))(double)
{
    return ^NSString *(double value) {
        return [NSString stringWithFormat:format, value];
    };
}

int main(void)
{
    @autoreleasepool {
        AXDataPointValue *number = [AXDataPointValue valueWithNumber:1.5];
        AXDataPointValue *category = [AXDataPointValue valueWithCategory:@"cat"];
        say(@"value.number.fromNumber", @(number.number));
        say(@"value.category.fromNumber", number.category ?: @"(nil)");
        sayNumber(@"value.number.fromCategory", category.number);
        say(@"value.category.fromCategory", category.category ?: @"(nil)");
        number.category = @"onANumber";
        say(@"value.category.set", number.category);
        sayNumber(@"value.number.afterCategorySet", number.number);
        category.number = 7.5;
        sayNumber(@"value.number.set", category.number);
        say(@"value.category.afterNumberSet", category.category);
        AXDataPointValue *numberCopy = [number copy];
        say(@"value.copy.number", @(numberCopy.number));
        say(@"value.copy.category", numberCopy.category ?: @"(nil)");
        sayClass(@"value.copy.class", [numberCopy class]);
        same(@"value.copy.category.shared", numberCopy.category, number.category);

        AXDataPoint *bare = [[AXDataPoint alloc] initWithX:number y:nil];
        say(@"point.bare.yValue", bare.yValue ? NSStringFromClass([bare.yValue class]) : @"(nil)");
        say(@"point.bare.additionalValues", bare.additionalValues ? @"present" : @"(nil)");
        say(@"point.bare.label", bare.label ?: @"(nil)");
        say(@"point.bare.attributedLabel", bare.attributedLabel ? @"present" : @"(nil)");
        AXDataPoint *withAdditional = [[AXDataPoint alloc] initWithX:number y:category
                                                 additionalValues:@[number, category]];
        say(@"point.withAdditional.count", @(withAdditional.additionalValues.count));
        say(@"point.withAdditional.label", withAdditional.label ?: @"(nil)");
        AXDataPoint *point = [[AXDataPoint alloc] initWithX:number y:category
                                          additionalValues:@[]
                                                     label:@"L"];
        say(@"point.label", point.label);
        say(@"point.attributedLabel", point.attributedLabel);
        point.label = @"L2";
        say(@"point.attributedLabel.afterLabelSet", point.attributedLabel);
        point.attributedLabel = attributed(@"L3");
        say(@"point.label.afterAttributedSet", point.label);
        point.label = nil;
        say(@"point.attributedLabel.afterLabelNilled", point.attributedLabel ? @"present" : @"(nil)");
        point.yValue = nil;
        say(@"point.yValue.nilled", point.yValue ? @"present" : @"(nil)");
        point.additionalValues = @[number];
        say(@"point.additionalValues.set", @(point.additionalValues.count));
        point.additionalValues = nil;
        say(@"point.additionalValues.nilled", point.additionalValues ? @"present" : @"(nil)");
        point.attributedLabel = attributed(@"PA");
        point.yValue = category;
        point.additionalValues = @[number, category];
        AXDataPoint *pointCopy = [point copy];
        sayClass(@"point.copy.xValue.class", [pointCopy.xValue class]);
        say(@"point.copy.label", pointCopy.label ?: @"(nil)");
        same(@"point.copy.xValue.shared", pointCopy.xValue, point.xValue);
        same(@"point.copy.yValue.shared", pointCopy.yValue, point.yValue);
        same(@"point.copy.additionalValues.shared", pointCopy.additionalValues, point.additionalValues);
        same(@"point.copy.label.shared", pointCopy.label, point.label);
        same(@"point.copy.attributedLabel.shared", pointCopy.attributedLabel, point.attributedLabel);

        AXDataSeriesDescriptor *series = [[AXDataSeriesDescriptor alloc] initWithName:@"S" isContinuous:YES
                                                                             dataPoints:@[point, bare]];
        say(@"series.name", series.name);
        say(@"series.attributedName", series.attributedName);
        sayYes(@"series.isContinuous", series.isContinuous);
        say(@"series.dataPoints.count", @(series.dataPoints.count));
        AXDataSeriesDescriptor *attributedSeries = [[AXDataSeriesDescriptor alloc] initWithAttributedName:attributed(@"A")
                                                                                            isContinuous:NO
                                                                                               dataPoints:@[]];
        say(@"series.attributed.name", attributedSeries.name);
        say(@"series.attributed.attributedName", attributedSeries.attributedName);
        sayYes(@"series.attributed.isContinuous", attributedSeries.isContinuous);
        say(@"series.attributed.dataPoints.count", @(attributedSeries.dataPoints.count));
        series.name = @"S2";
        say(@"series.attributedName.afterNameSet", series.attributedName);
        series.attributedName = attributed(@"S3");
        say(@"series.name.afterAttributedSet", series.name);
        series.attributedName = attributed(@"SA");
        AXDataSeriesDescriptor *seriesCopy = [series copy];
        say(@"series.copy.name", seriesCopy.name);
        say(@"series.copy.dataPoints.count", @(seriesCopy.dataPoints.count));
        same(@"series.copy.dataPoints.shared", seriesCopy.dataPoints, series.dataPoints);
        same(@"series.copy.name.shared", seriesCopy.name, series.name);
        same(@"series.copy.attributedName.shared", seriesCopy.attributedName, series.attributedName);

        AXNumericDataAxisDescriptor *numeric = [[AXNumericDataAxisDescriptor alloc] initWithTitle:@"N"
                                                                                    lowerBound:1
                                                                                    upperBound:2
                                                                            gridlinePositions:@[@0, @1]
                                                                    valueDescriptionProvider:describer(@"%.2f")];
        say(@"numeric.title", numeric.title);
        say(@"numeric.attributedTitle", numeric.attributedTitle);
        sayNumber(@"numeric.scaleType", numeric.scaleType);
        sayNumber(@"numeric.lowerBound", numeric.lowerBound);
        sayNumber(@"numeric.upperBound", numeric.upperBound);
        say(@"numeric.gridlinePositions.count", @(numeric.gridlinePositions.count));
        say(@"numeric.valueDescriptionProvider(0.5)", numeric.valueDescriptionProvider(0.5));
        numeric.title = @"N2";
        say(@"numeric.attributedTitle.afterTitleSet", numeric.attributedTitle);
        numeric.attributedTitle = attributed(@"N3");
        say(@"numeric.title.afterAttributedSet", numeric.title);
        numeric.scaleType = 2;
        sayNumber(@"numeric.scaleType.set", numeric.scaleType);
        numeric.lowerBound = -5;
        numeric.upperBound = 5;
        sayNumber(@"numeric.lowerBound.set", numeric.lowerBound);
        sayNumber(@"numeric.upperBound.set", numeric.upperBound);
        numeric.gridlinePositions = @[@(-1), @0, @1];
        say(@"numeric.gridlinePositions.set.count", @(numeric.gridlinePositions.count));
        numeric.gridlinePositions = nil;
        say(@"numeric.gridlinePositions.nilled", numeric.gridlinePositions ? @"present" : @"(nil)");
        numeric.valueDescriptionProvider = describer(@"%.3f");
        say(@"numeric.valueDescriptionProvider.set(0.5)", numeric.valueDescriptionProvider(0.5));
        AXNumericDataAxisDescriptor *numericNoGridlines = [[AXNumericDataAxisDescriptor alloc]
            initWithAttributedTitle:attributed(@"M") lowerBound:0 upperBound:0 gridlinePositions:nil
               valueDescriptionProvider:describer(@"%.1f")];
        say(@"numericNoGridlines.title", numericNoGridlines.title);
        say(@"numericNoGridlines.gridlinePositions", numericNoGridlines.gridlinePositions ? @"present" : @"(nil)");
        sayNumber(@"numericNoGridlines.lowerBound", numericNoGridlines.lowerBound);
        numeric.attributedTitle = attributed(@"NA");
        numeric.gridlinePositions = @[@0, @1];
        AXNumericDataAxisDescriptor *numericCopy = [numeric copy];
        say(@"numeric.copy.title", numericCopy.title);
        say(@"numeric.copy.scaleType", @(numericCopy.scaleType));
        say(@"numeric.copy.lowerBound", @(numericCopy.lowerBound));
        say(@"numeric.copy.upperBound", @(numericCopy.upperBound));
        say(@"numeric.copy.gridlinePositions.count", @(numericCopy.gridlinePositions.count));
        say(@"numeric.copy.valueDescriptionProvider(0.5)", numericCopy.valueDescriptionProvider(0.5));
        same(@"numeric.copy.title.shared", numericCopy.title, numeric.title);
        same(@"numeric.copy.attributedTitle.shared", numericCopy.attributedTitle, numeric.attributedTitle);
        same(@"numeric.copy.gridlinePositions.shared", numericCopy.gridlinePositions, numeric.gridlinePositions);
        same(@"numeric.copy.provider.shared", numericCopy.valueDescriptionProvider, numeric.valueDescriptionProvider);

        AXCategoricalDataAxisDescriptor *ordered = [[AXCategoricalDataAxisDescriptor alloc] initWithTitle:@"C"
                                                                                            categoryOrder:@[@"a", @"b"]];
        say(@"categorical.title", ordered.title);
        say(@"categorical.attributedTitle", ordered.attributedTitle);
        say(@"categorical.categoryOrder.count", @(ordered.categoryOrder.count));
        say(@"categorical.categoryOrder.first", ordered.categoryOrder.firstObject);
        AXCategoricalDataAxisDescriptor *attributedOrdered = [[AXCategoricalDataAxisDescriptor alloc]
            initWithAttributedTitle:attributed(@"D") categoryOrder:@[@"x"]];
        say(@"categorical.attributed.title", attributedOrdered.title);
        say(@"categorical.attributed.order.count", @(attributedOrdered.categoryOrder.count));
        ordered.categoryOrder = @[@"a", @"b", @"c"];
        say(@"categorical.categoryOrder.set.count", @(ordered.categoryOrder.count));
        ordered.attributedTitle = attributed(@"CA");
        AXCategoricalDataAxisDescriptor *orderedCopy = [ordered copy];
        say(@"categorical.copy.order.count", @(orderedCopy.categoryOrder.count));
        same(@"categorical.copy.categoryOrder.shared", orderedCopy.categoryOrder, ordered.categoryOrder);
        same(@"categorical.copy.title.shared", orderedCopy.title, ordered.title);
        same(@"categorical.copy.attributedTitle.shared", orderedCopy.attributedTitle, ordered.attributedTitle);

        AXChartDescriptor *chart = [[AXChartDescriptor alloc] initWithTitle:@"Ch" summary:@"S"
                                                            xAxisDescriptor:ordered
                                                           yAxisDescriptor:numeric
                                                                      series:@[series]];
        say(@"chart.title", chart.title);
        say(@"chart.attributedTitle", chart.attributedTitle);
        say(@"chart.summary", chart.summary);
        sayNumber(@"chart.contentDirection", chart.contentDirection);
        say(@"chart.contentFrame", NSStringFromRect(chart.contentFrame));
        say(@"chart.series.count", @(chart.series.count));
        sayClass(@"chart.xAxis.class", object_getClass(chart.xAxis));
        sayClass(@"chart.yAxis.class", object_getClass(chart.yAxis));
        say(@"chart.additionalAxes", chart.additionalAxes ? @"present" : @"(nil)");
        chart.title = @"Ch2";
        say(@"chart.attributedTitle.afterTitleSet", chart.attributedTitle);
        chart.attributedTitle = attributed(@"Ch3");
        say(@"chart.title.afterAttributedSet", chart.title);
        chart.title = nil;
        say(@"chart.attributedTitle.afterTitleNilled", chart.attributedTitle ? @"present" : @"(nil)");
        chart.summary = @"S2";
        say(@"chart.summary.set", chart.summary);
        chart.summary = nil;
        say(@"chart.summary.nilled", chart.summary ?: @"(nil)");
        chart.contentDirection = 5;
        sayNumber(@"chart.contentDirection.set", chart.contentDirection);
        chart.contentFrame = CGRectMake(1, 2, 3, 4);
        say(@"chart.contentFrame.set", NSStringFromRect(chart.contentFrame));
        chart.series = @[attributedSeries];
        say(@"chart.series.set.count", @(chart.series.count));
        chart.series = nil;
        say(@"chart.series.nilled", chart.series ? @"present" : @"(nil)");
        chart.xAxis = numeric;
        sayClass(@"chart.xAxis.afterSet.class", object_getClass(chart.xAxis));
        chart.yAxis = numeric;
        sayClass(@"chart.yAxis.afterSet.class", object_getClass(chart.yAxis));
        chart.additionalAxes = @[ordered, numeric];
        say(@"chart.additionalAxes.set.count", @(chart.additionalAxes.count));
        chart.additionalAxes = nil;
        say(@"chart.additionalAxes.nilled", chart.additionalAxes ? @"present" : @"(nil)");
        AXChartDescriptor *attributedChart = [[AXChartDescriptor alloc] initWithAttributedTitle:attributed(@"AC")
                                                                                       summary:@"AS"
                                                                              xAxisDescriptor:numeric
                                                                             yAxisDescriptor:numeric
                                                                             additionalAxes:@[ordered]
                                                                                        series:@[attributedSeries]];
        say(@"chart.attributed.title", attributedChart.title);
        say(@"chart.attributed.attributedTitle", attributedChart.attributedTitle);
        say(@"chart.attributed.additionalAxes.count", @(attributedChart.additionalAxes.count));
        say(@"chart.attributed.series.count", @(attributedChart.series.count));
        AXChartDescriptor *axesChart = [[AXChartDescriptor alloc] initWithTitle:@"AC" summary:nil
                                                              xAxisDescriptor:ordered yAxisDescriptor:numeric
                                                             additionalAxes:@[ordered, numeric] series:@[]];
        say(@"chart.axes.additionalAxes.count", @(axesChart.additionalAxes.count));
        say(@"chart.axes.summary", axesChart.summary ?: @"(nil)");
        say(@"chart.axes.series.count", @(axesChart.series.count));
        chart.attributedTitle = attributed(@"CHA");
        chart.summary = @"COPY-S";
        chart.series = @[series, attributedSeries];
        chart.additionalAxes = @[ordered, numeric];
        AXChartDescriptor *chartCopy = [chart copy];
        say(@"chart.copy.title", chartCopy.title);
        say(@"chart.copy.series.count", @(chartCopy.series.count));
        sayClass(@"chart.copy.xAxis.class", object_getClass(chartCopy.xAxis));
        say(@"chart.copy.contentDirection", @(chartCopy.contentDirection));
        say(@"chart.copy.contentFrame", NSStringFromRect(chartCopy.contentFrame));
        same(@"chart.copy.series.shared", chartCopy.series, chart.series);
        same(@"chart.copy.xAxis.shared", chartCopy.xAxis, chart.xAxis);
        same(@"chart.copy.yAxis.shared", chartCopy.yAxis, chart.yAxis);
        same(@"chart.copy.additionalAxes.shared", chartCopy.additionalAxes, chart.additionalAxes);
        same(@"chart.copy.title.shared", chartCopy.title, chart.title);
        same(@"chart.copy.attributedTitle.shared", chartCopy.attributedTitle, chart.attributedTitle);
        same(@"chart.copy.summary.shared", chartCopy.summary, chart.summary);

        AXDataPointValue *given = [AXDataPointValue valueWithNumber:42];
        AXDataPoint *setterPoint = [[AXDataPoint alloc] initWithX:number y:nil additionalValues:nil label:nil];
        setterPoint.xValue = given;
        same(@"setter.point.xValue", setterPoint.xValue, given);
        setterPoint.yValue = category;
        same(@"setter.point.yValue", setterPoint.yValue, category);
        setterPoint.additionalValues = @[given];
        same(@"setter.point.additionalValues", setterPoint.additionalValues, @[given].firstObject);
        setterPoint.label = @"SL";
        say(@"setter.point.label", setterPoint.label);
        say(@"setter.point.label.attributed", setterPoint.attributedLabel);
        NSAttributedString *givenAttributed = attributed(@"SA");
        setterPoint.attributedLabel = givenAttributed;
        say(@"setter.point.attributedLabel", setterPoint.attributedLabel);
        say(@"setter.point.attributedLabel.plain", setterPoint.label);

        AXDataSeriesDescriptor *setterSeries = [[AXDataSeriesDescriptor alloc] initWithName:@"S" isContinuous:NO dataPoints:@[]];
        setterSeries.dataPoints = @[point];
        same(@"setter.series.dataPoints", setterSeries.dataPoints.firstObject, point);
        setterSeries.isContinuous = YES;
        say(@"setter.series.isContinuous", @(setterSeries.isContinuous));
        setterSeries.name = @"SN";
        say(@"setter.series.name", setterSeries.name);
        say(@"setter.series.name.attributed", setterSeries.attributedName);
        setterSeries.attributedName = givenAttributed;
        say(@"setter.series.attributedName.name", setterSeries.name);

        AXCategoricalDataAxisDescriptor *setterCategorical = [[AXCategoricalDataAxisDescriptor alloc] initWithTitle:@"T"
                                                                                                     categoryOrder:@[]];
        setterCategorical.categoryOrder = @[@"one", @"two"];
        say(@"setter.categorical.categoryOrder.count", @(setterCategorical.categoryOrder.count));
        say(@"setter.categorical.categoryOrder.first", setterCategorical.categoryOrder.firstObject);
        setterCategorical.title = @"CT";
        say(@"setter.categorical.title", setterCategorical.title);
        say(@"setter.categorical.title.attributed", setterCategorical.attributedTitle);
        setterCategorical.attributedTitle = givenAttributed;
        say(@"setter.categorical.attributedTitle.plain", setterCategorical.title);

        AXNumericDataAxisDescriptor *setterNumeric = [[AXNumericDataAxisDescriptor alloc] initWithTitle:@"T" lowerBound:0
                                                                                          upperBound:1 gridlinePositions:@[]
                                                                          valueDescriptionProvider:describer(@"%.1f")];
        setterNumeric.scaleType = 2;
        say(@"setter.numeric.scaleType", @(setterNumeric.scaleType));
        setterNumeric.lowerBound = -2;
        say(@"setter.numeric.lowerBound", @(setterNumeric.lowerBound));
        setterNumeric.upperBound = 8;
        say(@"setter.numeric.upperBound", @(setterNumeric.upperBound));
        setterNumeric.gridlinePositions = @[@1, @2, @3];
        say(@"setter.numeric.gridlinePositions.count", @(setterNumeric.gridlinePositions.count));
        setterNumeric.valueDescriptionProvider = describer(@"%.4f");
        say(@"setter.numeric.valueDescriptionProvider", setterNumeric.valueDescriptionProvider(1));
        setterNumeric.title = @"NT";
        say(@"setter.numeric.title", setterNumeric.title);
        setterNumeric.attributedTitle = givenAttributed;
        say(@"setter.numeric.attributedTitle.plain", setterNumeric.title);

        AXChartDescriptor *setterChart = [[AXChartDescriptor alloc] initWithTitle:@"T" summary:nil xAxisDescriptor:ordered
                                                                             yAxisDescriptor:numeric additionalAxes:nil series:@[]];
        setterChart.title = @"CT";
        say(@"setter.chart.title", setterChart.title);
        say(@"setter.chart.title.attributed", setterChart.attributedTitle);
        setterChart.attributedTitle = givenAttributed;
        say(@"setter.chart.attributedTitle.plain", setterChart.title);
        setterChart.summary = @"CS";
        say(@"setter.chart.summary", setterChart.summary);
        setterChart.contentDirection = 4;
        say(@"setter.chart.contentDirection", @(setterChart.contentDirection));
        setterChart.contentFrame = CGRectMake(5, 6, 7, 8);
        say(@"setter.chart.contentFrame", NSStringFromRect(setterChart.contentFrame));
        setterChart.series = @[series];
        say(@"setter.chart.series.count", @(setterChart.series.count));
        same(@"setter.chart.series", setterChart.series.firstObject, series);
        setterChart.xAxis = numeric;
        same(@"setter.chart.xAxis", setterChart.xAxis, numeric);
        setterChart.additionalAxes = @[ordered, numeric];
        say(@"setter.chart.additionalAxes.count", @(setterChart.additionalAxes.count));
        same(@"setter.chart.additionalAxes", setterChart.additionalAxes.firstObject, ordered);

        RevenantCaseAdopter *adopter = [[RevenantCaseAdopter alloc] init];
        adopter.title = @"AT";
        adopter.attributedTitle = attributed(@"AA");
        adopter.accessibilityChartDescriptor = chart;
        say(@"adopter.conformsToAXChart", [adopter conformsToProtocol:@protocol(AXChart)] ? @"yes" : @"no");
        say(@"adopter.conformsToAXDataAxisDescriptor",
            [adopter conformsToProtocol:@protocol(AXDataAxisDescriptor)] ? @"yes" : @"no");
        say(@"adopter.title", adopter.title);
        say(@"adopter.attributedTitle", adopter.attributedTitle);
        say(@"adopter.accessibilityChartDescriptor.series.count", @(adopter.accessibilityChartDescriptor.series.count));
        say(@"adopter.description", adopter);
        Protocol *chartProtocol = objc_getProtocol(AXCHART_PROTOCOL.UTF8String);
        say(@"declaration.AXChart.found", chartProtocol ? @"yes" : @"no");
        say(@"declaration.AXChart.name", name([NSString stringWithUTF8String:protocol_getName(chartProtocol)]));
        if (chartProtocol) {
            unsigned count = 0;
            struct objc_method_description *members = protocol_copyMethodDescriptionList(chartProtocol, YES, YES, &count);
            NSMutableArray *names = [NSMutableArray array];
            for (unsigned i = 0; i < count; i++) [names addObject:NSStringFromSelector(members[i].name)];
            [names sortUsingSelector:@selector(compare:)];
            for (unsigned i = 0; i < names.count; i++)
                say([NSString stringWithFormat:@"declaration.AXChart.member.%u", i], names[i]);
            free(members);
        }
        Protocol *axisProtocol = objc_getProtocol(AXDATAAXISDESCRIPTOR_PROTOCOL.UTF8String);
        say(@"declaration.AXDataAxisDescriptor.found", axisProtocol ? @"yes" : @"no");
        sayYes(@"declaration.AXDataAxisDescriptor.adoptsNSCopying",
               protocol_conformsToProtocol(axisProtocol, @protocol(NSCopying)));
        if (axisProtocol) {
            unsigned count = 0;
            struct objc_method_description *members = protocol_copyMethodDescriptionList(axisProtocol, YES, YES, &count);
            NSMutableArray *names = [NSMutableArray array];
            for (unsigned i = 0; i < count; i++) [names addObject:NSStringFromSelector(members[i].name)];
            [names sortUsingSelector:@selector(compare:)];
            for (unsigned i = 0; i < names.count; i++)
                say([NSString stringWithFormat:@"declaration.AXDataAxisDescriptor.member.%u", i], names[i]);
            free(members);
        }
        id<AXDataAxisDescriptor> asProtocol = numeric;
        say(@"declaration.AXDataAxisDescriptor.title", asProtocol.title);
        say(@"declaration.AXDataAxisDescriptor.attributedTitle", asProtocol.attributedTitle);
        sayYes(@"declaration.AXDataAxisDescriptor.conforms",
               [numeric conformsToProtocol:@protocol(AXDataAxisDescriptor)]);

        sayYes(@"graph.start.isClassMethod", class_getClassMethod([AXLiveAudioGraph class], @selector(start)) != NULL);
        sayYes(@"graph.updateValue.isClassMethod",
               class_getClassMethod([AXLiveAudioGraph class], @selector(updateValue:)) != NULL);
        sayYes(@"graph.stop.isClassMethod", class_getClassMethod([AXLiveAudioGraph class], @selector(stop)) != NULL);
        unsigned ivars = 0;
        class_copyIvarList([AXLiveAudioGraph class], &ivars);
        say(@"graph.ivarCount", @(ivars));
        say(@"graph.instanceSize", @(class_getInstanceSize([AXLiveAudioGraph class])));
        sayClass(@"graph.instance.class", [[[AXLiveAudioGraph alloc] init] class]);
        NSUInteger starts = 0, updates = 0, stops = 0;
        for (int i = 0; i < 3; i++) {
            [AXLiveAudioGraph start];
            starts++;
        }
        for (int i = 0; i < 4; i++) {
            [AXLiveAudioGraph updateValue:i / 4.0];
            updates++;
        }
        for (int i = 0; i < 2; i++) {
            [AXLiveAudioGraph stop];
            stops++;
        }
        [AXLiveAudioGraph updateValue:0.25];
        updates++;
        say(@"graph.calls.start", @(starts));
        say(@"graph.calls.updateValue", @(updates));
        say(@"graph.calls.stop", @(stops));
        say(@"graph.calls.survived", @"yes");

        sayClass(@"class.AXChartDescriptor", [AXChartDescriptor class]);
        sayClass(@"class.AXDataSeriesDescriptor", [AXDataSeriesDescriptor class]);
        sayClass(@"class.AXDataPoint", [AXDataPoint class]);
        sayClass(@"class.AXDataPointValue", [AXDataPointValue class]);
        sayClass(@"class.AXNumericDataAxisDescriptor", [AXNumericDataAxisDescriptor class]);
        sayClass(@"class.AXCategoricalDataAxisDescriptor", [AXCategoricalDataAxisDescriptor class]);
        sayClass(@"class.AXLiveAudioGraph", [AXLiveAudioGraph class]);
        say(@"class.superclass.AXChartDescriptor", [NSStringFromClass([AXChartDescriptor superclass]) copy]);
        say(@"class.superclass.AXDataPointValue", [NSStringFromClass([AXDataPointValue superclass]) copy]);
        say(@"class.superclass.AXLiveAudioGraph", [NSStringFromClass([AXLiveAudioGraph superclass]) copy]);
        sayYes(@"class.copies.AXChartDescriptor",
               [[AXChartDescriptor class] instancesRespondToSelector:@selector(copyWithZone:)]);
        sayYes(@"class.copies.AXDataPointValue",
               [[AXDataPointValue class] instancesRespondToSelector:@selector(copyWithZone:)]);
        sayYes(@"class.adopts.AXNumericDataAxisDescriptor",
               [[AXNumericDataAxisDescriptor class] conformsToProtocol:@protocol(AXDataAxisDescriptor)]);
        sayYes(@"class.adopts.AXCategoricalDataAxisDescriptor",
               [[AXCategoricalDataAxisDescriptor class] conformsToProtocol:@protocol(AXDataAxisDescriptor)]);
    }
    return 0;
}
