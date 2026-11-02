nativeLoggingHook('rn-host: test bundle evaluated', 1);
var unimplemented = 'none';
try {
  nativeFlushQueueImmediate([]);
} catch (error) {
  unimplemented = String(error);
}
nativeLoggingHook('rn-host: ' + unimplemented, 2);
'rn-host test bundle ok';
