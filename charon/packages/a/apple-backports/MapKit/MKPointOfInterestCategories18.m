// The point of interest categories iOS 18 added. Same measurement, same image, same reading.
//
// The values are Apple's own, read out of the MapKit.framework of macOS 27.0 (build 26A428): a
// generated probe declares each of these as the extern its own SDK header declares, links against
// that framework, and prints what the symbol holds. The measurement is in
// tests/backports/host/mapkit-constants, which fails the moment a name is missing there, so a
// value this file gets wrong is a value the host disagrees with.
//
// Two of them are cross-checked against a different release of Apple's own, and they agree:
// MKMapCameraZoomDefault is -1 in the macOS image and -1.0 read out of the MapKit image
// dyld.extract took of the arm64e dyld shared cache of 18.0, and MKMapItemTypeIdentifier is
// "com.apple.mapkit.map-item" in both the macOS image and the arm64 cache of 12.0.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

extern NSString *const MKPointOfInterestCategoryAnimalService;
extern NSString *const MKPointOfInterestCategoryAutomotiveRepair;
extern NSString *const MKPointOfInterestCategoryBaseball;
extern NSString *const MKPointOfInterestCategoryBasketball;
extern NSString *const MKPointOfInterestCategoryBeauty;
extern NSString *const MKPointOfInterestCategoryBowling;
extern NSString *const MKPointOfInterestCategoryCastle;
extern NSString *const MKPointOfInterestCategoryConventionCenter;
extern NSString *const MKPointOfInterestCategoryDistillery;
extern NSString *const MKPointOfInterestCategoryFairground;
extern NSString *const MKPointOfInterestCategoryFishing;
extern NSString *const MKPointOfInterestCategoryFortress;
extern NSString *const MKPointOfInterestCategoryGoKart;
extern NSString *const MKPointOfInterestCategoryGolf;
extern NSString *const MKPointOfInterestCategoryHiking;
extern NSString *const MKPointOfInterestCategoryKayaking;
extern NSString *const MKPointOfInterestCategoryLandmark;
extern NSString *const MKPointOfInterestCategoryMailbox;
extern NSString *const MKPointOfInterestCategoryMiniGolf;
extern NSString *const MKPointOfInterestCategoryMusicVenue;
extern NSString *const MKPointOfInterestCategoryNationalMonument;
extern NSString *const MKPointOfInterestCategoryPlanetarium;
extern NSString *const MKPointOfInterestCategoryRVPark;
extern NSString *const MKPointOfInterestCategoryRockClimbing;
extern NSString *const MKPointOfInterestCategorySkatePark;
extern NSString *const MKPointOfInterestCategorySkating;
extern NSString *const MKPointOfInterestCategorySkiing;
extern NSString *const MKPointOfInterestCategorySoccer;
extern NSString *const MKPointOfInterestCategorySpa;
extern NSString *const MKPointOfInterestCategorySurfing;
extern NSString *const MKPointOfInterestCategorySwimming;
extern NSString *const MKPointOfInterestCategoryTennis;
extern NSString *const MKPointOfInterestCategoryVolleyball;

NSString *const MKPointOfInterestCategoryAnimalService = @"MKPOICategoryAnimalService";
NSString *const MKPointOfInterestCategoryAutomotiveRepair = @"MKPOICategoryAutomotiveRepair";
NSString *const MKPointOfInterestCategoryBaseball = @"MKPOICategoryBaseball";
NSString *const MKPointOfInterestCategoryBasketball = @"MKPOICategoryBasketball";
NSString *const MKPointOfInterestCategoryBeauty = @"MKPOICategoryBeauty";
NSString *const MKPointOfInterestCategoryBowling = @"MKPOICategoryBowling";
NSString *const MKPointOfInterestCategoryCastle = @"MKPOICategoryCastle";
NSString *const MKPointOfInterestCategoryConventionCenter = @"MKPOICategoryConventionCenter";
NSString *const MKPointOfInterestCategoryDistillery = @"MKPOICategoryDistillery";
NSString *const MKPointOfInterestCategoryFairground = @"MKPOICategoryFairground";
NSString *const MKPointOfInterestCategoryFishing = @"MKPOICategoryFishing";
NSString *const MKPointOfInterestCategoryFortress = @"MKPOICategoryFortress";
NSString *const MKPointOfInterestCategoryGoKart = @"MKPOICategoryGoKart";
NSString *const MKPointOfInterestCategoryGolf = @"MKPOICategoryGolf";
NSString *const MKPointOfInterestCategoryHiking = @"MKPOICategoryHiking";
NSString *const MKPointOfInterestCategoryKayaking = @"MKPOICategoryKayaking";
NSString *const MKPointOfInterestCategoryLandmark = @"MKPOICategoryLandmark";
NSString *const MKPointOfInterestCategoryMailbox = @"MKPOICategoryMailbox";
NSString *const MKPointOfInterestCategoryMiniGolf = @"MKPOICategoryMiniGolf";
NSString *const MKPointOfInterestCategoryMusicVenue = @"MKPOICategoryMusicVenue";
NSString *const MKPointOfInterestCategoryNationalMonument = @"MKPOICategoryNationalMonument";
NSString *const MKPointOfInterestCategoryPlanetarium = @"MKPOICategoryPlanetarium";
NSString *const MKPointOfInterestCategoryRVPark = @"MKPOICategoryRVPark";
NSString *const MKPointOfInterestCategoryRockClimbing = @"MKPOICategoryRockClimbing";
NSString *const MKPointOfInterestCategorySkatePark = @"MKPOICategorySkatePark";
NSString *const MKPointOfInterestCategorySkating = @"MKPOICategorySkating";
NSString *const MKPointOfInterestCategorySkiing = @"MKPOICategorySkiing";
NSString *const MKPointOfInterestCategorySoccer = @"MKPOICategorySoccer";
NSString *const MKPointOfInterestCategorySpa = @"MKPOICategorySpa";
NSString *const MKPointOfInterestCategorySurfing = @"MKPOICategorySurfing";
NSString *const MKPointOfInterestCategorySwimming = @"MKPOICategorySwimming";
NSString *const MKPointOfInterestCategoryTennis = @"MKPOICategoryTennis";
NSString *const MKPointOfInterestCategoryVolleyball = @"MKPOICategoryVolleyball";
