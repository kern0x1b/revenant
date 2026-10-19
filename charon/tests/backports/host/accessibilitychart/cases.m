// accessibilitychart - the chart and data classes of iOS 15.0 against the host's own.
//
// One source, two programs. The host half links the system's Accessibility.framework and gets Apple's
// classes; the port half is built with every class name remapped to a name the system does not use
// (so renaming one does not rename the system's declaration) and links only Foundation, and its
// classes are the port's own CharonChartDescriptors.m. Each prints "label<TAB>value" per case in the
// same order, and the two outputs are diffed by run.sh.
//
// Nothing printed here is an address: a pointer differs between the two programs and between two runs.
// What a pointer is for is *whether two values are the same object*, and that is the same question on
// both sides, so every shared field is printed as shared-or-copied through a comparison inside the
// program, and the addresses stay out of the output. A port that handed back copies where the system
// hands back the very objects is a defect this is here to catch, and it is caught by the
// `*.shared` and `*.copies` lines rather than by any value.
//
// Two things cannot be compared and the script says which, because a diff that pretends to cover them
// covers nothing:
//   * the live audio graph publishes sound, and a program cannot read sound. What is held for it is the
//     shape of the class and how many times each of its three members was called, which both sides can
//     answer; how many lines those calls wrote is the port's own log, and run.sh counts that against the
//     call counts printed here.
//   * a log line is not a value, so the once-only part of it is not a comparison: it is a count the
//     runner checks for the port alone, and the reason the host has no such log is in the script.
//
// Every property of every class is asked of its own setter as well as of its constructor, one line
// each, so a setter that does nothing is caught by the line that follows the call and not by nothing.

#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

// The class below prints a class name through name(), which is defined below it with the rest of the
// helpers, so it is named here first.
static NSString *name(NSString *spelling);

// A class that adopts the two protocols, at file scope so it is in both halves. It is what makes the
// protocol cases two-sided: the system's own Accessibility image does not list AXChart in its protocol
// list, so without a class that adopts it the name resolves on one side and not the other and those
// cases would be comparing the case's own file with itself. A caller adopts a protocol to get its
// metadata, and this is that; the port's own generated protocol object is the other half of the same
// thing, and run.sh gives it to the port half only.
@interface CharonCaseAdopter : NSObject <AXChart, AXDataAxisDescriptor> {
    // A class that adopts a protocol has to answer it, so the adopter stores the three members the two
    // protocols name rather than declaring them and doing nothing. The two cases above the protocol
    // declarations then ask a class something it really answers, on both sides.
    AXChartDescriptor *_chartDescriptor;
    NSString *_title;
    NSAttributedString *_attributedTitle;
}
@property (nonatomic, strong) AXChartDescriptor *accessibilityChartDescriptor;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSAttributedString *attributedTitle;
@end

@implementation CharonCaseAdopter

@synthesize accessibilityChartDescriptor = _chartDescriptor;
@synthesize title = _title;
@synthesize attributedTitle = _attributedTitle;

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CharonCaseAdopter title %@ attributed %@ chart %@ series %lu>",
            _title ?: @"(none)",
            _attributedTitle ?: @"(none)",
            _chartDescriptor ? name(NSStringFromClass([_chartDescriptor class])) : @"(none)",
            (unsigned long)(_chartDescriptor ? _chartDescriptor.series.count : 0)];
}

@end

// The protocol names are looked up by string, and a string is not remapped by -D, so the port half is
// told its own spelling.
#ifndef AXCHART_PROTOCOL
#define AXCHART_PROTOCOL @"AXChart"
#endif
#ifndef AXDATAAXISDESCRIPTOR_PROTOCOL
#define AXDATAAXISDESCRIPTOR_PROTOCOL @"AXDataAxisDescriptor"
#endif

// The port half is built with every class name remapped to a name the system does not use, so a class
// name is the one thing the two halves cannot share. It is compared by the name both of them agree
// on, which is the one with the port's marker taken off the front - the classes are otherwise the same
// classes, and the rest of every line in this file is the behaviour rather than the spelling.
static NSString *name(NSString *spelling)
{
    if (spelling.length > [@"CharonPort" length] &&
        [[spelling substringToIndex:[@"CharonPort" length]] isEqualToString:@"CharonPort"]) {
        return [spelling substringFromIndex:[@"CharonPort" length]];
    }
    return spelling;
}

