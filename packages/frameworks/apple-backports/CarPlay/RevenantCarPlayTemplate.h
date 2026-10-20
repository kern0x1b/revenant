#ifndef REVENANT_CARPLAY_TEMPLATE_H
#define REVENANT_CARPLAY_TEMPLATE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import "RevenantCarPlay260.h"

@interface CPListSection (RevenantSectionHeader)

- (void)revenant_setHeaderSubtitle:(NSString *)headerSubtitle;
- (void)revenant_setHeaderImage:(UIImage *)headerImage;
- (void)revenant_setHeaderButton:(CPButton *)headerButton;

@end

@interface CPAlertAction (RevenantAlertActionColor)

- (void)revenant_setColor:(UIColor *)color;

@end

@interface CPGridButton (RevenantGridButton26)

- (CPMessageGridItemConfiguration *)revenant_messageConfiguration;
- (void)revenant_setMessageConfiguration:(CPMessageGridItemConfiguration *)messageConfiguration;
- (void)revenant_setTitleVariants:(NSArray<NSString *> *)titleVariants;

- (void)revenant_setImage:(UIImage *)image;

@end

@interface CPImageSet (RevenantImageSetState)

- (void)revenant_setLightContentImage:(UIImage *)lightImage darkContentImage:(UIImage *)darkImage;

@end

@interface CPMapTemplate (RevenantMapTemplateState)

- (CPNavigationAlert *)revenant_navigationAlert;
- (void)revenant_setNavigationAlert:(CPNavigationAlert *)navigationAlert;
- (UIView *)revenant_mapButtons;
- (BOOL)revenant_panningInterfaceVisible;
- (void)revenant_setPanningInterfaceVisible:(BOOL)visible;
- (NSArray *)revenant_tripPreviews;
- (void)revenant_setTripPreviews:(NSArray *)previews selectedTrip:(CPTrip *)selectedTrip;
- (CPTrip *)revenant_selectedTrip;
- (void)revenant_setEstimates:(CPTravelEstimates *)estimates forTrip:(CPTrip *)trip;
- (CPTravelEstimates *)revenant_estimatesForTrip:(CPTrip *)trip;
- (void)revenant_setTimeRemainingColor:(CPTimeRemainingColor)color;
- (CPTimeRemainingColor)revenant_timeRemainingColor;
- (void)revenant_drawTripPreviews;
- (void)revenant_showCurrentAlert;
- (UIView *)revenant_mapView;

@end

@interface CPListTemplate (RevenantListTemplateState)

- (BOOL)revenant_showsSpinnerWhileEmpty;
- (void)revenant_setShowsSpinnerWhileEmpty:(BOOL)showsSpinnerWhileEmpty;

- (NSArray<CPGridButton *> *)revenant_headerGridButtons;
- (void)revenant_setHeaderGridButtons:(NSArray<CPGridButton *> *)headerGridButtons;

@end

#endif
