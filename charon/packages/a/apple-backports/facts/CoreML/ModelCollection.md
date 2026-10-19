# Core ML's model collections of iOS 14: MLModelCollectionDidChangeNotification, and what is owed

`MLModelCollection` and `MLModelCollectionEntry` are the iOS 14 classes through which an application asks Core ML for a
collection of models that Core ML Model Deployment delivers. Their own header sunsets them (`MODELCOLLECTION_SUNSET`
in the SDK's `MLModelCollection.h` and `MLModelCollectionEntry.h`: deprecated from iOS 14.0 to 17.4, unavailable from
18.0, and unavailable on tvOS and watchOS). The port carries the notification's name and not the classes.

## What the host does, measured

- **`MLModelCollectionDidChangeNotification` is a string whose value is its own name.** The host's CoreML is opened with
  `dlopen`, the symbol is read with `dlsym`, and the `NSString` it points at is
  `MLModelCollectionDidChangeNotification`. The SDK's stub of the framework does not export the symbol, so a link against
  the stub fails and the dlsym path is the only one; `tests/backports/host/coreml-collection14/probe.m` does it.
- **The class is present on the host** (`NSClassFromString(@"MLModelCollection")` answers a class), so the framework still
  carries it. Its behaviour is not measured here: `beginAccessingModelCollectionWithIdentifier:completionHandler:` asks a
  download service and the daemon's store, and this machine's results depend on that service's state.

## What is implemented

`CoreML/MLModelCollection14.m` defines the constant with the measured value. The port posts no notification and holds no
collection, so an observer on this name hears nothing from the port; this is the port's own state, not an answer about the
host.

## What is owed, and why

- **`MLModelCollection`** (14.0, sunset in 17.4). Its entries are a download from Core ML Model Deployment, kept by the daemon
  and synchronised with Apple's servers. Reproducing that download is not offline work, so the class is owed.
- **`MLModelCollectionEntry`** (14.0, sunset in 18.0). An entry is one row of the store that `MLModelCollection` reads;
  it exists only through that store, so it is owed with its class.

## Registry

`MLModelCollectionDidChangeNotification` is `implemented` in `registry/CoreML/absent_CoreML.json`, with this file as its
`facts`. `MLModelCollection` and `MLModelCollectionEntry` are `owed` with the reasons above.
