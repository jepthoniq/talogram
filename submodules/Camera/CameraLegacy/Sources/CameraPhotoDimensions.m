#import "CameraPhotoDimensions.h"

BOOL CameraPhotoOutputSetMaxPhotoDimensions(AVCapturePhotoOutput *output, CMVideoDimensions dimensions) {
    if (dimensions.width <= 0 || dimensions.height <= 0) {
        return NO;
    }
    if (@available(iOS 17.0, *)) {
        @try {
            output.maxPhotoDimensions = dimensions;
            return YES;
        } @catch (NSException *exception) {
            (void)exception;
            return NO;
        }
    }
    return NO;
}

BOOL CameraPhotoSettingsSetMaxPhotoDimensions(AVCapturePhotoSettings *settings, CMVideoDimensions dimensions) {
    if (dimensions.width <= 0 || dimensions.height <= 0) {
        return NO;
    }
    if (@available(iOS 17.0, *)) {
        @try {
            settings.maxPhotoDimensions = dimensions;
            return YES;
        } @catch (NSException *exception) {
            (void)exception;
            return NO;
        }
    }
    return NO;
}
