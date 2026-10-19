#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

struct os_system_version_s {
    unsigned int major;
    unsigned int minor;
    unsigned int patch;
};

int charon_os_system_version_get_current_version(struct os_system_version_s *version);

int main(void)
{
    int (*system)(struct os_system_version_s *) = dlsym(RTLD_DEFAULT, "os_system_version_get_current_version");
    struct os_system_version_s ours = {0, 0, 0}, darwins = {0, 0, 0};
    int failed = 0;
    if (!system) {
        printf("FAIL  the host must have os_system_version_get_current_version to compare against\n");
        return 1;
    }
    if (system(&darwins) != 0 || charon_os_system_version_get_current_version(&ours) != 0) {
        printf("FAIL  os_system_version_get_current_version must answer\n");
        return 1;
    }
    if (memcmp(&ours, &darwins, sizeof ours) != 0 || ours.major == 0) {
        printf("FAIL  the release's version is %u.%u.%u, and the shim answers %u.%u.%u\n", darwins.major, darwins.minor,
               darwins.patch, ours.major, ours.minor, ours.patch);
        failed = 1;
    }
    return failed;
}
