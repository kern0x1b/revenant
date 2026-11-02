#include <NitroModules/AnyMap.hpp>
#include <vector>

extern "C" bool nitroForceIteratorEquality(const std::vector<margelo::nitro::AnyValue>& values) {
  return values.cbegin() == values.cend();
}
