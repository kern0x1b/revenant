/*
 * The error domains of Network, as the symbols the SDK exports for them.
 *
 * The values are not guesses and not the names: each is the CFString a real release holds in that
 * global, read out of the host's own Network.framework (macOS 27.0, build 26A428) with a program
 * that prints what the symbol points at. Three of the four agree with what the iOS 12 release's
 * shared cache holds for the same symbols, and the two that name their own symbol name are what the
 * system itself uses, so a program that compares a domain string sees what it would see on a
 * release that has Network.
 */

#import <Foundation/Foundation.h>
#import <Network/Network.h>

const CFStringRef kNWErrorDomainPOSIX = CFSTR("NSPOSIXErrorDomain");
const CFStringRef kNWErrorDomainDNS = CFSTR("kNWErrorDomainDNS");
const CFStringRef kNWErrorDomainTLS = CFSTR("NSOSStatusErrorDomain");
