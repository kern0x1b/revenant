#ifndef CHARON_CARPLAY_TEMPLATE_H
#define CHARON_CARPLAY_TEMPLATE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import "CharonCarPlay260.h"

@interface CPListSection (CharonSectionHeader)

- (void)charon_setHeaderSubtitle:(NSString *)headerSubtitle;
- (void)charon_setHeaderImage:(UIImage *)headerImage;
- (void)charon_setHeaderButton:(CPButton *)headerButton;

@end

@interface CPAlertAction (CharonAlertActionColor)

- (void)charon_setColor:(UIColor *)color;

@end

@interface CPGridButton (CharonGridButton26)

- (CPMessageGridItemConfiguration *)charon_messageConfiguration;
- (void)charon_setMessageConfiguration:(CPMessageGridItemConfiguration *)messageConfiguration;
- (void)charon_setTitleVariants:(NSArray<NSString *> *)titleVariants;

- (void)charon_setImage:(UIImage *)image;

@end

@interface CPImageSet (CharonImageSetState)

- (void)charon_setLightContentImage:(UIImage *)lightImage darkContentImage:(UIImage *)darkImage;

@end

@interface CPMapTemplate (CharonMapTemplateState)

- (CPNavigationAlert *)charon_navigationAlert;
- (void)charon_setNavigationAlert:(CPNavigationAlert *)navigationAlert;
- (UIView *)charon_mapButtons;
- (BOOL)charon_panningInterfaceVisible;
- (void)charon_setPanningInterfaceVisible:(BOOL)visible;
- (NSArray *)charon_tripPreviews;
- (void)charon_setTripPreviews:(NSArray *)previews selectedTrip:(CPTrip *)selectedTrip;
- (CPTrip *)charon_selectedTrip;
- (void)charon_setEstimates:(CPTravelEstimates *)estimates forTrip:(CPTrip *)trip;
- (CPTravelEstimates *)charon_estimatesForTrip:(CPTrip *)trip;
- (void)charon_setTimeRemainingColor:(CPTimeRemainingColor)color;
- (CPTimeRemainingColor)charon_timeRemainingColor;
- (void)charon_drawTripPreviews;
- (void)charon_showCurrentAlert;
- (UIView *)charon_mapView;

@end

@interface CPListTemplate (CharonListTemplateState)

- (BOOL)charon_showsSpinnerWhileEmpty;
- (void)charon_setShowsSpinnerWhileEmpty:(BOOL)showsSpinnerWhileEmpty;

- (NSArray<CPGridButton *> *)charon_headerGridButtons;
- (void)charon_setHeaderGridButtons:(NSArray<CPGridButton *> *)headerGridButtons;

@end

#endif
