#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>

void revenant_SensorKitBackports_protocols(void);

static unsigned descriptions(Protocol *protocol, BOOL required)
{
    unsigned count = 0;
    protocol_copyMethodDescriptionList(protocol, required, YES, &count);
    return count;
}

int main(void)
{
    revenant_SensorKitBackports_protocols();
    Protocol *protocol = objc_getProtocol("SRSensorReaderDelegate");
    printf("the PORT's emitted protocol: %s, %u optional, %u required\n",
           protocol ? "found" : "ABSENT",
           protocol ? descriptions(protocol, NO) : 0u,
           protocol ? descriptions(protocol, YES) : 0u);
    return 0;
}
