#pragma once

#include "macho.h"

#include <map>
#include <optional>
#include <set>
#include <string>
#include <vector>

namespace xlate {

class GuestExports {
 public:
  bool Add(const Image &image, bool bridge, std::string &error);
  bool Replace(const std::string &library, const Image &image, std::string &error);
  std::optional<uint64_t> Find(const std::string &library, const std::string &symbol) const;

 private:
  std::optional<uint64_t> Find(const std::string &library, const std::string &symbol, unsigned depth) const;
  const Image *ImageOf(const std::string &library) const;

  std::vector<const Image *> images_;
  std::vector<const Image *> bridges_;
  std::map<std::string, const Image *> by_name_;
  std::map<std::string, const Image *> replaced_;
  mutable std::set<std::string> reported_;
};

}
