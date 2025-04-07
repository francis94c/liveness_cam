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
      _status = "Camera initialized. Blink to continue 👁️";
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

        if (leftEye >= 0 && rightEye >= 0) {
          if (leftEye < 0.3 && rightEye < 0.3) {
            setState(() => _status = 'Blink detected ✅');
            _captureFaceSnapshot();
          } else {
            setState(() => _status = 'Face detected. Blink to continue 👁️');
          }
        }
      } else {
        if (mounted) {
          setState(() => _status = 'No face detected');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
    }

    _isDetecting = false;
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
                    Positioned(
                      bottom: 50,
                      left: 20,
                      right: 20,
                      child: Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          backgroundColor: Colors.black54,
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
      ..color = Colors.black.withValues(alpha: .5)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final width = size.width * 0.6;
    final height = size.height * 0.4;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2;

    final ovalRect = Rect.fromLTWH(left, top, width, height);
    final ovalPath = Path()..addOval(ovalRect);

    // Draw semi-transparent background with oval cutout
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final combinedPath =
        Path.combine(PathOperation.difference, backgroundPath, ovalPath);

    canvas.drawPath(combinedPath, overlayPaint);
    canvas.drawOval(ovalRect, outlinePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
