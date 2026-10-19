// The _availability_version_check that dyld provides from iOS 12: guest code, compiled for arm64 and lifted
// with the image that calls it. compiler-rt's @available check in an arm64 image takes this function when
// the symbol is bound; unbound, it falls back to CoreFoundation function pointers from dlsym, which on the
// armv7 host are host addresses the guest cannot call. The answer is the device's own release, read from
// the record it keeps of it, as compiler-rt's armv7 fallback does.
#include <stdint.h>
#include <stdio.h>
#include <string.h>

struct build_version {
  uint32_t platform;
  uint32_t version;
};

enum { PLATFORM_IOS = 2 };

static uint32_t device_version;
static int device_version_read;

static uint32_t read_device_version(void) {
  char text[4096];
  FILE *file = fopen("/System/Library/CoreServices/SystemVersion.plist", "r");
  if (!file) return 0;
  size_t length = fread(text, 1, sizeof text - 1, file);
  fclose(file);
  text[length] = 0;
  const char *key = strstr(text, "<key>ProductVersion</key>");
  const char *value = key ? strstr(key, "<string>") : 0;
  if (!value) return 0;
  uint32_t parts[3] = {0, 0, 0};
  int part = 0;
  for (value += strlen("<string>"); part < 3; value++) {
    if (*value >= '0' && *value <= '9') parts[part] = parts[part] * 10 + (uint32_t)(*value - '0');
    else if (*value == '.') part++;
    else break;
  }
  return parts[0] << 16 | parts[1] << 8 | parts[2];
}

int _availability_version_check(uint32_t count, const struct build_version *versions) {
  if (!device_version_read) {
    device_version = read_device_version();
    device_version_read = 1;
    if (!device_version) fputs("xlate: cannot read ProductVersion from SystemVersion.plist; every @available check answers no\n", stderr);
  }
  // A release that cannot be read counts as version 0: a false answer takes the code written for a release
  // without the API, where a true one would call an API the device may not have.
  for (uint32_t i = 0; i < count; i++)
    if (versions[i].platform == PLATFORM_IOS)
      return device_version >= versions[i].version;
  return 1;
}
