#ifndef REVENANT_OS_SYSTEM_VERSION_GET_CURRENT_VERSION_H
#define REVENANT_OS_SYSTEM_VERSION_GET_CURRENT_VERSION_H

struct os_system_version_s;

#ifdef __cplusplus
extern "C" {
#endif

int revenant_os_system_version_get_current_version(struct os_system_version_s *version);

#ifdef __cplusplus
}
#endif

#define os_system_version_get_current_version revenant_os_system_version_get_current_version

#endif
