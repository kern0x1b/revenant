HOST_PROJECT = "paseo-ios6"
HOST_BACKPORTS = "FoundationBackports,CoreTextBackports,UIKitBackports,UserNotificationsBackports,CoreGraphicsBackports,GraphicsBackports,CoreFoundationBackports,SystemBackports,IOSurfaceBackports,WebKitBackports,MapKitBackports,CoreLocationBackports,SecurityBackports,CoreMotionBackports,CoreTelephonyBackports,AVKitBackports,AccelerateBackports,CoreMediaBackports,AVFoundationBackports"
includes(path.join(os.getenv("REVENANT_PATH") or "", "frameworks", "ReactNative", "examples", "host.lua"))
