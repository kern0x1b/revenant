#ifndef REVENANT_COREHAPTICS_ORACLE_H
#define REVENANT_COREHAPTICS_ORACLE_H

#import <Foundation/Foundation.h>

typedef struct {
    double relative;
    double duration;
    float intensity;
    int transient;
} RevenantOracleEvent;

NSTimeInterval revenant_apple_pattern_duration(const RevenantOracleEvent *events, int count);
NSDictionary *revenant_apple_pattern_dictionary(const RevenantOracleEvent *events, int count);
NSString *revenant_apple_event_type_transient(void);
NSString *revenant_apple_event_type_continuous(void);
NSString *revenant_apple_parameter_intensity(void);
NSString *revenant_apple_parameter_sharpness(void);
NSString *revenant_apple_dynamic_intensity(void);
NSString *revenant_apple_dynamic_sharpness(void);

#endif
