// The point of interest categories iOS 13.4 added, and the camera's default zoom distance of iOS 13.4. Apple's
// map knows a place by one of these strings, so a filter built against them is the filter Apple's
// own map understands; the values are Apple's, read from Apple's own image. The two iOS 16.0 names of
// the same header are in MKPointOfInterestCategories16.m.
//
// The values are Apple's own, read out of the MapKit.framework of macOS 27.0 (build 26A428): a
// generated probe declares each of these as the extern its own SDK header declares, links against
// that framework, and prints what the symbol holds. The measurement is in
// tests/backports/host/mapkit-constants, which fails the moment a name is missing there, so a
// value this file gets wrong is a value the host disagrees with.
//
// MKMapCameraZoomDefault is -1 in the macOS image and -1.0 read out of the MapKit image dyld.extract
// took of the arm64e dyld shared cache of 18.0, so the two agree.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

extern const double MKMapCameraZoomDefault;
extern NSString *const MKPointOfInterestCategoryATM;
extern NSString *const MKPointOfInterestCategoryAirport;
extern NSString *const MKPointOfInterestCategoryAmusementPark;
extern NSString *const MKPointOfInterestCategoryAquarium;
extern NSString *const MKPointOfInterestCategoryBakery;
extern NSString *const MKPointOfInterestCategoryBank;
extern NSString *const MKPointOfInterestCategoryBeach;
extern NSString *const MKPointOfInterestCategoryBrewery;
extern NSString *const MKPointOfInterestCategoryCafe;
extern NSString *const MKPointOfInterestCategoryCampground;
extern NSString *const MKPointOfInterestCategoryCarRental;
extern NSString *const MKPointOfInterestCategoryEVCharger;
extern NSString *const MKPointOfInterestCategoryFireStation;
extern NSString *const MKPointOfInterestCategoryFitnessCenter;
extern NSString *const MKPointOfInterestCategoryFoodMarket;
extern NSString *const MKPointOfInterestCategoryGasStation;
extern NSString *const MKPointOfInterestCategoryHospital;
extern NSString *const MKPointOfInterestCategoryHotel;
extern NSString *const MKPointOfInterestCategoryLaundry;
extern NSString *const MKPointOfInterestCategoryLibrary;
extern NSString *const MKPointOfInterestCategoryMarina;
extern NSString *const MKPointOfInterestCategoryMovieTheater;
extern NSString *const MKPointOfInterestCategoryMuseum;
extern NSString *const MKPointOfInterestCategoryNationalPark;
extern NSString *const MKPointOfInterestCategoryNightlife;
extern NSString *const MKPointOfInterestCategoryPark;
extern NSString *const MKPointOfInterestCategoryParking;
extern NSString *const MKPointOfInterestCategoryPharmacy;
extern NSString *const MKPointOfInterestCategoryPolice;
extern NSString *const MKPointOfInterestCategoryPostOffice;
extern NSString *const MKPointOfInterestCategoryPublicTransport;
extern NSString *const MKPointOfInterestCategoryRestaurant;
extern NSString *const MKPointOfInterestCategoryRestroom;
extern NSString *const MKPointOfInterestCategorySchool;
extern NSString *const MKPointOfInterestCategoryStadium;
extern NSString *const MKPointOfInterestCategoryStore;
extern NSString *const MKPointOfInterestCategoryTheater;
extern NSString *const MKPointOfInterestCategoryUniversity;
extern NSString *const MKPointOfInterestCategoryWinery;
extern NSString *const MKPointOfInterestCategoryZoo;

const double MKMapCameraZoomDefault = -1;
NSString *const MKPointOfInterestCategoryATM = @"MKPOICategoryATM";
NSString *const MKPointOfInterestCategoryAirport = @"MKPOICategoryAirport";
NSString *const MKPointOfInterestCategoryAmusementPark = @"MKPOICategoryAmusementPark";
NSString *const MKPointOfInterestCategoryAquarium = @"MKPOICategoryAquarium";
NSString *const MKPointOfInterestCategoryBakery = @"MKPOICategoryBakery";
NSString *const MKPointOfInterestCategoryBank = @"MKPOICategoryBank";
NSString *const MKPointOfInterestCategoryBeach = @"MKPOICategoryBeach";
NSString *const MKPointOfInterestCategoryBrewery = @"MKPOICategoryBrewery";
NSString *const MKPointOfInterestCategoryCafe = @"MKPOICategoryCafe";
NSString *const MKPointOfInterestCategoryCampground = @"MKPOICategoryCampground";
NSString *const MKPointOfInterestCategoryCarRental = @"MKPOICategoryCarRental";
NSString *const MKPointOfInterestCategoryEVCharger = @"MKPOICategoryEVCharger";
NSString *const MKPointOfInterestCategoryFireStation = @"MKPOICategoryFireStation";
NSString *const MKPointOfInterestCategoryFitnessCenter = @"MKPOICategoryFitnessCenter";
NSString *const MKPointOfInterestCategoryFoodMarket = @"MKPOICategoryFoodMarket";
NSString *const MKPointOfInterestCategoryGasStation = @"MKPOICategoryGasStation";
NSString *const MKPointOfInterestCategoryHospital = @"MKPOICategoryHospital";
NSString *const MKPointOfInterestCategoryHotel = @"MKPOICategoryHotel";
NSString *const MKPointOfInterestCategoryLaundry = @"MKPOICategoryLaundry";
NSString *const MKPointOfInterestCategoryLibrary = @"MKPOICategoryLibrary";
NSString *const MKPointOfInterestCategoryMarina = @"MKPOICategoryMarina";
NSString *const MKPointOfInterestCategoryMovieTheater = @"MKPOICategoryMovieTheater";
NSString *const MKPointOfInterestCategoryMuseum = @"MKPOICategoryMuseum";
NSString *const MKPointOfInterestCategoryNationalPark = @"MKPOICategoryNationalPark";
NSString *const MKPointOfInterestCategoryNightlife = @"MKPOICategoryNightlife";
NSString *const MKPointOfInterestCategoryPark = @"MKPOICategoryPark";
NSString *const MKPointOfInterestCategoryParking = @"MKPOICategoryParking";
NSString *const MKPointOfInterestCategoryPharmacy = @"MKPOICategoryPharmacy";
NSString *const MKPointOfInterestCategoryPolice = @"MKPOICategoryPolice";
NSString *const MKPointOfInterestCategoryPostOffice = @"MKPOICategoryPostOffice";
NSString *const MKPointOfInterestCategoryPublicTransport = @"MKPOICategoryPublicTransport";
NSString *const MKPointOfInterestCategoryRestaurant = @"MKPOICategoryRestaurant";
NSString *const MKPointOfInterestCategoryRestroom = @"MKPOICategoryRestroom";
NSString *const MKPointOfInterestCategorySchool = @"MKPOICategorySchool";
NSString *const MKPointOfInterestCategoryStadium = @"MKPOICategoryStadium";
NSString *const MKPointOfInterestCategoryStore = @"MKPOICategoryStore";
NSString *const MKPointOfInterestCategoryTheater = @"MKPOICategoryTheater";
NSString *const MKPointOfInterestCategoryUniversity = @"MKPOICategoryUniversity";
NSString *const MKPointOfInterestCategoryWinery = @"MKPOICategoryWinery";
NSString *const MKPointOfInterestCategoryZoo = @"MKPOICategoryZoo";
