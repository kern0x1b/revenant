#ifndef CHARON_OS_SYSTEM_VERSION_GET_CURRENT_VERSION_H
#define CHARON_OS_SYSTEM_VERSION_GET_CURRENT_VERSION_H

/* The caller defines the structure (libxpc's major, minor, patch, each an unsigned int), as Swift's runtime does; the
   declaration only names it. */
struct os_system_version_s;

#ifdef __cplusplus
extern "C" {
#endif

int charon_os_system_version_get_current_version(struct os_system_version_s *version);

#ifdef __cplusplus
}
#endif

#define os_system_version_get_current_version charon_os_system_version_get_current_version

#endif
