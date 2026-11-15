#pragma once

namespace opaque {

enum class Role { Pointer, Id };

constexpr int Result = -1;

struct Function {
  const char *api;
  int index;
  Role role;
  bool out;
  const char *meaning;
};

inline constexpr Function functions[] = {
    {"dispatch_async_f", 1, Role::Pointer, false, "the context of the work"},
    {"dispatch_sync_f", 1, Role::Pointer, false, "the context of the work"},
    {"dispatch_barrier_async_f", 1, Role::Pointer, false, "the context of the work"},
    {"dispatch_barrier_sync_f", 1, Role::Pointer, false, "the context of the work"},
    {"dispatch_after_f", 2, Role::Pointer, false, "the context of the work"},
    {"dispatch_apply_f", 2, Role::Pointer, false, "the context of the work"},
    {"dispatch_once_f", 1, Role::Pointer, false, "the context of the initializer"},
    {"dispatch_group_async_f", 2, Role::Pointer, false, "the context of the work"},
    {"dispatch_group_notify_f", 2, Role::Pointer, false, "the context of the work"},
    {"dispatch_set_context", 1, Role::Pointer, false, "the context of the object"},
    {"dispatch_get_context", Result, Role::Pointer, false, "the context of the object"},
    {"dispatch_queue_set_specific", 1, Role::Pointer, false, "the key of the specific value, compared by identity"},
    {"dispatch_queue_set_specific", 2, Role::Pointer, false, "the specific value of the queue"},
    {"dispatch_queue_get_specific", 1, Role::Pointer, false, "the key of the specific value, compared by identity"},
    {"dispatch_queue_get_specific", Result, Role::Pointer, false, "the specific value of the queue"},
    {"dispatch_get_specific", 0, Role::Pointer, false, "the key of the specific value, compared by identity"},
    {"dispatch_get_specific", Result, Role::Pointer, false, "the specific value of the current queue"},
    {"pthread_setspecific", 1, Role::Pointer, false, "the value of the key of the thread"},
    {"pthread_getspecific", Result, Role::Pointer, false, "the value of the key of the thread"},
    {"pthread_create", 3, Role::Pointer, false, "the argument of the start routine"},
    {"pthread_exit", 0, Role::Pointer, false, "the result of the thread"},
    {"pthread_join", 1, Role::Pointer, true, "the result of the thread"},
    {"qsort_r", 3, Role::Pointer, false, "the thunk of the comparison"},
    {"heapsort_r", 3, Role::Pointer, false, "the thunk of the comparison"},
    {"mergesort_r", 3, Role::Pointer, false, "the thunk of the comparison"},
    {"objc_setAssociatedObject", 1, Role::Pointer, false, "the key of the association, compared by identity"},
    {"objc_setAssociatedObject", 2, Role::Id, false, "the value, stored as it is with the policy assign"},
    {"objc_getAssociatedObject", 1, Role::Pointer, false, "the key of the association, compared by identity"},
    {"objc_getAssociatedObject", Result, Role::Id, false, "the value, stored as it is with the policy assign"},
    {"NSMapInsert", 1, Role::Pointer, false, "the key"},
    {"NSMapInsert", 2, Role::Pointer, false, "the value"},
    {"NSMapInsertKnownAbsent", 1, Role::Pointer, false, "the key"},
    {"NSMapInsertKnownAbsent", 2, Role::Pointer, false, "the value"},
    {"NSMapInsertIfAbsent", 1, Role::Pointer, false, "the key"},
    {"NSMapInsertIfAbsent", 2, Role::Pointer, false, "the value"},
    {"NSMapInsertIfAbsent", Result, Role::Pointer, false, "the value that was there"},
    {"NSMapRemove", 1, Role::Pointer, false, "the key"},
    {"NSMapGet", 1, Role::Pointer, false, "the key"},
    {"NSMapGet", Result, Role::Pointer, false, "the value"},
    {"NSMapMember", 1, Role::Pointer, false, "the key"},
    {"NSMapMember", 2, Role::Pointer, true, "the key that was stored"},
    {"NSMapMember", 3, Role::Pointer, true, "the value"},
    {"NSHashInsert", 1, Role::Pointer, false, "the member"},
    {"NSHashInsertKnownAbsent", 1, Role::Pointer, false, "the member"},
    {"NSHashInsertIfAbsent", 1, Role::Pointer, false, "the member"},
    {"NSHashInsertIfAbsent", Result, Role::Pointer, false, "the member that was there"},
    {"NSHashRemove", 1, Role::Pointer, false, "the member"},
    {"NSHashGet", 1, Role::Pointer, false, "the member"},
    {"NSHashGet", Result, Role::Pointer, false, "the member"},
    {"CFArrayCreate", 1, Role::Pointer, false, "the values"},
    {"CFArrayContainsValue", 2, Role::Pointer, false, "the value"},
    {"CFArrayGetCountOfValue", 2, Role::Pointer, false, "the value"},
    {"CFArrayGetFirstIndexOfValue", 2, Role::Pointer, false, "the value"},
    {"CFArrayGetLastIndexOfValue", 2, Role::Pointer, false, "the value"},
    {"CFArrayGetValueAtIndex", Result, Role::Pointer, false, "the value"},
    {"CFArrayAppendValue", 1, Role::Pointer, false, "the value"},
    {"CFArrayInsertValueAtIndex", 2, Role::Pointer, false, "the value"},
    {"CFArraySetValueAtIndex", 2, Role::Pointer, false, "the value"},
    {"CFArrayApplyFunction", 3, Role::Pointer, false, "the context of the applier"},
    {"CFArraySortValues", 3, Role::Pointer, false, "the context of the comparison"},
    {"CFDictionaryCreate", 1, Role::Pointer, false, "the keys"},
    {"CFDictionaryCreate", 2, Role::Pointer, false, "the values"},
    {"CFDictionaryGetValue", 1, Role::Pointer, false, "the key"},
    {"CFDictionaryGetValue", Result, Role::Pointer, false, "the value"},
    {"CFDictionaryGetValueIfPresent", 1, Role::Pointer, false, "the key"},
    {"CFDictionaryGetValueIfPresent", 2, Role::Pointer, true, "the value"},
    {"CFDictionaryContainsKey", 1, Role::Pointer, false, "the key"},
    {"CFDictionaryContainsValue", 1, Role::Pointer, false, "the value"},
    {"CFDictionaryGetCountOfKey", 1, Role::Pointer, false, "the key"},
    {"CFDictionaryGetCountOfValue", 1, Role::Pointer, false, "the value"},
    {"CFDictionaryAddValue", 1, Role::Pointer, false, "the key"},
    {"CFDictionaryAddValue", 2, Role::Pointer, false, "the value"},
    {"CFDictionarySetValue", 1, Role::Pointer, false, "the key"},
    {"CFDictionarySetValue", 2, Role::Pointer, false, "the value"},
    {"CFDictionaryReplaceValue", 1, Role::Pointer, false, "the key"},
    {"CFDictionaryReplaceValue", 2, Role::Pointer, false, "the value"},
    {"CFDictionaryRemoveValue", 1, Role::Pointer, false, "the key"},
    {"CFDictionaryApplyFunction", 2, Role::Pointer, false, "the context of the applier"},
    {"CFSetCreate", 1, Role::Pointer, false, "the values"},
    {"CFSetGetValue", 1, Role::Pointer, false, "the value"},
    {"CFSetGetValue", Result, Role::Pointer, false, "the value"},
    {"CFSetGetValueIfPresent", 1, Role::Pointer, false, "the candidate"},
    {"CFSetGetValueIfPresent", 2, Role::Pointer, true, "the value"},
    {"CFSetContainsValue", 1, Role::Pointer, false, "the value"},
    {"CFSetGetCountOfValue", 1, Role::Pointer, false, "the value"},
    {"CFSetAddValue", 1, Role::Pointer, false, "the value"},
    {"CFSetReplaceValue", 1, Role::Pointer, false, "the value"},
    {"CFSetSetValue", 1, Role::Pointer, false, "the value"},
    {"CFSetRemoveValue", 1, Role::Pointer, false, "the value"},
    {"CFSetApplyFunction", 2, Role::Pointer, false, "the context of the applier"},
    {"CFBagCreate", 1, Role::Pointer, false, "the values"},
    {"CFBagGetValue", 1, Role::Pointer, false, "the value"},
    {"CFBagGetValue", Result, Role::Pointer, false, "the value"},
    {"CFBagGetValueIfPresent", 1, Role::Pointer, false, "the candidate"},
    {"CFBagGetValueIfPresent", 2, Role::Pointer, true, "the value"},
    {"CFBagContainsValue", 1, Role::Pointer, false, "the value"},
    {"CFBagGetCountOfValue", 1, Role::Pointer, false, "the value"},
    {"CFBagAddValue", 1, Role::Pointer, false, "the value"},
    {"CFBagReplaceValue", 1, Role::Pointer, false, "the value"},
    {"CFBagSetValue", 1, Role::Pointer, false, "the value"},
    {"CFBagRemoveValue", 1, Role::Pointer, false, "the value"},
    {"CFBagApplyFunction", 2, Role::Pointer, false, "the context of the applier"},
};

struct Method {
  const char *selector;
  int index;
  const char *meaning;
};

inline constexpr Method methods[] = {
    {"performSelector:withObject:", 1, "the argument of the method that runs"},
    {"performSelector:withObject:withObject:", 1, "the first argument of the method that runs"},
    {"performSelector:withObject:withObject:", 2, "the second argument of the method that runs"},
};

struct Field {
  const char *record;
  const char *field;
};

inline constexpr Field fields[] = {
    {"CFRunLoopSourceContext", "info"}, {"CFRunLoopSourceContext1", "info"}, {"CFRunLoopObserverContext", "info"},
    {"CFRunLoopTimerContext", "info"},  {"CFStreamClientContext", "info"},   {"CFSocketContext", "info"},
    {"CFMachPortContext", "info"},      {"CFMessagePortContext", "info"},    {"CFFileDescriptorContext", "info"},
};

struct Input {
  const char *api;
  int index;
};

inline constexpr Input inputs[] = {
    {"CFRunLoopTimerCreate", 6}, {"CFRunLoopObserverCreate", 5}, {"CFRunLoopSourceCreate", 2}, {"CFReadStreamSetClient", 3},
    {"CFWriteStreamSetClient", 3}, {"CFMachPortCreate", 2}, {"CFMachPortCreateWithPort", 3}, {"CFMessagePortCreateLocal", 3},
    {"CFFileDescriptorCreate", 4}, {"CFSocketCreate", 6}, {"CFSocketCreateWithNative", 4},
};

}