// One case per line: a value is folded onto one line before it is printed, because an attributed
// string's description carries the line break its (empty) attributes dictionary prints across two
// lines, and a case that is two lines cannot be lined up with the other side's. What is compared is
// the characters and the attribute dictionary, not where the line broke.
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

// Whether two values are the same object, answered the same way on both sides and printed as a word,
// so the addresses stay out of the output and a copy of the port cannot be told from a copy of the
// system by anything but the answer.
//
// "both-nil" is a vacuous answer and the six probes that produced it are the reason every copy block
// sets the fields it will be asked about before it makes the copy: two nils are equal, so a port that
// dropped the field entirely printed the same line as one that shared it. A probe that answers
// "both-nil" is not a check, and the six mutants that drop one of the six fields are what says so.
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
        // --- AXDataPointValue: two independent faces, and the two factories.
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
        // The one field a value's copy can be asked about by identity: its category.
        same(@"value.copy.category.shared", numberCopy.category, number.category);

        // --- AXDataPoint: three initialisers, and what each leaves nil.
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
        // Everything the copy is asked about is set first, because a copy of a point whose label or y
        // value or additional values was set to nil answers "both-nil" on both sides and the identity
        // probe asks nothing at all. Six of the twenty-three share probes were vacuous in the first
        // version for exactly this reason, and a port that dropped any of the six answered the same.
        point.attributedLabel = attributed(@"PA");
        point.yValue = category;
        point.additionalValues = @[number, category];
        AXDataPoint *pointCopy = [point copy];
        sayClass(@"point.copy.xValue.class", [pointCopy.xValue class]);
        say(@"point.copy.label", pointCopy.label ?: @"(nil)");
        // Five fields, and the one that is not shared: the plain label is the original's own string and
        // the attributed one is a new string, which is why this class's copy is built through the
        // setter. A port that shared both would be told apart here.
        same(@"point.copy.xValue.shared", pointCopy.xValue, point.xValue);
        same(@"point.copy.yValue.shared", pointCopy.yValue, point.yValue);
        same(@"point.copy.additionalValues.shared", pointCopy.additionalValues, point.additionalValues);
        same(@"point.copy.label.shared", pointCopy.label, point.label);
        same(@"point.copy.attributedLabel.shared", pointCopy.attributedLabel, point.attributedLabel);

        // --- AXDataSeriesDescriptor: two initialisers, one name in two faces.
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

        // --- AXNumericDataAxisDescriptor: both initialisers, every property, the block called.
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
        // The gridline positions were set to nil above, so a copy of that axis has none to share and the
        // probe answers "both-nil"; they are set back before the copy so the question is real.
        numeric.attributedTitle = attributed(@"NA");
        numeric.gridlinePositions = @[@0, @1];
        AXNumericDataAxisDescriptor *numericCopy = [numeric copy];
        say(@"numeric.copy.title", numericCopy.title);
        // The scale is the field the system's own copy drops, so this answers the linear case whatever
        // the original was set to. Nothing declares that difference here any more: the case holds the
        // parity with a mutant that sets the scale again, and that mutant has to turn this line red.
        say(@"numeric.copy.scaleType", @(numericCopy.scaleType));
        say(@"numeric.copy.lowerBound", @(numericCopy.lowerBound));
        say(@"numeric.copy.upperBound", @(numericCopy.upperBound));
        say(@"numeric.copy.gridlinePositions.count", @(numericCopy.gridlinePositions.count));
        say(@"numeric.copy.valueDescriptionProvider(0.5)", numericCopy.valueDescriptionProvider(0.5));
        same(@"numeric.copy.title.shared", numericCopy.title, numeric.title);
        same(@"numeric.copy.attributedTitle.shared", numericCopy.attributedTitle, numeric.attributedTitle);
        same(@"numeric.copy.gridlinePositions.shared", numericCopy.gridlinePositions, numeric.gridlinePositions);
        same(@"numeric.copy.provider.shared", numericCopy.valueDescriptionProvider, numeric.valueDescriptionProvider);

        // --- AXCategoricalDataAxisDescriptor: both initialisers, the order, the copy.
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

        // --- AXChartDescriptor: the four initialisers, and the two values none of them takes.
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
        // Three more: the summary, the series and the additional axes were all set to nil above, and a
        // copy of a chart with none of them has nothing to share. The identity probes below are about
        // whether the copy answers the very objects, and that question needs the objects to be there.
        chart.attributedTitle = attributed(@"CHA");
        chart.summary = @"COPY-S";
        chart.series = @[series, attributedSeries];
        chart.additionalAxes = @[ordered, numeric];
        AXChartDescriptor *chartCopy = [chart copy];
        say(@"chart.copy.title", chartCopy.title);
        say(@"chart.copy.series.count", @(chartCopy.series.count));
        sayClass(@"chart.copy.xAxis.class", object_getClass(chartCopy.xAxis));
        // The direction and the frame are the two fields the system's own copy drops, so a copy here
        // answers the zero case and a zero rectangle whatever the original was set to. Two mutants hold
        // that: one sets the direction again, one sets the frame, and each has to turn these two lines
        // red.
        say(@"chart.copy.contentDirection", @(chartCopy.contentDirection));
        say(@"chart.copy.contentFrame", NSStringFromRect(chartCopy.contentFrame));
        same(@"chart.copy.series.shared", chartCopy.series, chart.series);
        same(@"chart.copy.xAxis.shared", chartCopy.xAxis, chart.xAxis);
        same(@"chart.copy.yAxis.shared", chartCopy.yAxis, chart.yAxis);
        same(@"chart.copy.additionalAxes.shared", chartCopy.additionalAxes, chart.additionalAxes);
        same(@"chart.copy.title.shared", chartCopy.title, chart.title);
        same(@"chart.copy.attributedTitle.shared", chartCopy.attributedTitle, chart.attributedTitle);
        same(@"chart.copy.summary.shared", chartCopy.summary, chart.summary);

        // --- Every setter, asked of its own getter and of the object it was given. A setter that does
        // nothing, or that answers a copy where the system answers the very object, is caught by the
        // line that follows the call: a case that only read the constructors could not see either.

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

        // --- The two protocols. The two adopter cases are behaviour and come first: they ask whether a
        // class that adopts a protocol answers conformsToProtocol:, which on the port is the port's own
        // protocol metadata - the thing the two implemented protocol rows claim - and on the host is the
        // framework's own. The cases after them check a *declaration* and not the port's code: their
        // members come from whichever header each side compiled against, so a change to Apple's header
        // moves them and nothing in packages/ can. They are labelled declaration.* and run.sh counts them
        // apart from the behaviour cases for that reason, and the adopter class above is what puts each
        // side's own metadata into the program.
        CharonCaseAdopter *adopter = [[CharonCaseAdopter alloc] init];
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
            // Sorted and numbered, so each member is a case of its own and the order is the same on
            // both sides; a repeated label would leave the two outputs impossible to line up.
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
        // The two axis classes of the port answer the protocol's own members, so the two are held
        // together here rather than only through the class's own property names.
        id<AXDataAxisDescriptor> asProtocol = numeric;
        say(@"declaration.AXDataAxisDescriptor.title", asProtocol.title);
        say(@"declaration.AXDataAxisDescriptor.attributedTitle", asProtocol.attributedTitle);
        sayYes(@"declaration.AXDataAxisDescriptor.conforms",
               [numeric conformsToProtocol:@protocol(AXDataAxisDescriptor)]);

        // --- AXLiveAudioGraph: the shape of the class, and that its three calls do not raise.
        // The values it publishes are sound, which a program cannot read, so nothing about them is
        // compared; what is compared is the class both sides expose and the absence of any state.
        sayYes(@"graph.start.isClassMethod", class_getClassMethod([AXLiveAudioGraph class], @selector(start)) != NULL);
        sayYes(@"graph.updateValue.isClassMethod",
               class_getClassMethod([AXLiveAudioGraph class], @selector(updateValue:)) != NULL);
        sayYes(@"graph.stop.isClassMethod", class_getClassMethod([AXLiveAudioGraph class], @selector(stop)) != NULL);
        unsigned ivars = 0;
        class_copyIvarList([AXLiveAudioGraph class], &ivars);
        say(@"graph.ivarCount", @(ivars));
        say(@"graph.instanceSize", @(class_getInstanceSize([AXLiveAudioGraph class])));
        sayClass(@"graph.instance.class", [[[AXLiveAudioGraph alloc] init] class]);
        // Each member called more than once, and the number of calls printed as a number: the once-only
        // part of the inert contract says one line per member however many times it is called, and
        // run.sh counts the port's own log lines against exactly these numbers.
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

        // --- The seven classes the registry rows name are all there, under the name both halves use.
        // A lookup by string would be nil in the port half, whose classes are the port's own names, so
        // the class object itself is what is named here and the lookup is on the other side of the gate
        // (the registry check reads the classes out of the built objects).
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
