#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "RevenantCarPlayTemplate.h"

static const NSUInteger RevenantMapMaximumPreviews = 12;

@interface RevenantMapPreviewCard : UIView
@end

@implementation RevenantMapPreviewCard
@end

@implementation CPMapTemplate (RevenantMapTemplate12)

#pragma mark - the navigation alert

- (void)presentNavigationAlert:(CPNavigationAlert *)navigationAlert animated:(BOOL)animated
{
    if (navigationAlert == nil || self.revenant_navigationAlert != nil) {
        return;
    }
    if (animated) {
        [UIView beginAnimations:@"revenant.alert.present" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self revenant_setNavigationAlert:navigationAlert];
    if (animated) {
        [UIView commitAnimations];
    }
}

- (void)dismissNavigationAlertAnimated:(BOOL)animated completion:(void (^)(BOOL dismissed))completion
{
    BOOL wasVisible = self.revenant_navigationAlert != nil;
    if (animated) {
        [UIView beginAnimations:@"revenant.alert.dismiss" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self revenant_setNavigationAlert:nil];
    if (animated) {
        [UIView commitAnimations];
    }
    if (completion != NULL) {
        completion(wasVisible);
    }
}

#pragma mark - the panning interface

- (void)showPanningInterfaceAnimated:(BOOL)animated
{
    if (self.revenant_panningInterfaceVisible) {
        return;
    }
    if (animated) {
        [UIView beginAnimations:@"revenant.panning.show" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self revenant_setPanningInterfaceVisible:YES];
    NSArray<CPMapButton *> *buttons = self.mapButtons;
    for (NSUInteger i = 0; i < buttons.count; i++) {
        [buttons[i] setHidden:i >= 2];
    }
    if (animated) {
        [UIView commitAnimations];
    }
}

- (void)dismissPanningInterfaceAnimated:(BOOL)animated
{
    if (!self.revenant_panningInterfaceVisible) {
        return;
    }
    if (animated) {
        [UIView beginAnimations:@"revenant.panning.dismiss" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self revenant_setPanningInterfaceVisible:NO];
    for (CPMapButton *button in self.mapButtons) {
        [button setHidden:NO];
    }
    if (animated) {
        [UIView commitAnimations];
    }
}

#pragma mark - the trip previews

- (void)showTripPreviews:(NSArray<CPTrip *> *)trips textConfiguration:(CPTripPreviewTextConfiguration *)textConfiguration
{
    if (trips == nil) {
        return;
    }
    NSUInteger kept = MIN(trips.count, RevenantMapMaximumPreviews);
    [self revenant_setTripPreviews:[trips subarrayWithRange:NSMakeRange(0, kept)] selectedTrip:nil];
    [self revenant_drawTripPreviews];
}

- (void)showRouteChoicesPreviewForTrip:(CPTrip *)trip textConfiguration:(CPTripPreviewTextConfiguration *)textConfiguration
{
    if (trip == nil) {
        return;
    }
    [self revenant_setTripPreviews:@[trip] selectedTrip:trip];
    [self revenant_drawTripPreviews];
}

- (void)hideTripPreviews
{
    [self revenant_setTripPreviews:nil selectedTrip:nil];
    UIView *map = [self revenant_mapView];
    for (UIView *sub in [map.subviews copy]) {
        if ([sub isKindOfClass:[RevenantMapPreviewCard class]]) {
            [sub removeFromSuperview];
        }
    }
}

#pragma mark - the travel estimates

- (void)updateTravelEstimates:(CPTravelEstimates *)estimates forTrip:(CPTrip *)trip
{
    [self updateTravelEstimates:estimates forTrip:trip withTimeRemainingColor:CPTimeRemainingColorDefault];
}

- (void)updateTravelEstimates:(CPTravelEstimates *)estimates
                      forTrip:(CPTrip *)trip
         withTimeRemainingColor:(CPTimeRemainingColor)timeRemainingColor
{
    if (trip == nil) {
        return;
    }
    [self revenant_setEstimates:estimates forTrip:trip];
    [self revenant_setTimeRemainingColor:timeRemainingColor];
}

#pragma mark - the drawing these members reach

static NSString *revenant_nameForTimeRemainingColor(CPTimeRemainingColor color)
{
    switch (color) {
        case CPTimeRemainingColorGreen: return @"green";
        case CPTimeRemainingColorOrange: return @"orange";
        case CPTimeRemainingColorRed: return @"red";
        case CPTimeRemainingColorDefault: break;
    }
    return @"default";
}

- (void)revenant_drawTripPreviews
{
    UIView *map = [self revenant_mapView];
    if (map == nil) {
        return;
    }
    for (UIView *sub in [map.subviews copy]) {
        if ([sub isKindOfClass:[RevenantMapPreviewCard class]]) {
            [sub removeFromSuperview];
        }
    }
    NSArray<CPTrip *> *previews = self.revenant_tripPreviews;
    if (previews.count == 0) {
        return;
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (CPTrip *trip in previews) {
        NSString *origin = trip.origin.name;
        NSString *destination = trip.destination.name;
        [lines addObject:origin.length > 0 ? (destination.length > 0
                                              ? [NSString stringWithFormat:@"%@ to %@", origin, destination]
                                              : origin)
                                           : @"(trip)"];
    }
    if (self.revenant_selectedTrip != nil) {
        CPTravelEstimates *estimates = [self revenant_estimatesForTrip:self.revenant_selectedTrip];
        if (estimates != nil) {
            NSString *remaining = estimates.timeRemaining < 0.0
                ? @"--"
                : [NSString stringWithFormat:@"%.0f min", estimates.timeRemaining / 60.0];
            [lines addObject:[NSString stringWithFormat:@"%@ - %@", remaining,
                                  revenant_nameForTimeRemainingColor(self.revenant_timeRemainingColor)]];
        }
    }
    CGSize size = CGSizeMake(420.0, 24.0 + 22.0 * (CGFloat)lines.count);
    RevenantMapPreviewCard *card = [[RevenantMapPreviewCard alloc]
        initWithFrame:CGRectMake(20.0, CGRectGetHeight(map.bounds) - size.height - 20.0,
                                 size.width, size.height)];
    card.backgroundColor = self.guidanceBackgroundColor;
    card.layer.cornerRadius = 10.0;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(card.bounds, 12.0, 8.0)];
    label.text = [lines componentsJoinedByString:@"\n"];
    label.numberOfLines = (NSInteger)lines.count;
    label.textColor = [UIColor whiteColor];
    [card addSubview:label];
    [map addSubview:card];
}

@end

@implementation CPImageSet (RevenantImageSetInitialiser)

- (instancetype)initWithLightContentImage:(UIImage *)lightImage darkContentImage:(UIImage *)darkImage
{
    self = [super init];
    if (self) {
        [self revenant_setLightContentImage:lightImage darkContentImage:darkImage];
    }
    return self;
}

@end
