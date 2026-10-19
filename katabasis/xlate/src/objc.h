#pragma once

#include "exports.h"
#include "macho.h"

#include <llvm/Support/raw_ostream.h>

#include <map>
#include <string>
#include <vector>

namespace xlate {

struct Pointer {
  enum Kind { Null, Local, Import, Raw } kind = Null;
  uint64_t host = 0;
  std::string symbol;
  std::string library;  // install name of the dylib an Import names; empty when it names none
};

struct Method {
  std::string selector;
  std::string types;
  uint64_t name_address = 0;
  uint64_t types_address = 0;
  uint64_t imp = 0;
};

struct Ivar {
  std::string name;
  std::string type;
  uint64_t offset_address = 0;
  uint32_t offset_value = 0;
  uint64_t name_address = 0;
  uint64_t type_address = 0;
  uint32_t alignment = 0;
  uint32_t size = 0;
};

struct Property {
  std::string name;
  std::string attributes;
  uint64_t name_address = 0;
  uint64_t attributes_address = 0;
};

struct ObjCProtocol {
  uint64_t address = 0;
  std::string name;
  uint64_t name_address = 0;
  std::vector<uint64_t> protocols;
  std::vector<Method> instance_methods;
  std::vector<Method> class_methods;
  std::vector<Method> optional_instance_methods;
  std::vector<Method> optional_class_methods;
  std::vector<Property> properties;
  uint32_t flags = 0;
  uint32_t size = 0;
};

struct ClassData {
  uint32_t flags = 0;
  uint32_t instance_start = 0;
  uint32_t instance_size = 0;
  std::string name;
  uint64_t name_address = 0;
  std::vector<Method> methods;
  std::vector<Ivar> ivars;
  std::vector<Property> properties;
  std::vector<uint64_t> protocols;
};

struct ObjCClass {
  uint64_t address = 0;
  // Swift's class metadata, not an Objective-C class: the data word carries the Swift flags in its low bits.
  bool swift = false;
  Pointer superclass;
  ClassData data;
  uint64_t metaclass = 0;
  Pointer meta_isa;
  Pointer meta_superclass;
  ClassData meta_data;
};

struct ObjCCategory {
  std::string name;
  uint64_t name_address = 0;
  Pointer cls;
  std::vector<Method> instance_methods;
  std::vector<Method> class_methods;
  std::vector<Property> properties;
  std::vector<uint64_t> protocols;
};

struct ConstantString {
  uint64_t address = 0;
  uint32_t flags = 0;
  uint64_t string = 0;
  uint64_t length = 0;
};

struct SelectorReference {
  uint64_t slot = 0;
  uint64_t string = 0;
  std::string selector;
};

struct ObjCImage {
  std::vector<ObjCClass> classes;
  // Class objects (and their metaclasses) that Swift laid out statically and listed in __objc_clsrolist by their
  // class_ro_t: the compiler leaves them out of __objc_classlist, so the Objective-C runtime never learns of them at
  // load. Found by the slot that holds each listed ro (a class object's data word, at +32).
  std::vector<uint64_t> swift_static_classes;
  // The superclass of the class half of each __objc_clsrolist-only pair (not the metaclass), read from the class object the
  // same way AnalyzeObjC reads it for a __objc_classlist class: SplitGuestLayoutClasses's ancestor walk needs it when a
  // __objc_classlist class's superclass is one of these -- a guest-owned ancestor __objc_classlist itself does not know of.
  std::vector<std::pair<uint64_t, Pointer>> clsrolist_superclass;
  // The classes among them that the compiler listed in __objc_classlist, which the Objective-C runtime registers at load:
  // they get their shadows at start-up (runtime/swift_classes.m), so a lookup by name finds them, as it does on a device.
  std::vector<uint64_t> swift_listed_classes;
  // The number of class_ro_t entries in __objc_clsrolist, and how many of them no static class object holds (the
  // class the Swift runtime builds for itself from that ro).
  uint64_t clsrolist_count = 0;
  uint64_t clsrolist_unowned = 0;
  std::vector<ObjCCategory> categories;
  std::vector<ObjCProtocol> protocols;
  std::vector<ConstantString> strings;
  std::vector<SelectorReference> selectors;
  std::vector<std::string> errors;
};

ObjCImage AnalyzeObjC(const Image &image);
void ResolveGuestImports(std::vector<ObjCImage> &objc, const GuestExports &exports);
// Take the Swift classes whose ancestry is the guest's own out of the class lists and into swift_static_classes: they keep
// the arm64 layout Swift reads, and get a host shadow class at run time (runtime/swift_classes.m). A Swift class with a
// host ancestor (an NSArray subclass, say) keeps the host layout, since host code sends its instances messages; so does
// every Objective-C class. False, with the reason, when a category or an Objective-C subclass names a class that moved.
bool SplitGuestLayoutClasses(std::vector<ObjCImage> &objc, std::string &error);
void WriteManifest(llvm::raw_ostream &os, const std::vector<const Image *> &images, const std::vector<ObjCImage> &objc);

}  // namespace xlate
