#pragma once

template <typename T> struct Tls {
  inline static thread_local int value = 0;
};

inline int tlsRead() { return Tls<int>::value; }
