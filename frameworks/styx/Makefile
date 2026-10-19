SWIFT_EXE=swift
SWIFT_TEST_FLAGS=
SWIFT_BUILD_FLAGS=-Xcc -Wunguarded-availability

# NOTE: on Apple hosts the system Combine shadows this module, so these SwiftPM
# targets are meant for platforms without a system Combine (Linux, WASI). The
# legacy-iOS (armv7) build goes through the Charon `charon@styx` package.

debug:
	$(SWIFT_EXE) build -c debug $(SWIFT_BUILD_FLAGS)

release:
	$(SWIFT_EXE) build -c release $(SWIFT_BUILD_FLAGS)

test-debug:
	$(SWIFT_EXE) test -c debug $(SWIFT_BUILD_FLAGS) $(SWIFT_TEST_FLAGS)

test-release:
	$(SWIFT_EXE) test -c release $(SWIFT_BUILD_FLAGS) $(SWIFT_TEST_FLAGS)

swift-version:
	$(SWIFT_EXE) -version

gyb:
	$(shell ./utils/recursively_gyb.sh)

clean:
	rm -rf .build

.PHONY: debug release test-debug test-release swift-version gyb clean
