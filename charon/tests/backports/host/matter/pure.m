/*
 * The parts of Matter an application meets first, held against the host's own framework.
 *
 * Commissioning, reading and writing an attribute on MTRBaseDevice, and MTRDeviceController: the first three things
 * a program does. What is here is what of those three the host can be asked with no device on the other end, because
 * that is the only part that can be held to a reference at all:
 *
 *   - the setup payload, built from a passcode and a discriminator and read back; the manual-entry parser over the
 *     eleven decimal digits of that payload; the onboarding-payload parser over its base38 form; a payload that is not
 *     one, so the failure answer is compared too and not only the happy path; and the commissioning parameters' own
 *     defaults, which a program reads before it has a device;
 *   - the shape of the three areas' classes and of MTRDeviceControllerStorageClasses(), which needs no controller.
 *
 * The output is one "name<TAB>answer" line per question. This is the HOST half alone. The port's product carries the
 * cluster and data classes only, not the setup payload, the commissioning parameters or the controller's storage
 * classes asked about above, so there is no port-side run of this file in the tree and none is compared: the 38
 * answers are outside the product, and are not passed. tools/matter-pure-diff.lua reads two such files and names every
 * line that differs, for a product that carries those classes.
 */

#import <Foundation/Foundation.h>
#import <Matter/Matter.h>

static void say(NSString *name, id answer)
{
    printf("%s\t%s\n", name.UTF8String, [[answer description] UTF8String]);
    fflush(stdout);
}

static void commissioning(void)
{
    // A standard-flow payload: the passcode 20202021 and the discriminator 3840, which is the discriminator Matter's
    // own documentation works with, and which gives the eleven-digit manual entry code 20202021384.
    MTRSetupPayload *payload = [[MTRSetupPayload alloc] initWithSetupPasscode:@(20202021) discriminator:@(3840)];
    say(@"commissioning/vendorID", payload.vendorID);
    say(@"commissioning/productID", payload.productID);
    say(@"commissioning/setupPasscode", payload.setupPasscode);
    say(@"commissioning/discriminator", payload.discriminator);
    say(@"commissioning/hasShortDiscriminator", @(payload.hasShortDiscriminator));
    say(@"commissioning/commissioningFlow", @(payload.commissioningFlow));
    say(@"commissioning/serialNumber", payload.serialNumber ?: @"(nil)");
    say(@"commissioning/manualEntryCode", payload.manualEntryCode ?: @"(nil)");

    // The passcode the framework itself accepts, and one it does not.
    say(@"commissioning/isValidSetupPasscode/20202021", @([MTRSetupPayload isValidSetupPasscode:@(20202021)]));
    say(@"commissioning/isValidSetupPasscode/1234", @([MTRSetupPayload isValidSetupPasscode:@(1234)]));

    // The same payload the manual way, from the code the framework itself wrote out of it. A hand-written code would
    // test the parser against this session's guess at its format; the framework's own code tests the round trip, and
    // the code it writes is one of the answers the port has to reproduce.
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

    // A manual code that is not one, so the failure answer is compared and not only the happy path.
    MTRManualSetupPayloadParser *bad = [[MTRManualSetupPayloadParser alloc] initWithDecimalStringRepresentation:@"1"];
    MTRSetupPayload *fromBad = [bad populatePayload:&error];
    say(@"commissioning/manualBad", fromBad ? @"a payload" : (error.localizedDescription ?: @"nil"));

    // The onboarding payload of the same commissioning code, read the base38 way.
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

    // A payload that is not one at all.
    say(@"commissioning/badPayload", [[MTRSetupPayload alloc] initWithPayload:@"MT:NOTAPAYLOAD"] ? @"a payload" : @"nil");

    // The commissioning parameters' own defaults: what a program reads before it has anything to commission.
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
    // The names the controller persists its store under: a program reads them to find where the controller put its
    // data, and it needs no controller to ask.
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
