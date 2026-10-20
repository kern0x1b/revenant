#import <MapKit/MapKit.h>
#import <MapKit/MKScaleView.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import "RevenantMapKit.h"

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
        [scale revenant_build];
    }
    return scale;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _scaleVisibility = MKFeatureVisibilityAdaptive;
        _legendAlignment = MKScaleViewAlignmentTrailing;
        [self revenant_build];
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
    [self revenant_update];
}

- (void)revenant_build
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
    [self revenant_update];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self revenant_update];
}

- (void)revenant_update
{
    MKMapView *mapView = _mapView;
    CGRect box = self.bounds;
    if (!mapView || _scaleVisibility == MKFeatureVisibilityHidden || CGRectIsEmpty(box)) {
        _bar.hidden = YES;
        _legend.hidden = YES;
        return;
    }
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
