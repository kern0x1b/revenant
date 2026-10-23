#include "emulator_main.h"

#include <stdio.h>
#include <string.h>

#include <string>

#include <gtest/gtest.h>

namespace {

const char kFilterPath[] = "/var/root/gtest_filter";
const char kResultsPath[] = "/var/root/gtest.json";

}  // namespace

void ApplyEmulatorGtestFilter() {
  setvbuf(stdout, NULL, _IONBF, 0);
  FILE *file = fopen(kFilterPath, "r");
  if (file == NULL) {
    return;
  }
  static char filter[16384];
  if (fgets(filter, sizeof(filter), file) != NULL) {
    filter[strcspn(filter, "\r\n")] = '\0';
    testing::GTEST_FLAG(filter) = filter;
    testing::GTEST_FLAG(output) = std::string("json:") + kResultsPath;
  }
  fclose(file);
}
