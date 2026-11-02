#import "RNHostHostFunctions.h"

#import <Foundation/Foundation.h>

#include <string>

using facebook::jsi::Function;
using facebook::jsi::PropNameID;
using facebook::jsi::Runtime;
using facebook::jsi::Value;

namespace {

const char *const kUnimplementedHostFunctions[] = {
    "nativeFlushQueueImmediate",
    "nativeCallSyncHook",
};

Value RNHostNativeLoggingHook(Runtime &runtime, const Value &, const Value *arguments, size_t count)
{
    std::string message = count > 0 ? arguments[0].toString(runtime).utf8(runtime) : std::string();
    int level = count > 1 && arguments[1].isNumber() ? static_cast<int>(arguments[1].getNumber()) : 0;
    NSLog(@"rn-host: js[%d]: %s", level, message.c_str());
    return Value::undefined();
}

void RNHostInstallNotImplemented(Runtime &runtime, const char *name)
{
    std::string functionName(name);
    Function function = Function::createFromHostFunction(
        runtime,
        PropNameID::forAscii(runtime, functionName),
        0,
        [functionName](Runtime &runtime, const Value &, const Value *, size_t) -> Value {
            throw facebook::jsi::JSError(runtime, "not implemented: " + functionName);
        });
    runtime.global().setProperty(runtime, name, std::move(function));
}

}

void RNHostInstallHostFunctions(Runtime &runtime)
{
    Function logging = Function::createFromHostFunction(
        runtime,
        PropNameID::forAscii(runtime, "nativeLoggingHook"),
        2,
        RNHostNativeLoggingHook);
    runtime.global().setProperty(runtime, "nativeLoggingHook", std::move(logging));

    for (const char *name : kUnimplementedHostFunctions) {
        RNHostInstallNotImplemented(runtime, name);
    }
}
