#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

/// Sets `maxPhotoDimensions` on a photo output, returning `NO` instead of
/// letting AVFoundation raise the Objective-C exception it throws when the
/// dimensions are not valid for the output's current connection or active
/// format. Swift cannot catch `NSException`, so every call site goes through
/// this wrapper (a wrong value used to abort the app on some devices).
FOUNDATION_EXPORT BOOL CameraPhotoOutputSetMaxPhotoDimensions(AVCapturePhotoOutput *output, CMVideoDimensions dimensions);

/// Sets `maxPhotoDimensions` on photo settings with the same protection as
/// `CameraPhotoOutputSetMaxPhotoDimensions`.
FOUNDATION_EXPORT BOOL CameraPhotoSettingsSetMaxPhotoDimensions(AVCapturePhotoSettings *settings, CMVideoDimensions dimensions);

NS_ASSUME_NONNULL_END
