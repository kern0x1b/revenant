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
    function roundTrip(accessible) {
      var options = {keychainService: 'rn-probe', requireAuthentication: false};
      if (accessible !== undefined) {
        options.keychainAccessible = accessible;
      }
      return module.setValueWithKeyAsync('probe-value', 'probe-key', options)
        .then(function () { return module.getValueWithKeyAsync('probe-key', options); })
        .then(function (value) {
          return module.deleteValueWithKeyAsync('probe-key', options).then(function () { return value === 'probe-value'; });
        })
        .catch(function (error) { return String(error && error.message || error); });
    }
    var classes = {whenUnlocked: undefined, afterFirstUnlock: 0, always: 2};
    var names = Object.keys(classes);
    return names.reduce(function (chain, name) {
      return chain.then(function (answers) {
        return roundTrip(classes[name]).then(function (answer) { answers[name] = answer; return answers; });
      });
    }, Promise.resolve({})).then(function (answers) {
      return {roundTrip: answers, biometrics: module.canUseBiometricAuthentication()};
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
  },
  ExpoSQLite: function (module) {
    var database = new module.NativeDatabase(':memory:', {});
    function query(source) {
      var statement = new module.NativeStatement();
      return database.prepareAsync(statement, source).then(function () {
        return statement.runAsync(database);
      }).then(function (result) {
        return statement.finalizeAsync(database).then(function () { return result.firstRowValues; });
      });
    }
    return database.initAsync()
      .then(function () { return database.execAsync('CREATE TABLE t (a INTEGER); INSERT INTO t VALUES (2), (3);'); })
      .then(function () { return query('SELECT SUM(a) FROM t'); })
      .then(function (sum) {
        return query('SELECT sqlite_version()').then(function (version) { return {sum: sum, version: version}; });
      });
  },
  ExpoScreenOrientation: function (module) {
    return Promise.all([module.getOrientationAsync(), module.getOrientationLockAsync()]).then(function (answers) {
      var result = {orientation: answers[0], lock: answers[1]};
      return module.lockAsync(6).then(function () {
        return new Promise(function (resolve) { setTimeout(resolve, 1500); });
      }).then(function () {
        return Promise.all([module.getOrientationAsync(), module.getOrientationLockAsync()]);
      }).then(function (locked) {
        result.landscapeOrientation = locked[0];
        result.landscapeLock = locked[1];
        return module.lockAsync(3);
      }).then(function () {
        return new Promise(function (resolve) { setTimeout(resolve, 1500); });
      }).then(function () {
        return module.getOrientationAsync();
      }).then(function (back) {
        result.portraitOrientation = back;
        return result;
      });
    });
  }
};

var NAMES = ['FileSystem', 'ExpoDocumentPicker', 'ExpoImageManipulator', 'ExpoImage', 'ExpoCamera', 'ExpoSecureStore', 'ExpoNetwork', 'ExpoDevice', 'ExpoBrightness', 'ExpoLinearGradient', 'ExpoStoreReview', 'ExpoWebBrowser', 'ExpoBlur', 'ExpoScreenOrientation', 'ExpoSQLite'];

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
