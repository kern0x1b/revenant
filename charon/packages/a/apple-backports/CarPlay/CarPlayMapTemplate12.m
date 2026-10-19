// The nine 12.0 members of CPMapTemplate this port did not carry, and CPImageSet's own designated
// initialiser.
//
// Every one of them was a row saying `implemented` with nothing behind it, and the reason the gate
// could not see that is worth writing down: backports.lua's unbuilt check counts a member row as built
// when its owner class is exported, so a class answers for a member it never defined and the check says
// the row is there. Thirteen such selectors were in no source file in the package, of which
// -[CPMapTemplate startNavigationSessionForTrip:] already has a body in CarPlayNavigationSession12.m -
// the 26.2 header says that method is where a session comes to exist. The other twelve are here.
//
// What the release's own cache says about this class is what makes these members modellable here and
// not inventions: at 16.0 CPMapTemplate carries -presentNavigationAlert:animated:,
// -dismissNavigationAlertAnimated:completion:, -updateTravelEstimates:forTrip: and the rest, and its
// own -init has already made the alert, the guidance colour and the map buttons these members drive.
// The drawing they reach is the class's own: `charon_showCurrentAlert` draws the alert card over the
// release's MKMapView, `CharonMapButtons` draws the buttons, and `charon_drawTripPreviews` draws the
// previews. None of them is reimplemented here.
//
// **What each member does and does not do.** A `textConfiguration` argument is the system's font and
// scale for a car screen, and this port has no car screen to measure one on: the previews are drawn in
// this port's own label at the system's default, which is what a `UIFont` the port does not choose
// looks like. The arguments are named in the signature because the SDK declares them, and they are not
// read, because reading them would mean inventing a number. The `animated:` argument of the alert and
// the panning interface is read: it decides whether the change is animated, through this release's own
// `UIView` animation calls. The panning interface's own rule - "a maximum of two mapButtons will be
// visible" - is applied to the buttons the template holds, and the container view's `hidden` is not
// touched, because the header says nothing about the container and a caller's own `hidden` on a map
// button is what the grid button draws from.
//
// A category cannot write an ivar, so the storage for the alert, the previews, the per-trip estimates
// and the time-remaining colour is declared with the class's own ivars in CarPlayTemplatesView12.m and
// reached through the accessors declared in CharonCarPlayTemplate.h. One release per object: the 14.0
// member is in CarPlayMapTemplate14.m and CPGridButton's 26.0 `-updateImage:` is in CarPlayGrid260.m,
// with the rest of that release's own object.
#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>
#import "CharonCarPlayTemplate.h"

// The header's own limit: CPMapTemplate.h:76 says "Number of trips will be limited to 12".
static const NSUInteger CharonMapMaximumPreviews = 12;

// The card a trip preview is drawn in, named so that -hideTripPreviews can find it and take it off the
// map, the same reason CharonCarPlayAlertCard is a class of its own. Charon's own, so no row.
@interface CharonMapPreviewCard : UIView
@end

@implementation CharonMapPreviewCard
@end

@implementation CPMapTemplate (CharonMapTemplate12)

#pragma mark - the navigation alert

