#pragma once
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace probe {
class Counter {
 public:
  explicit Counter(int start) : value_(start) {}
  int next() { return ++value_; }
  std::string describe() const { return "counter:" + std::to_string(value_); }
  std::vector<int> range(int n) const { std::vector<int> r; for (int i = 0; i < n; ++i) r.push_back(value_ + i); return r; }
 private:
  int value_;
};
inline std::shared_ptr<Counter> makeCounter(int start) { return std::make_shared<Counter>(start); }
inline std::unique_ptr<Counter> makeUnique(int start) { return std::make_unique<Counter>(start); }
inline std::string echo(const std::string &text) { return text + "!"; }
inline std::vector<std::string> split(const std::string &text) {
  std::vector<std::string> parts;
  std::string current;
  for (char c : text) {
    if (c == ',') { parts.push_back(current); current.clear(); }
    else current.push_back(c);
  }
  parts.push_back(current);
  return parts;
}
inline std::function<int(int)> adder(int n) { return [n](int x) { return x + n; }; }
inline int apply(std::function<int(int)> f, int x) { return f(x); }
inline std::optional<int> maybe(int x) { if (x > 0) return x * 2; return std::nullopt; }
inline std::map<std::string, int> counts() { return {{"one", 1}, {"two", 2}}; }
inline std::unordered_map<std::string, int> table() { return {{"three", 3}}; }
}
