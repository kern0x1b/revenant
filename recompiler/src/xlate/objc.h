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
  std::string library;
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
  std::vector<uint64_t> swift_static_classes;
  std::vector<std::pair<uint64_t, Pointer>> clsrolist_superclass;
  std::vector<uint64_t> swift_listed_classes;
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
bool SplitGuestLayoutClasses(std::vector<ObjCImage> &objc, std::string &error);
void WriteManifest(llvm::raw_ostream &os, const std::vector<const Image *> &images, const std::vector<ObjCImage> &objc);

}