// CPMapTemplate.h:159-169. The header's own @warning is the first thing this does: while a navigation alert is already showing,
// the method has no effect, and the currently visible alert must be dismissed before a new one is presented. So a second presentation is not a replacement.
- (void)presentNavigationAlert:(CPNavigationAlert *)navigationAlert animated:(BOOL)animated
{
    if (navigationAlert == nil || self.charon_navigationAlert != nil) {
        return;
    }
    // `animated` is the caller's choice about how the card appears, and this release's own animation
    // calls are the mechanism: an animated presentation fades the card in rather than cutting it.
    if (animated) {
        [UIView beginAnimations:@"charon.alert.present" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self charon_setNavigationAlert:navigationAlert];
    if (animated) {
        [UIView commitAnimations];
    }
}

// CPMapTemplate.h:171-178. The header says what the BOOL means: YES when a visible alert was dismissed, and NO when
// nothing happened because no alert was there to dismiss. So the answer is whether there was one, which is a question about the state before the call
// and not about anything this method did.
- (void)dismissNavigationAlertAnimated:(BOOL)animated completion:(void (^)(BOOL dismissed))completion
{
    BOOL wasVisible = self.charon_navigationAlert != nil;
    if (animated) {
        [UIView beginAnimations:@"charon.alert.dismiss" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self charon_setNavigationAlert:nil];
    if (animated) {
        [UIView commitAnimations];
    }
    if (completion != NULL) {
        completion(wasVisible);
    }
}

#pragma mark - the panning interface

// CPMapTemplate.h:129-138. The header's own rule: while the panning interface is showing, at most two mapButtons are visible.
// If more than two are visible when the template moves into panning mode, the system hides some of the map buttons, working back from the tail of the
// mapButtons array.
- (void)showPanningInterfaceAnimated:(BOOL)animated
{
    if (self.charon_panningInterfaceVisible) {
        return;
    }
    if (animated) {
        [UIView beginAnimations:@"charon.panning.show" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self charon_setPanningInterfaceVisible:YES];
    // "beginning from the end of the mapButtons array", applied to the buttons this template holds: the
    // last ones are hidden and each one's own `hidden` is what CharonMapButtons draws from.
    NSArray<CPMapButton *> *buttons = self.mapButtons;
    for (NSUInteger i = 0; i < buttons.count; i++) {
        [buttons[i] setHidden:i >= 2];
    }
    if (animated) {
        [UIView commitAnimations];
    }
}

// CPMapTemplate.h:140-144: the header says dismissing the panning interface happens only if it is visible. A note there says
// that mapButtons hidden by the system before the dismissal are no longer hidden afterward.
- (void)dismissPanningInterfaceAnimated:(BOOL)animated
{
    if (!self.charon_panningInterfaceVisible) {
        return;
    }
    if (animated) {
        [UIView beginAnimations:@"charon.panning.dismiss" context:nil];
        [UIView setAnimationDuration:0.25];
    }
    [self charon_setPanningInterfaceVisible:NO];
    // The note is the whole of this method: every button becomes visible again, including the ones the
    // excess hid, which is what "no longer be hidden" says and not merely "the excess stays hidden".
    for (CPMapButton *button in self.mapButtons) {
        [button setHidden:NO];
    }
    if (animated) {
        [UIView commitAnimations];
    }
}

#pragma mark - the trip previews

// CPMapTemplate.h:74-78: the header says a preview for a trip gives an overview of the coming trip, and it may show several
// trip options; the number of trips is limited to 12.
- (void)showTripPreviews:(NSArray<CPTrip *> *)trips textConfiguration:(CPTripPreviewTextConfiguration *)textConfiguration
{
    if (trips == nil) {
        return;
    }
    NSUInteger kept = MIN(trips.count, CharonMapMaximumPreviews);
    [self charon_setTripPreviews:[trips subarrayWithRange:NSMakeRange(0, kept)] selectedTrip:nil];
    [self charon_drawTripPreviews];
}

// CPMapTemplate.h:86-90: the header says the route choices for one trip are displayed, and trip previews may be shown
// on top of a running navigation session.
- (void)showRouteChoicesPreviewForTrip:(CPTrip *)trip textConfiguration:(CPTripPreviewTextConfiguration *)textConfiguration
{
    if (trip == nil) {
        return;
    }
    [self charon_setTripPreviews:@[trip] selectedTrip:trip];
    [self charon_drawTripPreviews];
}

// CPMapTemplate.h:92-95: "Stop displaying any currently shown trip previews."
- (void)hideTripPreviews
{
    [self charon_setTripPreviews:nil selectedTrip:nil];
    UIView *map = [self charon_mapView];
    for (UIView *sub in [map.subviews copy]) {
        if ([sub isKindOfClass:[CharonMapPreviewCard class]]) {
            [sub removeFromSuperview];
        }
    }
}

#pragma mark - the travel estimates

// CPMapTemplate.h:98-100: the header says the template refreshes the figures for a trip preview or an active
// navigation trip, using the default color for the remaining time.
- (void)updateTravelEstimates:(CPTravelEstimates *)estimates forTrip:(CPTrip *)trip
{
    // "with the default color for time remaining" is CPMapTemplate.h:37 - CPTimeRemainingColorDefault,
    // which is the enumeration's own first case and the number an unset value already holds.
    [self updateTravelEstimates:estimates forTrip:trip withTimeRemainingColor:CPTimeRemainingColorDefault];
}

// CPMapTemplate.h:102-105: the header says the template refreshes the arrival, remaining-time and remaining-distance figures,
// with a chosen color for the remaining time.
- (void)updateTravelEstimates:(CPTravelEstimates *)estimates
                      forTrip:(CPTrip *)trip
         withTimeRemainingColor:(CPTimeRemainingColor)timeRemainingColor
{
    if (trip == nil) {
        return;
    }
    [self charon_setEstimates:estimates forTrip:trip];
    [self charon_setTimeRemainingColor:timeRemainingColor];
}

#pragma mark - the drawing these members reach

// The four cases of CPMapTemplate.h:36-41 by name, so the card says which one the estimates asked for
// rather than printing a number. The enumeration's own values, in the header's own order, and anything
// outside them as the default, which is what an unset value already holds.
static NSString *charon_nameForTimeRemainingColor(CPTimeRemainingColor color)
{
    switch (color) {
        case CPTimeRemainingColorGreen: return @"green";
        case CPTimeRemainingColorOrange: return @"orange";
        case CPTimeRemainingColorRed: return @"red";
        case CPTimeRemainingColorDefault: break;
    }
    return @"default";
}

// The previews, drawn in one card over the map: what it holds, and the estimates' time remaining for
// the selected trip in the colour the estimates asked for. Charon's own, so no row - and it is the
// class's own drawing that -hideTripPreviews finds the card by.
//
// The geometry is this port's own and not a measurement: there is no car screen to measure a preview
// card on, and the 420-point width is the alert card's above. What is not this port's own is the text:
// each line is the trip's own origin and destination as MapKit items name them, and the time remaining
// is read from the estimates the caller gave.
- (void)charon_drawTripPreviews
{
    UIView *map = [self charon_mapView];
    if (map == nil) {
        return;
    }
    for (UIView *sub in [map.subviews copy]) {
        if ([sub isKindOfClass:[CharonMapPreviewCard class]]) {
            [sub removeFromSuperview];
        }
    }
    NSArray<CPTrip *> *previews = self.charon_tripPreviews;
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
    if (self.charon_selectedTrip != nil) {
        CPTravelEstimates *estimates = [self charon_estimatesForTrip:self.charon_selectedTrip];
        if (estimates != nil) {
            // CPTravelEstimates.h:24-31 says a value below zero renders as "--", and zero is not below
            // zero, so a zero reads as a zero here and not as a placeholder.
            NSString *remaining = estimates.timeRemaining < 0.0
                ? @"--"
                : [NSString stringWithFormat:@"%.0f min", estimates.timeRemaining / 60.0];
            [lines addObject:[NSString stringWithFormat:@"%@ - %@", remaining,
                                  charon_nameForTimeRemainingColor(self.charon_timeRemainingColor)]];
        }
    }
    CGSize size = CGSizeMake(420.0, 24.0 + 22.0 * (CGFloat)lines.count);
    CharonMapPreviewCard *card = [[CharonMapPreviewCard alloc]
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

// CPImageSet.h:22-24 declares the designated initialiser, and a category cannot write an ivar for the
// two images, so the storage is the class's own in CarPlayTemplatesMore12.m and this reaches it.
@implementation CPImageSet (CharonImageSetInitialiser)

- (instancetype)initWithLightContentImage:(UIImage *)lightImage darkContentImage:(UIImage *)darkImage
{
    self = [super init];
    if (self) {
        [self charon_setLightContentImage:lightImage darkContentImage:darkImage];
    }
    return self;
}

@end