import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final CameraController _cameraController;
  late final FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _initialized = false;
  String _status = "Initializing...";
  bool _isFaceCaptured = false;

  // Gesture tracking
  int _currentGestureStep = 0; // 0: blink, 1: mouth open, 2: smile
  bool _blinkDetected = false;
  bool _mouthOpenDetected = false;
  bool _eyesWereOpen = false; // Track if eyes were open before blink
  bool _mouthWasClosed = false; // Track if mouth was closed before opening

  final GlobalKey _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController.initialize();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // for smile & eye open detection
        enableTracking: false,
      ),
    );

    _cameraController.startImageStream((image) {
      if (_isDetecting || _isFaceCaptured) return;
      _isDetecting = true;
      _processCameraImage(image);
    });

    setState(() {
      _initialized = true;
      _status = "Please blink your eyes 👁️";
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final camera = _cameraController.description;
      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;
      final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final leftEye = face.leftEyeOpenProbability ?? -1;
        final rightEye = face.rightEyeOpenProbability ?? -1;
        final smiling = face.smilingProbability ?? -1;

        if (leftEye >= 0 && rightEye >= 0) {
          // Step 0: Detect Blink
          if (_currentGestureStep == 0) {
            // Track if eyes are open
            if (leftEye > 0.5 && rightEye > 0.5) {
              _eyesWereOpen = true;
            }
            // Detect blink (eyes closed after being open)
            if (_eyesWereOpen &&
                leftEye < 0.3 &&
                rightEye < 0.3 &&
                !_blinkDetected) {
              _blinkDetected = true;
              _currentGestureStep = 1;
              if (mounted) {
                setState(
                    () => _status = 'Blink detected ✅ Now open your mouth 👄');
              }
            } else if (!_blinkDetected) {
              if (mounted) {
                setState(() => _status = 'Please blink your eyes 👁️');
              }
            }
          }
          // Step 1: Detect Mouth Open/Close
          else if (_currentGestureStep == 1) {
            // Use mouth opening detection based on facial landmarks
            final mouthOpenValue = _detectMouthOpen(face);

            // Track if mouth was closed
            if (mouthOpenValue < 0.2) {
              _mouthWasClosed = true;
            }
            // Detect mouth open after being closed
            if (_mouthWasClosed &&
                mouthOpenValue > 0.4 &&
                !_mouthOpenDetected) {
              _mouthOpenDetected = true;
              _currentGestureStep = 2;
              if (mounted) {
                setState(() => _status = 'Mouth detected ✅ Now smile! 😊');
              }
            } else if (!_mouthOpenDetected) {
              if (mounted) {
                setState(() => _status =
                    'Open your mouth wide 👄 (${(mouthOpenValue * 100).toInt()}%)');
              }
            }
          }
          // Step 2: Detect Smile
          else if (_currentGestureStep == 2) {
            if (smiling >= 0 && smiling > 0.7) {
              if (mounted) {
                setState(() => _status = 'Smile detected ✅ Capturing...');
              }
              _captureFaceSnapshot();
            } else {
              if (mounted) {
                setState(() => _status = 'Please smile! 😊');
              }
            }
          }
        }
      } else {
        // Face not detected - reset gesture verification if in progress
        if (_currentGestureStep > 0 || _blinkDetected || _mouthOpenDetected) {
          _resetGestureTracking();
          if (mounted) {
            setState(() =>
                _status = 'Face lost! Please restart - blink your eyes 👁️');
          }
        } else {
          if (mounted) {
            setState(() => _status = 'No face detected');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
    }

    _isDetecting = false;
  }

  /// Resets all gesture tracking variables to restart the verification process
  void _resetGestureTracking() {
    _currentGestureStep = 0;
    _blinkDetected = false;
    _mouthOpenDetected = false;
    _eyesWereOpen = false;
    _mouthWasClosed = false;
  }

  /// Detects mouth opening by analyzing the distance between nose and bottom mouth landmarks
  /// Returns a value between 0 (closed) and 1 (open)
  double _detectMouthOpen(Face face) {
    // Get mouth and nose landmarks if available
    final noseBase = face.landmarks[FaceLandmarkType.noseBase];
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth];
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth];

    if (noseBase != null && bottomMouth != null) {
      // Calculate vertical distance between nose base and bottom mouth
      final verticalDistance =
          (bottomMouth.position.y - noseBase.position.y).abs();

      // Calculate mouth width for normalization
      double mouthWidth = 100.0; // default
      if (leftMouth != null && rightMouth != null) {
        mouthWidth =
            (rightMouth.position.x - leftMouth.position.x).abs().toDouble();
      }

      // Normalize the distance relative to mouth width
      // Typical ratio: closed ~0.6-0.8, open ~1.0-1.4
      final ratio = verticalDistance / mouthWidth;
      final normalized = (ratio - 0.6) / 0.6; // Map 0.6-1.2 to 0-1
      return normalized.clamp(0.0, 1.0);
    }

    // Fallback: no landmarks available
    return 0.0;
  }

  Future<void> _captureFaceSnapshot() async {
    _isFaceCaptured = true;
    final navigator = Navigator.of(context);
    try {
      await _cameraController.stopImageStream();
      final file = await _cameraController.takePicture();
      navigator.pop(File(file.path));
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Snapshot error: $e');
      }
      _isFaceCaptured = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _initialized
          ? _cameraController.value.isInitialized
              ? Stack(
                  key: _previewKey,
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController.value.previewSize!.height,
                        height: _cameraController.value.previewSize!.width,
                        child: CameraPreview(_cameraController),
                      ),
                    ),
                    // Transparent face outline overlay
                    Align(
                      alignment: Alignment.center,
                      child: CustomPaint(
                        painter: FaceOutlinePainter(),
                        size: Size.infinite,
                      ),
                    ),
                    // Top instruction
                    Positioned(
                      top: 60,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Position your face within the outline',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    // Bottom status
                    Positioned(
                      bottom: 50,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(child: CircularProgressIndicator())
          : const Center(child: CircularProgressIndicator()),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _faceDetector.close();
    super.dispose();
  }
}

class FaceOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: .6)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final guidelinePaint = Paint()
      ..color = Colors.white.withValues(alpha: .4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Calculate proportional sizes
    final faceWidth = size.width * 0.65;
    final faceHeight = faceWidth * 1.3; // Face is taller than wide
    final shoulderWidth = faceWidth * 1.8;
    final shoulderHeight = faceHeight * 0.4;

    // Create face and shoulders path
    final facePath = Path();

    // Draw head (oval)
    final headRect = Rect.fromCenter(
      center: Offset(centerX, centerY - shoulderHeight * 0.3),
      width: faceWidth,
      height: faceHeight,
    );
    facePath.addOval(headRect);

    // Draw neck
    final neckWidth = faceWidth * 0.35;
    final neckTop = headRect.bottom - faceHeight * 0.15;
    final neckHeight = shoulderHeight * 0.6;
    facePath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - neckWidth / 2,
          neckTop,
          neckWidth,
          neckHeight,
        ),
        const Radius.circular(8),
      ),
    );

    // Draw shoulders (curved path)
    final shoulderTop = neckTop + neckHeight;
    final shoulderPath = Path();
    shoulderPath.moveTo(centerX - shoulderWidth / 2, size.height);
    shoulderPath.lineTo(
        centerX - shoulderWidth / 2, shoulderTop + shoulderHeight * 0.3);
    shoulderPath.quadraticBezierTo(
      centerX - shoulderWidth * 0.3,
      shoulderTop,
      centerX - neckWidth / 2,
      shoulderTop,
    );
    shoulderPath.lineTo(centerX + neckWidth / 2, shoulderTop);
    shoulderPath.quadraticBezierTo(
      centerX + shoulderWidth * 0.3,
      shoulderTop,
      centerX + shoulderWidth / 2,
      shoulderTop + shoulderHeight * 0.3,
    );
    shoulderPath.lineTo(centerX + shoulderWidth / 2, size.height);
    shoulderPath.close();

    facePath.addPath(shoulderPath, Offset.zero);

    // Draw semi-transparent background with face cutout
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final combinedPath =
        Path.combine(PathOperation.difference, backgroundPath, facePath);

    canvas.drawPath(combinedPath, overlayPaint);

    // Draw face outline
    canvas.drawOval(headRect, outlinePaint);

    // Draw neck outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - neckWidth / 2,
          neckTop,
          neckWidth,
          neckHeight,
        ),
        const Radius.circular(8),
      ),
      outlinePaint,
    );

    // Draw shoulders outline
    final shoulderOutline = Path();
    shoulderOutline.moveTo(
        centerX - shoulderWidth / 2, shoulderTop + shoulderHeight * 0.3);
    shoulderOutline.quadraticBezierTo(
      centerX - shoulderWidth * 0.3,
      shoulderTop,
      centerX - neckWidth / 2,
      shoulderTop,
    );
    shoulderOutline.lineTo(centerX + neckWidth / 2, shoulderTop);
    shoulderOutline.quadraticBezierTo(
      centerX + shoulderWidth * 0.3,
      shoulderTop,
      centerX + shoulderWidth / 2,
      shoulderTop + shoulderHeight * 0.3,
    );
    canvas.drawPath(shoulderOutline, outlinePaint);

    // Draw facial feature guidelines (eyes and mouth position hints)
    final eyeLineY = headRect.top + faceHeight * 0.4;
    final mouthLineY = headRect.top + faceHeight * 0.7;

    // Eye guidelines
    canvas.drawLine(
      Offset(headRect.left + faceWidth * 0.2, eyeLineY),
      Offset(headRect.left + faceWidth * 0.8, eyeLineY),
      guidelinePaint,
    );

    // Mouth guideline
    canvas.drawLine(
      Offset(headRect.left + faceWidth * 0.3, mouthLineY),
      Offset(headRect.left + faceWidth * 0.7, mouthLineY),
      guidelinePaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
