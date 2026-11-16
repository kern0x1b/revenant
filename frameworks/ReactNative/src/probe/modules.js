var modules = globalThis.expo && globalThis.expo.modules;

function report(name, answer) {
  nativeLoggingHook('rn-probe ' + name + ' ' + JSON.stringify(answer), 1);
}

function present(name) {
  var module = modules && modules[name];
  if (!module) {
    return {ok: false, error: 'the module is not registered'};
  }
  return {ok: true, module: module, value: {exports: Object.keys(module).sort()}};
}

var CHECKS = {
  ExpoSecureStore: function (module) {
    var options = {keychainService: 'rn-probe', requireAuthentication: false};
    return module.setValueWithKeyAsync('probe-value', 'probe-key', options)
      .then(function () { return module.getValueWithKeyAsync('probe-key', options); })
      .then(function (value) {
        return module.deleteValueWithKeyAsync('probe-key', options).then(function () {
          return {roundTrip: value === 'probe-value', biometrics: module.canUseBiometricAuthentication()};
        });
      });
  },
  ExpoNetwork: function (module) {
    return module.getNetworkStateAsync();
  },
  ExpoDevice: function (module) {
    return {modelName: module.modelName, osVersion: module.osVersion, deviceYearClass: module.deviceYearClass, totalMemory: module.totalMemory};
  },
  ExpoBrightness: function (module) {
    return module.getBrightnessAsync();
  },
  ExpoStoreReview: function (module) {
    return module.isAvailableAsync();
  }
};

var NAMES = ['FileSystem', 'ExpoDocumentPicker', 'ExpoImageManipulator', 'ExpoImage', 'ExpoCamera', 'ExpoSecureStore', 'ExpoNetwork', 'ExpoDevice', 'ExpoBrightness', 'ExpoLinearGradient', 'ExpoStoreReview'];

NAMES.forEach(function (name) {
  var found = present(name);
  if (!found.ok) {
    report(name, found);
    return;
  }
  var check = CHECKS[name];
  if (!check) {
    report(name, {ok: true, value: found.value});
    return;
  }
  var outcome;
  try {
    outcome = Promise.resolve(check(found.module));
  } catch (error) {
    report(name, {ok: false, error: String(error)});
    return;
  }
  outcome.then(
    function (value) { report(name, {ok: true, value: value, exports: found.value.exports}); },
    function (error) { report(name, {ok: false, error: String(error && error.message || error)}); }
  );
});
