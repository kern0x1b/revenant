#include "JSIUtils.h"

#ifdef RN_HERMES
#include <hermes/hermes.h>
#else
// iOS 6 port: the engine is JavaScriptCore (ReactCommon/jsc over the prefixed JSC C API), not Hermes.
#include <jsc/JSCRuntime.h>
#endif

namespace expo {

jsi::Runtime* createHermesRuntime() {
#ifdef RN_HERMES
  std::unique_ptr<jsi::Runtime> runtimePtr = facebook::hermes::makeHermesRuntime();
#else
  std::unique_ptr<jsi::Runtime> runtimePtr = facebook::jsc::makeJSCRuntime();
#endif
  jsi::Runtime *runtime = runtimePtr.release();

  // `setImmediate` isn't defined by JSC either; inject it as the Hermes version did.
  auto setImmediatePropName = jsi::PropNameID::forUtf8(*runtime, "setImmediate");
  auto setImmediateFunction = jsi::Function::createFromHostFunction(*runtime, setImmediatePropName, 1, [](jsi::Runtime &rt, const jsi::Value &thisVal, const jsi::Value *args, size_t count) {
    if (count < 1) {
      return jsi::Value::undefined();
    }
    args[0].asObject(rt).asFunction(rt).call(rt);
    return jsi::Value::undefined();
  });
  runtime->global().setProperty(*runtime, setImmediatePropName, setImmediateFunction);

  return runtime;
}

} // namespace expo
