/*
 * The Wi-Fi Aware error domain, the one symbol of that API the port exports. The release this port
 * builds for has no Wi-Fi Aware radio, so nothing produces an error of that domain here; the symbol
 * is exported because the SDK declares it, and it carries the value the host's own Network holds for
 * it - its own name, as the other two self-named domains do. The declaration itself is the port's:
 * the SDK this port compiles against is 16.4, which predates the constant, and the value is the one
 * the header of a release that has it gives.
 */

#import <Foundation/Foundation.h>
#import <Network/Network.h>

const CFStringRef kNWErrorDomainWiFiAware = CFSTR("kNWErrorDomainWiFiAware");
