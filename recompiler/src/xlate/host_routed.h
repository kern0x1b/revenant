#pragma once

#include <set>
#include <string>

namespace xlate {

inline const std::set<std::string> &HostRoutedSymbols() {
  static const std::set<std::string> symbols = {
      "___cxa_allocate_exception",
      "___cxa_free_exception",
      "___cxa_throw",
      "___cxa_rethrow",
      "___cxa_begin_catch",
      "___cxa_end_catch",
      "___cxa_get_exception_ptr",
      "___cxa_current_exception_type",
      "___cxa_current_primary_exception",
      "___cxa_rethrow_primary_exception",
      "___cxa_increment_exception_refcount",
      "___cxa_decrement_exception_refcount",
      "___cxa_uncaught_exception",
      "___cxa_uncaught_exceptions",
      "___cxa_init_primary_exception",
      "___cxa_allocate_dependent_exception",
      "___cxa_free_dependent_exception",
      "__ZNSt13exception_ptr31__from_native_exception_pointerEPv",
      "__ZNSt13exception_ptrC1ERKS_",
      "__ZNSt13exception_ptrC2ERKS_",
      "__ZNSt13exception_ptrD1Ev",
      "__ZNSt13exception_ptrD2Ev",
      "__ZNSt13exception_ptraSERKS_",
      "__ZSt17current_exceptionv",
      "__ZSt17rethrow_exceptionSt13exception_ptr",
      "__ZSt18uncaught_exceptionv",
      "__ZSt19uncaught_exceptionsv",
  };
  return symbols;
}

inline bool IsHostRouted(const std::string &symbol) {
  return HostRoutedSymbols().count(symbol) != 0;
}

inline std::string HostRoutedHandler(const std::string &symbol) {
  return "xl_h_" + symbol.substr(1);
}

}
