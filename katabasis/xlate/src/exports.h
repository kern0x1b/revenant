#pragma once

#include "macho.h"

#include <map>
#include <optional>
#include <set>
#include <string>
#include <vector>

namespace xlate {

// What the guest images define, looked up the way a two-level bind does it: a bind that names a library takes the
// export of the guest image that library is (and what that image re-exports), never that of another image that
// happens to define the same name, so a host framework's class is not taken by a guest image that also defines it.
// A bind that names no library (flat namespace, weak coalescing) takes the first image that defines the name.
// A bridge image stands for the host's libraries, so every bind that no library image answers may take its export.
//
// A bind names a library by the path in the binding image's load command, and an image answers to its install name,
// exactly: nothing here guesses that two paths are one library. Two images with one install name are an error, not a
// choice. A guest image that takes the place of a library under another name (the recipe-built libc++ is
// @rpath/libc++.1.dylib and stands for /usr/lib/libc++.1.dylib) is said to do so by the invoker, through Replace.
class GuestExports {
 public:
  // False, with the reason in `error`, when another image already has this install name.
  bool Add(const Image &image, bool bridge, std::string &error);
  // False, with the reason in `error`, when the library is already replaced or is the install name of an image: the
  // invoker would be choosing between two answers by the order of the arguments.
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

}  // namespace xlate
