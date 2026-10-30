#pragma once

struct Tls {
  inline static thread_local int value = 0;
};

inline int tlsRead() { return Tls::value; }
