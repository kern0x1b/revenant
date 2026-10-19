#import <Foundation/Foundation.h>
#import <Matter/Matter.h>

static void say(NSString *name, id answer)
{
    printf("%s\t%s\n", name.UTF8String, [[answer description] UTF8String]);
    fflush(stdout);
}

static void commissioning(void)
{
    MTRSetupPayload *payload = [[MTRSetupPayload alloc] initWithSetupPasscode:@(20202021) discriminator:@(3840)];
    say(@"commissioning/vendorID", payload.vendorID);
    say(@"commissioning/productID", payload.productID);
    say(@"commissioning/setupPasscode", payload.setupPasscode);
    say(@"commissioning/discriminator", payload.discriminator);
    say(@"commissioning/hasShortDiscriminator", @(payload.hasShortDiscriminator));
    say(@"commissioning/commissioningFlow", @(payload.commissioningFlow));
    say(@"commissioning/serialNumber", payload.serialNumber ?: @"(nil)");
    say(@"commissioning/manualEntryCode", payload.manualEntryCode ?: @"(nil)");

    say(@"commissioning/isValidSetupPasscode/20202021", @([MTRSetupPayload isValidSetupPasscode:@(20202021)]));
    say(@"commissioning/isValidSetupPasscode/1234", @([MTRSetupPayload isValidSetupPasscode:@(1234)]));

    NSString *written = payload.manualEntryCode;
    MTRManualSetupPayloadParser *manual = [[MTRManualSetupPayloadParser alloc] initWithDecimalStringRepresentation:written];
    NSError *error = nil;
    MTRSetupPayload *fromManual = [manual populatePayload:&error];
    if (fromManual) {
        say(@"commissioning/manual/setupPasscode", fromManual.setupPasscode);
        say(@"commissioning/manual/discriminator", fromManual.discriminator);
        say(@"commissioning/manual/hasShortDiscriminator", @(fromManual.hasShortDiscriminator));
        say(@"commissioning/manual/commissioningFlow", @(fromManual.commissioningFlow));
    } else {
        say(@"commissioning/manual", error.localizedDescription ?: @"nil");
    }

    say(@"commissioning/manualCode", written);

    MTRManualSetupPayloadParser *bad = [[MTRManualSetupPayloadParser alloc] initWithDecimalStringRepresentation:@"1"];
    MTRSetupPayload *fromBad = [bad populatePayload:&error];
    say(@"commissioning/manualBad", fromBad ? @"a payload" : (error.localizedDescription ?: @"nil"));

    MTRSetupPayload *onboarding = [[MTRSetupPayload alloc] initWithPayload:@"MT:Y.K90SO527JA0648G00"];
    if (onboarding) {
        say(@"commissioning/onboarding/vendorID", onboarding.vendorID);
        say(@"commissioning/onboarding/productID", onboarding.productID);
        say(@"commissioning/onboarding/setupPasscode", onboarding.setupPasscode);
        say(@"commissioning/onboarding/discriminator", onboarding.discriminator);
        say(@"commissioning/onboarding/commissioningFlow", @(onboarding.commissioningFlow));
    } else {
        say(@"commissioning/onboarding", @"nil");
    }

    say(@"commissioning/badPayload", [[MTRSetupPayload alloc] initWithPayload:@"MT:NOTAPAYLOAD"] ? @"a payload" : @"nil");

    MTRCommissioningParameters *parameters = [[MTRCommissioningParameters alloc] init];
    say(@"commissioning/parameters/csrNonce", parameters.csrNonce ?: @"(nil)");
    say(@"commissioning/parameters/attestationNonce", parameters.attestationNonce ?: @"(nil)");
    say(@"commissioning/parameters/wifiSSID", parameters.wifiSSID ?: @"(nil)");
    say(@"commissioning/parameters/failSafeTimeout", parameters.failSafeTimeout ?: @"(nil)");
    say(@"commissioning/parameters/skipCommissioningComplete", @(parameters.skipCommissioningComplete));
    say(@"commissioning/parameters/countryCode", parameters.countryCode ?: @"(nil)");
    say(@"commissioning/parameters/deviceAttestationDelegate", parameters.deviceAttestationDelegate ? @"set" : @"(nil)");
}

static void controller(void)
{
    NSArray<NSString *> *classes = MTRDeviceControllerStorageClasses();
    say(@"controller/storageClasses/count", @(classes.count));
    for (NSString *name in classes) {
        say(([NSString stringWithFormat:@"controller/storageClass/%@", name]), @"yes");
    }
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        commissioning();
        controller();
    }
    return 0;
}
