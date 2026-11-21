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
        return statement.runAsync(database, {}, {}, true);
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
  ExpoTwoWayAudio: function (module) {
    var counts = {micChunks: 0, micBytes: 0, inputLevels: 0, outputLevels: 0, recordingChanges: []};
    var rate = 16000;
    var levels = [];
    var firstChunk = null;
    var tone = 1000;
    var control = 1700;
    var phase = 'plain';
    var samples = {plain: [], quiet: [], tone: []};
    function toInt16(data) {
      if (!data) { return []; }
      var buffer = data.buffer && data.byteLength !== undefined && !(data instanceof ArrayBuffer) ? data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) : data;
      return new Int16Array(buffer);
    }
    function goertzel(values, frequency) {
      var coefficient = 2 * Math.cos(2 * Math.PI * frequency / rate);
      var previous = 0;
      var before = 0;
      for (var i = 0; i < values.length; i++) {
        var current = values[i] + coefficient * previous - before;
        before = previous;
        previous = current;
      }
      var power = before * before + previous * previous - coefficient * previous * before;
      return power / (values.length * values.length);
    }
    function rms(values) {
      var sum = 0;
      for (var i = 0; i < values.length; i++) { sum += values[i] * values[i]; }
      return values.length ? Math.sqrt(sum / values.length) : 0;
    }
    function join(parts) {
      var total = 0;
      parts.forEach(function (part) { total += part.length; });
      var all = new Float64Array(total);
      var at = 0;
      parts.forEach(function (part) { for (var i = 0; i < part.length; i++) { all[at + i] = part[i]; } at += part.length; });
      return all;
    }
    function measure(parts) {
      var values = join(parts);
      return {samples: values.length, rms: Math.round(rms(values)), atTone: goertzel(values, tone), atControl: goertzel(values, control)};
    }
    module.addListener('onMicrophoneData', function (event) {
      counts.micChunks += 1;
      counts.micBytes += event && event.data && event.data.byteLength || 0;
      var chunk = toInt16(event && event.data);
      if (!firstChunk) { firstChunk = {type: Object.prototype.toString.call(event && event.data), length: chunk.length, head: Array.prototype.slice.call(chunk, 0, 8)}; }
      samples[phase].push(chunk);
    });
    module.addListener('onInputVolumeLevelData', function (event) { counts.inputLevels += 1; if (levels.length < 6) { levels.push(event && event.data); } });
    module.addListener('onOutputVolumeLevelData', function () { counts.outputLevels += 1; });
    module.addListener('onRecordingChange', function (event) { counts.recordingChanges.push(event && event.data); });
    function wait(ms) { return new Promise(function (resolve) { setTimeout(resolve, ms); }); }
    var answers = {};
    return module.getMicrophonePermissionsAsync().then(function (permission) {
      answers.permission = permission;
      return module.initialize();
    }).then(function (initialized) {
      answers.initialized = initialized;
      answers.recording = module.toggleRecording(true);
      return wait(3000);
    }).then(function () {
      answers.stillRecording = module.isRecording();
      answers.playing = module.isPlaying();
      module.bypassVoiceProcessing(true);
      phase = 'quiet';
      return wait(1500);
    }).then(function () {
      var pcm = new Int16Array(rate * 2);
      for (var i = 0; i < pcm.length; i++) { pcm[i] = Math.round(12000 * Math.sin(2 * Math.PI * tone * i / rate)); }
      phase = 'tone';
      module.playPCMData(new Uint8Array(pcm.buffer));
      return wait(2600);
    }).then(function () {
      module.toggleRecording(false);
      answers.recordingAfterStop = module.isRecording();
      module.tearDown();
      answers.counts = counts;
      answers.levels = levels;
      answers.firstChunk = firstChunk;
      var quiet = measure(samples.quiet);
      var heard = measure(samples.tone);
      answers.tone = {
        quiet: quiet,
        heard: heard,
        toneOverQuiet: quiet.atTone > 0 ? heard.atTone / quiet.atTone : null,
        toneOverControl: heard.atControl > 0 ? heard.atTone / heard.atControl : null,
        heardTheTone: heard.atTone > 10 * Math.max(quiet.atTone, 1e-9) && heard.atTone > 3 * heard.atControl
      };
      return answers;
    });
  },
  FileSystem: function (module) {
    var base = module.cacheDirectory + 'rn-probe-fs/';
    var steps = {};
    function step(name, run) {
      try { steps[name] = run(); } catch (error) { steps[name] = 'error: ' + String(error && error.message || error); }
    }
    var directory = new module.FileSystemDirectory(base);
    step('directoryCreate', function () { directory.create({intermediates: true, overwrite: true}); return directory.exists; });
    var file = new module.FileSystemFile(base + 'a.txt');
    step('fileCreateWrite', function () { file.create({}); file.write('hello, iOS 6'); return file.exists; });
    step('textSync', function () { return file.textSync(); });
    step('size', function () { return file.size; });
    step('md5', function () { return file.md5; });
    step('base64Sync', function () { return file.base64Sync(); });
    step('bytesSync', function () { return Array.prototype.slice.call(file.bytesSync(), 0, 5); });
    step('append', function () { file.write('!', {append: true}); return file.textSync(); });
    step('info', function () { var info = file.info({md5: true}); return {exists: info.exists, size: info.size, md5: info.md5, hasModification: info.modificationTime > 0}; });
    var copy = new module.FileSystemFile(base + 'b.txt');
    step('copySync', function () { file.copySync(copy); return copy.textSync(); });
    step('renameMoveSync', function () { copy.rename('c.txt'); var moved = new module.FileSystemFile(base + 'd.txt'); new module.FileSystemFile(base + 'c.txt').moveSync(moved); return moved.textSync(); });
    step('handle', function () {
      var data = new module.FileSystemFile(base + 'h.bin');
      data.create({});
      var handle = data.open('rw');
      handle.writeBytes(new Uint8Array([1, 2, 3, 4, 5, 6]));
      var size = handle.size;
      handle.close();
      var reader = data.open('r');
      var first = Array.prototype.slice.call(reader.readBytes(4));
      var offset = reader.offset;
      reader.close();
      return {size: size, first: first, offset: offset};
    });
    step('createFileIn', function () { directory.createFile('e.txt', 'in directory'); directory.createDirectory('sub'); return directory.listAsRecords().map(function (entry) { return entry.uri.replace(/^.*rn-probe-fs\//, ''); }).sort(); });
    step('directorySize', function () { return directory.size; });
    step('disk', function () { return {total: module.totalDiskSpace > 0, available: module.availableDiskSpace > 0}; });
    step('writeBase64', function () { var b = new module.FileSystemFile(base + 'b64.bin'); b.create({}); b.write('AQID', {encoding: 'base64'}); return Array.prototype.slice.call(b.bytesSync()); });
    function cleanup() {
      step('cleanup', function () { directory.delete(); return !directory.exists; });
      return steps;
    }
    return new module.FileSystemFile(base + 'a.txt').text().then(function (text) {
      steps.asyncText = text;
      return cleanup();
    }, function (error) {
      steps.asyncText = 'error: ' + String(error && error.message || error);
      return cleanup();
    });
  },
  ExpoImageManipulator: function (module) {
    var files = modules.FileSystem;
    var base = files.cacheDirectory + 'rn-probe-image/';
    var directory = new files.FileSystemDirectory(base);
    directory.create({intermediates: true, overwrite: true});
    function crc32(bytes) {
      var crc = -1;
      for (var i = 0; i < bytes.length; i++) {
        crc ^= bytes[i];
        for (var k = 0; k < 8; k++) { crc = (crc >>> 1) ^ (0xEDB88320 & -(crc & 1)); }
      }
      return (crc ^ -1) >>> 0;
    }
    function be(value) { return [(value >>> 24) & 255, (value >>> 16) & 255, (value >>> 8) & 255, value & 255]; }
    function chunk(type, data) {
      var body = [type.charCodeAt(0), type.charCodeAt(1), type.charCodeAt(2), type.charCodeAt(3)].concat(data);
      return be(data.length).concat(body, be(crc32(body)));
    }
    function png(width, height) {
      var raw = [];
      for (var y = 0; y < height; y++) {
        raw.push(0);
        for (var x = 0; x < width; x++) { raw.push(x < width / 2 ? 255 : 0, y < height / 2 ? 255 : 0, 64); }
      }
      var a = 1, b = 0;
      raw.forEach(function (byte) { a = (a + byte) % 65521; b = (b + a) % 65521; });
      var deflate = [0x78, 0x01, 1, raw.length & 255, raw.length >> 8, ~raw.length & 255, (~raw.length >> 8) & 255].concat(raw, be(((b << 16) | a) >>> 0));
      return [137, 80, 78, 71, 13, 10, 26, 10].concat(chunk('IHDR', be(width).concat(be(height), [8, 2, 0, 0, 0])), chunk('IDAT', deflate), chunk('IEND', []));
    }
    var source = new files.FileSystemFile(base + 'source.png');
    source.create({overwrite: true});
    source.write(new Uint8Array(png(16, 8)));
    var answers = {sourceBytes: source.size};
    function run(name, build, options) {
      return Promise.resolve().then(function () {
        return build(module.manipulate(source.uri)).renderAsync();
      }).then(function (image) {
        var result = {width: image.width, height: image.height};
        if (!options) { answers[name] = result; return null; }
        return image.saveAsync(options).then(function (saved) {
          var file = new files.FileSystemFile(saved.uri);
          var head = Array.prototype.slice.call(file.bytesSync(), 0, 12);
          result.saved = {width: saved.width, height: saved.height, size: file.size, head: head, base64Length: saved.base64 ? saved.base64.length : null};
          result.saved.uri = saved.uri.replace(/^.*\//, '');
          answers[name] = result;
        });
      }).catch(function (error) { answers[name] = 'error: ' + String(error && error.message || error); });
    }
    return run('render', function (c) { return c; })
      .then(function () { return run('resize', function (c) { return c.resize({width: 8}); }); })
      .then(function () { return run('resizeBoth', function (c) { return c.resize({width: 5, height: 7}); }); })
      .then(function () { return run('rotate90', function (c) { return c.rotate(90); }); })
      .then(function () { return run('flipHorizontal', function (c) { return c.flip('horizontal'); }); })
      .then(function () { return run('flipVertical', function (c) { return c.flip('vertical'); }); })
      .then(function () { return run('crop', function (c) { return c.crop({originX: 2, originY: 1, width: 6, height: 4}); }); })
      .then(function () { return run('chain', function (c) { return c.resize({width: 8}).rotate(90).crop({originX: 0, originY: 0, width: 3, height: 5}); }); })
      .then(function () { return run('savePng', function (c) { return c; }, {format: 'png', base64: true}); })
      .then(function () { return run('saveJpeg', function (c) { return c; }, {format: 'jpeg', compress: 0.8}); })
      .then(function () { return run('saveWebp', function (c) { return c; }, {format: 'webp', compress: 0.8}); })
      .then(function () {
        try { directory.delete(); answers.cleanup = !directory.exists; } catch (error) { answers.cleanup = 'error: ' + String(error && error.message || error); }
        return answers;
      });
  },
  ExpoLocalization: function (module) {
    var locales = module.getLocales();
    var calendars = module.getCalendars();
    return {
      localeCount: locales.length,
      firstLocale: locales[0],
      calendarCount: calendars.length,
      firstCalendar: calendars[0]
    };
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

var NAMES = ['FileSystem', 'ExpoDocumentPicker', 'ExpoImageManipulator', 'ExpoImage', 'ExpoCamera', 'ExpoSecureStore', 'ExpoNetwork', 'ExpoDevice', 'ExpoBrightness', 'ExpoLinearGradient', 'ExpoStoreReview', 'ExpoWebBrowser', 'ExpoBlur', 'ExpoScreenOrientation', 'ExpoSQLite', 'ExpoTwoWayAudio', 'ExpoLocalization'];

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
