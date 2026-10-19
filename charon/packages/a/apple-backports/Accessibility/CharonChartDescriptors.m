//
//  CharonChartDescriptors.m
//  Accessibility
//
//  The chart and data classes of iOS 15.0, in one object because one object carries the API of one
//  release and all of them arrived together: seven classes, of which six are containers, and the two
//  protocols whose rows are answered by the metadata object the build generates from them. The release
//  does not have any of them
//  (tools/intents/measure-release-carries.lua: 6.1.3 armv7 carries 0 of the framework's 30 classes,
//  with the control symbol found, and so do 4.3 and 3.0), so every band builds this file whole.
//
//  The value each one keeps is the value it was given, which is the whole of its behaviour, and every
//  rule below is one the host's own Accessibility.framework was measured to answer - the cases and
//  their outputs are in facts/Accessibility/Accessibility.md and the check that holds them to it is
//  tests/backports/host/accessibilitychart/run.sh.
//
//  Five of those rules are not what the header's spelling suggests, and each was measured rather than
//  read:
//
//  * **A name and an attributed name are one value.** Setting either face of a chart's title, a
//    series' name, a point's label or an axis' title leaves the other face holding the same
//    characters, and setting one to nil leaves the other nil. The two properties are separate
//    readwrite properties in the header and two accessors each; they are kept in step here.
//  * **A data point value's two faces are independent.** The factory for a number leaves the category
//    nil, the factory for a category leaves the number 0, and setting one afterwards does not disturb
//    the other.
//  * **-copy shares its objects, and one class's copy is the exception.** A copy of a chart, a series,
//    an axis or a value answers the very array, the very axis and the very string its original does,
//    including both faces of the name pair. A copy of a data point shares the plain label and answers a
//    *new* attributed string, so that one copy is built through the pair's own setter and the other
//    four assign the pair. Measured by pointer identity, case by case, and the four that assign it are
//    the four that would otherwise have rebuilt the attributed face and been told apart here.
//  * **-copy drops the value-typed fields.** A copy of a chart answers the zero case of the direction
//    and a zero rectangle, and a copy of a numeric axis answers the linear case, because the system's
//    own -copyWithZone: drops exactly those three and keeps every object-typed field. This is
//    deliberate: the family carries the system's behaviour, and a copy that answered a zero rectangle
//    for a frame the caller had set would be a port that is better than the system and would hide the
//    difference. What a copy that kept them would be good for is in
//    .agent-work/handoffs/better-than-system-accessibility.md, and the two objects' own answers are
//    pinned by three mutants of the case.
//  * **What a setter keeps.** A setter of an object-typed property keeps the very object it was given -
//    an immutable string or an immutable array, whose -copy is itself - and a setter of a data point's
//    x or y value answers a copy, because that class has a -copy of its own. Both measured per
//    property by the case.
//
//  The seventh class, AXLiveAudioGraph, is the one member of this group that asks for something this
//  release does not have: a graph an assistive technology renders as sound. Nothing on 6.1.3
//  publishes one - the release's whole Accessibility surface is the AXS* preference library, measured,
//  with no publisher in it - so the three class methods carry the class and say once each that there
//  is nothing drawing the graph. The class answers nothing else, holds no state (the host's instance
//  has no ivars at all, measured) and raises nothing: the host accepts a value outside the unit range
//  and a call after +stop without complaint, so neither does this.
//

#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>

#import "../CharonSayOnce.h"

#pragma mark - AXDataPointValue

@implementation AXDataPointValue {
    // Two independent values, because the host keeps them independent: the number factory leaves the
    // category nil and the category factory leaves the number at its zero, and a write to one does
    // not move the other. The number is a plain double, so its zero is 0 and not nil.
    double _number;
    NSString *_category;
}

+ (instancetype)valueWithNumber:(double)number
{
    AXDataPointValue *value = [[AXDataPointValue alloc] init];
    value->_number = number;
    return value;
}

+ (instancetype)valueWithCategory:(NSString *)category
{
    AXDataPointValue *value = [[AXDataPointValue alloc] init];
    value->_category = [category copy];
    return value;
}

