HOST_PROJECT = "rn-probe"
HOST_BACKPORTS = "FoundationBackports,CoreTextBackports,UIKitBackports,UserNotificationsBackports,CoreGraphicsBackports,GraphicsBackports,CoreFoundationBackports,SystemBackports,IOSurfaceBackports,WebKitBackports,MapKitBackports,CoreLocationBackports,SecurityBackports,CoreMotionBackports,CoreTelephonyBackports,AVKitBackports,AccelerateBackports,CoreMediaBackports,AVFoundationBackports,PhotosBackports,MediaPlayerBackports"
includes(path.join(os.getenv("REVENANT_PATH") or "", "frameworks", "ReactNative", "examples", "host.lua"))
