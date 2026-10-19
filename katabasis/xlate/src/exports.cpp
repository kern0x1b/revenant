#include "exports.h"

#include <llvm/Support/raw_ostream.h>

namespace xlate {

namespace {

constexpr unsigned kMaxReexportDepth = 8;

bool IsSystemPath(const std::string &path) {
  return path.rfind("/System/", 0) == 0 || path.rfind("/usr/lib/", 0) == 0;
}

std::string Leaf(const std::string &path) {
  auto slash = path.rfind('/');
  return slash == std::string::npos ? path : path.substr(slash + 1);
}

}  // namespace

bool GuestExports::Add(const Image &image, bool bridge, std::string &error) {
  if (!image.install_name().empty()) {
    auto [existing, added] = by_name_.emplace(image.install_name(), &image);
    if (!added) {
      error = image.path() + " and " + existing->second->path() + " are both " + image.install_name() +
              "; a bind to that library would take either";
      return false;
    }
  }
  for (auto &[name, vmaddr] : image.exports()) {
    // A class two guest images both define is told apart by the library a bind names; a bind with none gets the first.
    if (name.rfind("_OBJC_CLASS_$_", 0) != 0) {
      continue;
    }
    for (auto earlier : images_) {
      if (earlier->exports().count(name)) {
        llvm::errs() << "xlate: " << image.path() << ": " << name << " is also defined by " << earlier->path()
                     << "; a bind that names no library takes that one\n";
        break;
      }
    }
  }
  images_.push_back(&image);
  if (bridge) {
    bridges_.push_back(&image);
  }
  return true;
}

bool GuestExports::Replace(const std::string &library, const Image &image, std::string &error) {
  if (auto found = by_name_.find(library); found != by_name_.end()) {
    error = "--replaces " + library + ": that is the install name of " + found->second->path();
    return false;
  }
  auto [existing, added] = replaced_.emplace(library, &image);
  if (!added) {
    error = "--replaces " + library + " is given twice, for " + existing->second->path() + " and " + image.path();
    return false;
  }
  return true;
}

const Image *GuestExports::ImageOf(const std::string &library) const {
  if (auto found = replaced_.find(library); found != replaced_.end()) {
    return found->second;
  }
  if (auto found = by_name_.find(library); found != by_name_.end()) {
    return found->second;
  }
  return nullptr;
}

std::optional<uint64_t> GuestExports::Find(const std::string &library, const std::string &symbol) const {
  return Find(library, symbol, 0);
}

std::optional<uint64_t> GuestExports::Find(const std::string &library, const std::string &symbol, unsigned depth) const {
  if (library.empty()) {
    for (auto image : images_) {
      if (auto found = image->exports().find(symbol); found != image->exports().end()) {
        return image->host(found->second);
      }
    }
    return std::nullopt;
  }
  if (auto image = ImageOf(library)) {
    if (auto exported = image->exports().find(symbol); exported != image->exports().end()) {
      return image->host(exported->second);
    }
    if (auto sent = image->reexports().find(symbol); sent != image->reexports().end() && depth < kMaxReexportDepth) {
      if (auto target = Find(sent->second.library, sent->second.symbol, depth + 1)) {
        return target;
      }
    }
    if (depth < kMaxReexportDepth) {
      for (auto &whole : image->reexported_libraries()) {
        if (ImageOf(whole)) {
          if (auto target = Find(whole, symbol, depth + 1)) {
            return target;
          }
        }
      }
    }
  } else if (reported_.insert(library).second) {
    // What a library is by its file name is a guess xlate does not act on; it only says the guess is available.
    const Image *alike = nullptr;
    for (auto image : images_) {
      if (!image->install_name().empty() && Leaf(image->install_name()) == Leaf(library)) {
        alike = image;
      }
    }
    if (alike) {
      llvm::errs() << "xlate: a bind names " << library << ", which no guest image is; " << alike->path() << " is named "
                   << alike->install_name() << ". If it stands for that library, say so with --replaces " << library << "="
                   << alike->path() << "; its symbols are taken from the host\n";
    } else if (!IsSystemPath(library)) {
      // Right for a framework the build does not lift, wrong for a library a guest image is under another spelling.
      llvm::errs() << "xlate: a bind names " << library << ", which is no guest image and no system library; "
                   << "its symbols are taken from the host\n";
    }
  }
  for (auto bridge : bridges_) {
    if (auto exported = bridge->exports().find(symbol); exported != bridge->exports().end()) {
      return bridge->host(exported->second);
    }
  }
  return std::nullopt;
}

}  // namespace xlate
