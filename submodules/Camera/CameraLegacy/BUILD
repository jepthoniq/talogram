load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "CameraLegacyObjC",
    enable_modules = True,
    module_name = "CameraLegacyObjC",
    srcs = [
        "Sources/CameraPhotoDimensions.m",
    ],
    hdrs = [
        "PublicHeaders/CameraPhotoDimensions.h",
    ],
    includes = [
        "PublicHeaders",
    ],
    sdk_frameworks = [
        "Foundation",
        "AVFoundation",
        "CoreMedia",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "CameraLegacy",
    module_name = "CameraLegacy",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        "//submodules/Camera:CameraBundle",
    ],
    deps = [
        ":CameraLegacyObjC",
        "//submodules/Camera",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/ImageBlur:ImageBlur",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Utils/DeviceModel",
        "//submodules/LottieBinding:LottieBinding",
        "//submodules/AppBundle",
        "//submodules/GZip",
    ],
    visibility = [
        "//visibility:public",
    ],
)
