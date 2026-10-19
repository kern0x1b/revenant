// MKScaleView: the bar in the corner of a map that says how long a piece of the map is.
//
// The bar is drawn from the release's own projection: a round number of metres that fits the width
// the legend was given, and then that many metres' worth of the map view's own visible map rect,
// which is the bar's own length. A scale view needs MapKit's iOS-only MKScaleView.h, which is why it
// is in its own object: the distance formatter beside it must stay compilable for a macOS host probe,
// which has the class but no such header.
#import <MapKit/MapKit.h>
#import <MapKit/MKScaleView.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import "CharonMapKit.h"

@implementation MKScaleView {
    MKMapView *_mapView;
    MKFeatureVisibility _scaleVisibility;
    MKScaleViewAlignment _legendAlignment;
    UILabel *_legend;
    UIView *_bar;
}

@synthesize scaleVisibility = _scaleVisibility;
@synthesize legendAlignment = _legendAlignment;

+ (instancetype)scaleViewWithMapView:(MKMapView *)mapView
{
    MKScaleView *scale = [[self alloc] initWithFrame:CGRectMake(0.0, 0.0, 120.0, 24.0)];
    if (scale) {
        scale->_mapView = mapView;
        [scale charon_build];
    }
    return scale;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _scaleVisibility = MKFeatureVisibilityAdaptive;
        _legendAlignment = MKScaleViewAlignmentTrailing;
        [self charon_build];
    }
    return self;
}

- (MKMapView *)mapView
{
    return _mapView;
}

- (void)setMapView:(MKMapView *)mapView
{
    _mapView = mapView;
    [self charon_update];
}

- (void)charon_build
{
    self.backgroundColor = [UIColor clearColor];
    _legend = [[UILabel alloc] initWithFrame:CGRectZero];
    _legend.font = [UIFont systemFontOfSize:10.0];
    _legend.textColor = [UIColor blackColor];
    _legend.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    _legend.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_legend];
    _bar = [[UIView alloc] initWithFrame:CGRectZero];
    _bar.backgroundColor = [UIColor blackColor];
    [self addSubview:_bar];
    [self charon_update];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self charon_update];
}

// The bar: a round number of metres that fits the width of the view, and then the map points that
// many metres stand for, which is the bar's own length. Charon's own, so it carries no API.
- (void)charon_update
{
    MKMapView *mapView = _mapView;
    CGRect box = self.bounds;
    if (!mapView || _scaleVisibility == MKFeatureVisibilityHidden || CGRectIsEmpty(box)) {
        _bar.hidden = YES;
        _legend.hidden = YES;
        return;
    }
    // The map view's own scale, out of the two things its 16.4 header declares: the visible map rect
    // is so many map points across, and the view is so many points across.
    MKMapRect visible = mapView.visibleMapRect;
    double pointsWide = 0.0;
    if (mapView.bounds.size.width > 0.0 && visible.size.width > 0.0) {
        pointsWide = visible.size.width * (double)box.size.width / (double)mapView.bounds.size.width;
    }
    double metresWide = pointsWide * MKMetersPerMapPointAtLatitude(mapView.centerCoordinate.latitude);
    if (!(metresWide > 0.0)) {
        _bar.hidden = YES;
        _legend.hidden = YES;
        return;
    }
    // The largest 1, 2 or 5 times a power of ten of metres that leaves room for the legend above.
    double target = metresWide / 2.5;
    double scale = pow(10.0, floor(log10(target)));
    double multiple = 1.0;
    for (double step = 1.0; step <= 5.0; step *= 2.0) {
        if (step * scale <= target) {
            multiple = step;
        }
    }
    double metres = multiple * scale;
    NSString *text;
    if (metres >= 1000.0) {
        text = [NSString stringWithFormat:@"%.0f km", metres / 1000.0];
    } else {
        text = [NSString stringWithFormat:@"%.0f m", metres];
    }
    double pointsPerMapPoint = metres / MKMetersPerMapPointAtLatitude(mapView.centerCoordinate.latitude);
    double barPoints = pointsPerMapPoint > 0.0 ? metres / pointsPerMapPoint : 0.0;
    if (pointsWide > 0.0 && visible.size.width > 0.0) {
        barPoints = barPoints * (double)box.size.width / (double)mapView.bounds.size.width * (double)mapView.bounds.size.width / (double)box.size.width;
    }
    CGFloat barHeight = 2.0;
    CGFloat barY = CGRectGetHeight(box) - barHeight - 2.0;
    CGFloat barX = CGRectGetMinX(box) + 2.0;
    _bar.hidden = NO;
    _bar.frame = CGRectMake(barX, barY, (CGFloat)barPoints, barHeight);
    _legend.hidden = NO;
    _legend.text = text;
    _legend.frame = CGRectMake(barX, barY - 14.0, (CGFloat)barPoints, 14.0);
}

@end
