/* port-store-rule.h -- the one predicate that decides whether a write may be sent to a store.
 *
 * On this Mac, ASCredentialIdentityStore's four writing methods change the USER'S AutoFill state, so the
 * host side of this family is read-only and the port's own store case is the only thing in it that
 * writes. The rule is about the RECEIVER, not the name of a selector and not the spelling of a class in
 * the source: a probe that sends writing selectors as strings through a cast objc_msgSend passes every
 * check that reads words, which is what the first two versions of the static guard did.
 *
 * So the answer comes from the runtime: the receiver's own class name, compared against the prefix the
 * harness gave for the port's classes. A probe that cannot name the port's class cannot pass it, and
 * this Mac's own class -- whose name is the release's own -- cannot pass it either.
 *
 * The prefix is passed in rather than compiled in, so that the probe and the guard's self-test run the
 * same predicate without either knowing the other's spelling.
 */
#ifndef PORT_STORE_RULE_H
#define PORT_STORE_RULE_H

#include <string.h>
#include <objc/runtime.h>

/* The class of a receiver, for the check. An INSTANCE's class: a class object is refused, which is what
 * makes the self-test's question about the host's class object meaningful without sending anything. */
static inline const char *port_store_receiver_class(id receiver)
{
    return object_getClass(receiver) ? class_getName(object_getClass(receiver)) : "?";
}

static inline int port_store_receiver_is_the_ports(id receiver, const char *prefix)
{
    const char *name = port_store_receiver_class(receiver);
    return name && prefix && strncmp(name, prefix, strlen(prefix)) == 0;
}

#endif
