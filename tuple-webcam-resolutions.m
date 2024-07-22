// clang -fmodules -fobjc-arc tuple-webcam-resolutions.m -o tuple-webcam-resolutions

#include <stdio.h>

@import Foundation;
@import AVFoundation;

static inline int AVCaptureDeviceFormatMaxFrameRate(AVCaptureDeviceFormat* format) {
    int maxFrameRate = 0;
    for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
        if (range.maxFrameRate > maxFrameRate) {
            maxFrameRate = range.maxFrameRate;
        }
    }
    return maxFrameRate;
}

static inline NSArray<AVCaptureDeviceFormat*>* AVCaptureDeviceSortedFormats(AVCaptureDevice *device) {
    NSMutableArray *formats = [NSMutableArray array];

    for (AVCaptureDeviceFormat *format in device.formats) {
        if (CMFormatDescriptionGetMediaType(format.formatDescription) != kCMMediaType_Video) {
            continue;
        }

        [formats addObject:format];
    }

    [formats sortUsingComparator:^NSComparisonResult(AVCaptureDeviceFormat* format1, AVCaptureDeviceFormat* format2) {
        CMVideoDimensions dimensions1 = CMVideoFormatDescriptionGetDimensions(format1.formatDescription);
        CMVideoDimensions dimensions2 = CMVideoFormatDescriptionGetDimensions(format2.formatDescription);

        if (dimensions1.width == dimensions2.width) {
            return AVCaptureDeviceFormatMaxFrameRate(format1) > AVCaptureDeviceFormatMaxFrameRate(format2) ? NSOrderedAscending : NSOrderedDescending;
        }

        return dimensions1.width > dimensions2.width ? NSOrderedAscending : NSOrderedDescending;
    }];

    return [formats copy];
}

static inline AVCaptureDeviceFormat* _Nullable AVCaptureDeviceFormatForResolution(AVCaptureDevice *device, CGSize resolution) {
    AVCaptureDeviceFormat *bestFormat = nil;

    for (AVCaptureDeviceFormat *format in AVCaptureDeviceSortedFormats(device)) {
        if (bestFormat != nil) {
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);

            if (dimensions.width < resolution.width && dimensions.height < resolution.width) {
                // Remaining formats have lower resolution
                break;
            }
            else if (AVCaptureDeviceFormatMaxFrameRate(format) < 15 && AVCaptureDeviceFormatMaxFrameRate(bestFormat) >= 15) {
                // Resolution is a closer match but FPS is janky
                continue;
            }
        }

        bestFormat = format;
    }

    return bestFormat;
}

typedef struct Resolution {
    const char *name;
    CGSize size;
} Resolution;

static const size_t nResolutions = 4;

static const Resolution resolutions[nResolutions] = {
    {"Low", {160, 120}},
    {"Medium", {320, 240}},
    {"High", {640, 480}},
    {"Max", {16000, 12000}}
};

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray<AVCaptureDeviceType> *deviceTypes = @[ AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeExternal ];
        AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];

        for (int i = 0; i < nResolutions; i++) {
            Resolution resolution = resolutions[i];

            fprintf(stdout, "\n## %s resolution (%d x %d)\n", resolution.name, (int)resolution.size.width, (int)resolution.size.height);

            for (AVCaptureDevice *device in session.devices) {
                fprintf(stdout, "\n - %s\n", device.localizedName.UTF8String);

                AVCaptureDeviceFormat *idealFormat = AVCaptureDeviceFormatForResolution(device, resolution.size);

                for (AVCaptureDeviceFormat *format in AVCaptureDeviceSortedFormats(device)) {
                    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                    fprintf(stdout, "   - %d x %d @ %d fps", dimensions.width, dimensions.height, AVCaptureDeviceFormatMaxFrameRate(format));
                    fprintf(stdout, [format isEqual:idealFormat] ? " *\n" : "\n");
                }
            }
        }
    }

    return 0;
}