- (double)number
{
    return _number;
}

- (void)setNumber:(double)number
{
    _number = number;
}

- (NSString *)category
{
    return _category;
}

- (void)setCategory:(NSString *)category
{
    _category = [category copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    // Shared, measured by pointer identity: the value a copy answers for its category is the original's
    // own string, and the number is a double.
    AXDataPointValue *copy = [[AXDataPointValue allocWithZone:zone] init];
    copy->_number = _number;
    copy->_category = _category;
    return copy;
}

@end

#pragma mark - AXDataPoint

@implementation AXDataPoint {
    AXDataPointValue *_xValue;
    AXDataPointValue *_yValue;
    NSArray<AXDataPointValue *> *_additionalValues;
    // A label and an attributed label are one value in two faces, kept in step by the two setters
    // below; the host answers the same characters through either one, and a nil through either one.
    NSString *_label;
    NSAttributedString *_attributedLabel;
}

// The header names one designated initialiser for this class, the one that takes a label, and
// marks -init unavailable, so the two shorter ones below are conveniences that reach it with a nil
// for what it takes and it is the one that calls up to NSObject. That is also the shape the measured
// answers need: the two-argument initialiser leaves the additional values, the label and the
// attributed label nil, which is what a nil for both of them gives.

- (instancetype)initWithX:(AXDataPointValue *)xValue y:(AXDataPointValue *)yValue
{
    return [self initWithX:xValue y:yValue additionalValues:nil label:nil];
}

- (instancetype)initWithX:(AXDataPointValue *)xValue
                         y:(AXDataPointValue *)yValue
          additionalValues:(NSArray<AXDataPointValue *> *)additionalValues
{
    return [self initWithX:xValue y:yValue additionalValues:additionalValues label:nil];
}

- (instancetype)initWithX:(AXDataPointValue *)xValue
                         y:(AXDataPointValue *)yValue
          additionalValues:(NSArray<AXDataPointValue *> *)additionalValues
                     label:(NSString *)label
{
    self = [super init];
    if (self) {
        _xValue = xValue;
        _yValue = yValue;
        // What it was given, nil included: the host answers nil here, and an empty array stays an
        // empty array. Nothing is substituted for either.
        _additionalValues = [additionalValues copy];
        [self setLabel:label];
    }
    return self;
}

- (AXDataPointValue *)xValue
{
    return _xValue;
}

- (void)setXValue:(AXDataPointValue *)xValue
{
    _xValue = [xValue copy];
}

- (AXDataPointValue *)yValue
{
    return _yValue;
}

- (void)setYValue:(AXDataPointValue *)yValue
{
    _yValue = [yValue copy];
}

- (NSArray<AXDataPointValue *> *)additionalValues
{
    return _additionalValues;
}

- (void)setAdditionalValues:(NSArray<AXDataPointValue *> *)additionalValues
{
    _additionalValues = [additionalValues copy];
}

- (NSString *)label
{
    return _label;
}

- (void)setLabel:(NSString *)label
{
    _label = [label copy];
    _attributedLabel = label ? [[NSAttributedString alloc] initWithString:label] : nil;
}

- (NSAttributedString *)attributedLabel
{
    return _attributedLabel;
}

- (void)setAttributedLabel:(NSAttributedString *)attributedLabel
{
    _attributedLabel = [attributedLabel copy];
    _label = [attributedLabel.string copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    AXDataPoint *copy = [[AXDataPoint allocWithZone:zone] initWithX:_xValue y:_yValue];
    // Shared, measured: the x value, the y value, the additional values and the plain label are the
    // original's own objects. The attributed label is NOT, and the system's copy is the one class here
    // whose copy answers a different object for the attributed face - so this copy is built through the
    // pair's own setter, which is what makes the attributed string a new one and leaves the plain label
    // the very string it was, both measured by pointer identity.
    copy->_additionalValues = _additionalValues;
    [copy setLabel:_label];
    return copy;
}

@end

#pragma mark - AXDataSeriesDescriptor

@implementation AXDataSeriesDescriptor {
    // One value in two faces again, for the series' name.
    NSString *_name;
    NSAttributedString *_attributedName;
    BOOL _isContinuous;
    NSArray<AXDataPoint *> *_dataPoints;
}

- (instancetype)initWithName:(NSString *)name
               isContinuous:(BOOL)isContinuous
                  dataPoints:(NSArray<AXDataPoint *> *)dataPoints
{
    self = [super init];
    if (self) {
        [self setName:name];
        _isContinuous = isContinuous;
        _dataPoints = [dataPoints copy];
    }
    return self;
}

- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName
                         isContinuous:(BOOL)isContinuous
                            dataPoints:(NSArray<AXDataPoint *> *)dataPoints
{
    self = [super init];
    if (self) {
        [self setAttributedName:attributedName];
        _isContinuous = isContinuous;
        _dataPoints = [dataPoints copy];
    }
    return self;
}

- (NSString *)name
{
    return _name;
}

- (void)setName:(NSString *)name
{
    _name = [name copy];
    _attributedName = name ? [[NSAttributedString alloc] initWithString:name] : nil;
}

- (NSAttributedString *)attributedName
{
    return _attributedName;
}

- (void)setAttributedName:(NSAttributedString *)attributedName
{
    _attributedName = [attributedName copy];
    _name = [attributedName.string copy];
}

- (BOOL)isContinuous
{
    return _isContinuous;
}

- (void)setContinuous:(BOOL)isContinuous
{
    _isContinuous = isContinuous;
}

- (NSArray<AXDataPoint *> *)dataPoints
{
    return _dataPoints;
}

- (void)setDataPoints:(NSArray<AXDataPoint *> *)dataPoints
{
    _dataPoints = [dataPoints copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    // Shared, measured by pointer identity: the points array is the original's own, and so are the name
    // and the attributed name. The pair is assigned rather than rebuilt through the name's setter,
    // because the setter derives the attributed face and would answer a new string where the system's
    // copy answers the original's own. A data point's copy is the other way round and says so.
    AXDataSeriesDescriptor *copy = [[AXDataSeriesDescriptor allocWithZone:zone] initWithName:_name
                                                                              isContinuous:_isContinuous
                                                                                 dataPoints:_dataPoints];
    copy->_attributedName = _attributedName;
    return copy;
}

@end

// The title pair of the two axis classes is written out in each of them rather than shared through a
// helper. It cannot go in a C function, which cannot reach an ivar, and it cannot go in a base class,
// which would add a class to the library that the registry has no row for. What it could go in is a
// helper object, and four accessors are less machinery than that.

#pragma mark - AXNumericDataAxisDescriptor

@implementation AXNumericDataAxisDescriptor {
    NSString *_title;
    NSAttributedString *_attributedTitle;
    AXNumericDataAxisDescriptorScale _scaleType;
    double _lowerBound;
    double _upperBound;
    NSArray<NSNumber *> *_gridlinePositions;
    NSString *(^_valueDescriptionProvider)(double);
}

- (instancetype)initWithTitle:(NSString *)title
                   lowerBound:(double)lowerBound
                   upperBound:(double)upperBound
             gridlinePositions:(NSArray<NSNumber *> *)gridlinePositions
     valueDescriptionProvider:(NSString *(^)(double))valueDescriptionProvider
{
    self = [super init];
    if (self) {
        [self setTitle:title];
        _lowerBound = lowerBound;
        _upperBound = upperBound;
        // Nullable in the initialiser, and nil in is nil out: the host answers nil for a nil here and
        // nil again after a set to nil, where the series' array is the other way round.
        _gridlinePositions = [gridlinePositions copy];
        _valueDescriptionProvider = [valueDescriptionProvider copy];
    }
    return self;
}

- (instancetype)initWithAttributedTitle:(NSAttributedString *)attributedTitle
                             lowerBound:(double)lowerBound
                             upperBound:(double)upperBound
                       gridlinePositions:(NSArray<NSNumber *> *)gridlinePositions
               valueDescriptionProvider:(NSString *(^)(double))valueDescriptionProvider
{
    self = [super init];
    if (self) {
        [self setAttributedTitle:attributedTitle];
        _lowerBound = lowerBound;
        _upperBound = upperBound;
        _gridlinePositions = [gridlinePositions copy];
        _valueDescriptionProvider = [valueDescriptionProvider copy];
    }
    return self;
}

- (NSString *)title
{
    return _title;
}

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
    _attributedTitle = title ? [[NSAttributedString alloc] initWithString:title] : nil;
}

- (NSAttributedString *)attributedTitle
{
    return _attributedTitle;
}

- (void)setAttributedTitle:(NSAttributedString *)attributedTitle
{
    _attributedTitle = [attributedTitle copy];
    _title = [attributedTitle.string copy];
}

- (AXNumericDataAxisDescriptorScale)scaleType
{
    return _scaleType;
}

- (void)setScaleType:(AXNumericDataAxisDescriptorScale)scaleType
{
    _scaleType = scaleType;
}

- (double)lowerBound
{
    return _lowerBound;
}

- (void)setLowerBound:(double)lowerBound
{
    _lowerBound = lowerBound;
}

- (double)upperBound
{
    return _upperBound;
}

- (void)setUpperBound:(double)upperBound
{
    _upperBound = upperBound;
}

- (NSArray<NSNumber *> *)gridlinePositions
{
    return _gridlinePositions;
}

- (void)setGridlinePositions:(NSArray<NSNumber *> *)gridlinePositions
{
    _gridlinePositions = [gridlinePositions copy];
}

- (NSString *(^)(double))valueDescriptionProvider
{
    return _valueDescriptionProvider;
}

- (void)setValueDescriptionProvider:(NSString *(^)(double))valueDescriptionProvider
{
    _valueDescriptionProvider = [valueDescriptionProvider copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    // Shared, measured by pointer identity: the title, the attributed title, the gridline positions and
    // the caller's own block are the original's objects. The scale is not carried, and the reason is the
    // same as the chart's two: the system's own copy drops it, no initialiser of this class takes one,
    // and a copy that answered the linear case whatever the original was set to would be a port that is
    // better than the system. The case holds that with a mutant that sets it again.
    AXNumericDataAxisDescriptor *copy = [[AXNumericDataAxisDescriptor allocWithZone:zone]
        initWithTitle:_title lowerBound:_lowerBound upperBound:_upperBound
       gridlinePositions:_gridlinePositions valueDescriptionProvider:_valueDescriptionProvider];
    copy->_attributedTitle = _attributedTitle;
    return copy;
}

@end

#pragma mark - AXCategoricalDataAxisDescriptor

@implementation AXCategoricalDataAxisDescriptor {
    NSString *_title;
    NSAttributedString *_attributedTitle;
    NSArray<NSString *> *_categoryOrder;
}

- (instancetype)initWithTitle:(NSString *)title categoryOrder:(NSArray<NSString *> *)categoryOrder
{
    self = [super init];
    if (self) {
        [self setTitle:title];
        _categoryOrder = [categoryOrder copy];
    }
    return self;
}


- (instancetype)initWithAttributedTitle:(NSAttributedString *)attributedTitle
                          categoryOrder:(NSArray<NSString *> *)categoryOrder
{
    self = [super init];
    if (self) {
        [self setAttributedTitle:attributedTitle];
        _categoryOrder = [categoryOrder copy];
    }
    return self;
}

- (NSString *)title
{
    return _title;
}

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
    _attributedTitle = title ? [[NSAttributedString alloc] initWithString:title] : nil;
}

- (NSAttributedString *)attributedTitle
{
    return _attributedTitle;
}

- (void)setAttributedTitle:(NSAttributedString *)attributedTitle
{
    _attributedTitle = [attributedTitle copy];
    _title = [attributedTitle.string copy];
}

- (NSArray<NSString *> *)categoryOrder
{
    return _categoryOrder;
}

- (void)setCategoryOrder:(NSArray<NSString *> *)categoryOrder
{
    _categoryOrder = [categoryOrder copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    // Shared, measured by pointer identity: the order is the original's own array and the title and the
    // attributed title are its own strings. The pair is assigned rather than rebuilt through the title's
    // setter, for the reason the series' copy above gives.
    AXCategoricalDataAxisDescriptor *copy = [[AXCategoricalDataAxisDescriptor allocWithZone:zone]
        initWithTitle:_title categoryOrder:_categoryOrder];
    copy->_attributedTitle = _attributedTitle;
    return copy;
}

@end

#pragma mark - AXChartDescriptor

@implementation AXChartDescriptor {
    NSString *_title;
    NSAttributedString *_attributedTitle;
    NSString *_summary;
    AXChartDescriptorContentDirection _contentDirection;
    CGRect _contentFrame;
    NSArray<AXDataSeriesDescriptor *> *_series;
    id<AXDataAxisDescriptor> _xAxis;
    AXNumericDataAxisDescriptor *_yAxis;
    NSArray<id<AXDataAxisDescriptor>> *_additionalAxes;
}

// The two values no initialiser takes. Both start where a fresh object of this class starts on the
// host, measured: a zero rectangle, and the left-to-right case of the direction's own enumeration.
// The header marks the two initialisers that take additional axes as this class's designated ones and
// leaves the other two as conveniences, so those two call up to NSObject and the other two reach one
// of them with a nil for the axes they do not take.

// A nil for the additional axes stays nil: the host answers nil there, and an empty array stays an
// empty array. Nothing is substituted for either.

- (instancetype)initWithTitle:(NSString *)title
                      summary:(NSString *)summary
             xAxisDescriptor:(id<AXDataAxisDescriptor>)xAxis
            yAxisDescriptor:(AXNumericDataAxisDescriptor *)yAxis
                       series:(NSArray<AXDataSeriesDescriptor *> *)series
{
    return [self initWithTitle:title summary:summary xAxisDescriptor:xAxis yAxisDescriptor:yAxis
               additionalAxes:nil series:series];
}

- (instancetype)initWithAttributedTitle:(NSAttributedString *)attributedTitle
                               summary:(NSString *)summary
                      xAxisDescriptor:(id<AXDataAxisDescriptor>)xAxis
                     yAxisDescriptor:(AXNumericDataAxisDescriptor *)yAxis
                                series:(NSArray<AXDataSeriesDescriptor *> *)series
{
    return [self initWithAttributedTitle:attributedTitle summary:summary xAxisDescriptor:xAxis
                         yAxisDescriptor:yAxis additionalAxes:nil series:series];
}

- (instancetype)initWithTitle:(NSString *)title
                      summary:(NSString *)summary
             xAxisDescriptor:(id<AXDataAxisDescriptor>)xAxis
            yAxisDescriptor:(AXNumericDataAxisDescriptor *)yAxis
            additionalAxes:(NSArray<id<AXDataAxisDescriptor>> *)additionalAxes
                       series:(NSArray<AXDataSeriesDescriptor *> *)series
{
    self = [super init];
    if (self) {
        [self setTitle:title];
        _summary = [summary copy];
        _xAxis = xAxis;
        _yAxis = yAxis;
        _series = [series copy];
        _additionalAxes = [additionalAxes copy];
    }
    return self;
}

- (instancetype)initWithAttributedTitle:(NSAttributedString *)attributedTitle
                               summary:(NSString *)summary
                      xAxisDescriptor:(id<AXDataAxisDescriptor>)xAxis
                     yAxisDescriptor:(AXNumericDataAxisDescriptor *)yAxis
                     additionalAxes:(NSArray<id<AXDataAxisDescriptor>> *)additionalAxes
                                series:(NSArray<AXDataSeriesDescriptor *> *)series
{
    self = [super init];
    if (self) {
        [self setAttributedTitle:attributedTitle];
        _summary = [summary copy];
        _xAxis = xAxis;
        _yAxis = yAxis;
        _series = [series copy];
        _additionalAxes = [additionalAxes copy];
    }
    return self;
}

- (NSString *)title
{
    return _title;
}

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
    _attributedTitle = title ? [[NSAttributedString alloc] initWithString:title] : nil;
}

- (NSAttributedString *)attributedTitle
{
    return _attributedTitle;
}

- (void)setAttributedTitle:(NSAttributedString *)attributedTitle
{
    _attributedTitle = [attributedTitle copy];
    _title = [attributedTitle.string copy];
}

- (NSString *)summary
{
    return _summary;
}

- (void)setSummary:(NSString *)summary
{
    _summary = [summary copy];
}

- (AXChartDescriptorContentDirection)contentDirection
{
    return _contentDirection;
}

- (void)setContentDirection:(AXChartDescriptorContentDirection)contentDirection
{
    _contentDirection = contentDirection;
}

- (CGRect)contentFrame
{
    return _contentFrame;
}

- (void)setContentFrame:(CGRect)contentFrame
{
    _contentFrame = contentFrame;
}

- (NSArray<AXDataSeriesDescriptor *> *)series
{
    return _series;
}

- (void)setSeries:(NSArray<AXDataSeriesDescriptor *> *)series
{
    _series = [series copy];
}

- (id<AXDataAxisDescriptor>)xAxis
{
    return _xAxis;
}

- (void)setXAxis:(id<AXDataAxisDescriptor>)xAxis
{
    _xAxis = xAxis;
}

- (AXNumericDataAxisDescriptor *)yAxis
{
    return _yAxis;
}

- (void)setYAxis:(AXNumericDataAxisDescriptor *)yAxis
{
    _yAxis = yAxis;
}

- (NSArray<id<AXDataAxisDescriptor>> *)additionalAxes
{
    return _additionalAxes;
}

- (void)setAdditionalAxes:(NSArray<id<AXDataAxisDescriptor>> *)additionalAxes
{
    _additionalAxes = [additionalAxes copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    // Shared, measured: the copy answers the original's own series array and its own x axis.
    // Shared, measured: the title, the summary, the series, both axes and the additional axes are the
    // original's own objects. The direction and the frame are not carried, and the reason is that the
    // system's own copy drops them too - measured twice, with the same two fields lost in both runs and
    // every object-typed field of the same copy kept. The policy of this family is the system's
    // behaviour, so a copy here answers the zero case of the direction and a zero rectangle, and the
    // case holds that with a mutant that puts the two lines back.
    AXChartDescriptor *copy = [[AXChartDescriptor allocWithZone:zone] initWithTitle:_title
                                                                           summary:_summary
                                                                  xAxisDescriptor:_xAxis
                                                                 yAxisDescriptor:_yAxis
                                                                            series:_series];
    copy->_attributedTitle = _attributedTitle;
    copy->_additionalAxes = _additionalAxes;
    return copy;
}

@end

#pragma mark - AXLiveAudioGraph

// The class of a graph an assistive technology draws as sound. Nothing on this release draws one, so
// the three class methods below keep the class and leave a line in the log the first time each is
// used. They hold nothing, because there is nothing to hold: the host's instance has no ivar at all
// (measured with class_copyIvarList), and its three methods are all class methods (measured with
// class_getClassMethod). No value is refused and no call raises, because the host does not: it takes
// a value below and above the unit range and a call after +stop without complaint (measured).
@implementation AXLiveAudioGraph

+ (void)start
{
    charon_say_once_for(@"AXLiveAudioGraph.start",
                        @"AXLiveAudioGraph +start: this release runs no assistive technology that draws "
                        @"a live audio graph, so no graph is published");
}

+ (void)updateValue:(double)value
{
    charon_say_once_for(@"AXLiveAudioGraph.updateValue",
                        @"AXLiveAudioGraph +updateValue: this release runs no assistive technology that "
                        @"draws a live audio graph, so the value is not published");
}

+ (void)stop
{
    charon_say_once_for(@"AXLiveAudioGraph.stop",
                        @"AXLiveAudioGraph +stop: this release runs no assistive technology that draws a "
                        @"live audio graph, so there is no graph to stop");
}

@end
