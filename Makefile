all: tuple-webcam-resolutions

tuple-webcam-resolutions:
	clang -fmodules -fobjc-arc tuple-webcam-resolutions.m -o tuple-webcam-resolutions

clean:
	rm tuple-webcam-resolutions
