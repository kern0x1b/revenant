#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>

#import "../CharonSayOnce.h"

#pragma mark - AXDataPointValue

@implementation AXDataPointValue {
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
    NSString *_label;
    NSAttributedString *_attributedLabel;
}

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
    copy->_additionalValues = _additionalValues;
    [copy setLabel:_label];
    return copy;
}

@end

#pragma mark - AXDataSeriesDescriptor

@implementation AXDataSeriesDescriptor {
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
    AXDataSeriesDescriptor *copy = [[AXDataSeriesDescriptor allocWithZone:zone] initWithName:_name
                                                                              isContinuous:_isContinuous
                                                                                 dataPoints:_dataPoints];
    copy->_attributedName = _attributedName;
    return copy;
}

@end

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
