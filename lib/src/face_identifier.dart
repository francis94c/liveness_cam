import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'scanned_image.dart';

class FaceIdentifier {
  static Future<DetectedFace?> scanImage(
      {required CameraImage cameraImage,
      required CameraDescription camera}) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(cameraImage.width.toDouble(), cameraImage.height.toDouble());

    final InputImageRotation imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final InputImageFormat inputImageFormat =
        InputImageFormatValue.fromRawValue(cameraImage.format.raw) ??
            InputImageFormat.nv21;

    final planeData = cameraImage.planes.map(
      (Plane plane) {
        return InputImageMetadata(
            bytesPerRow: plane.bytesPerRow,
            size: Size(
                plane.width?.toDouble() ?? 0, plane.height?.toDouble() ?? 0),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21);
      },
    ).toList();

    final visionImage =
        InputImage.fromBytes(bytes: bytes, metadata: planeData.first);
    DetectedFace? result;
    final face = await _detectFace(visionImage: visionImage);
    if (face != null) {
      result = face;
    }

    return result;
  }

  static Future<DetectedFace?> _detectFace({required visionImage}) async {
    final options = FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true);
    final faceDetector = FaceDetector(options: options);
    try {
      final List<Face> faces = await faceDetector.processImage(visionImage);
      final faceDetect = _extractFace(faces);
      return faceDetect;
    } catch (error) {
      debugPrint(error.toString());
      return null;
    }
  }

  static _extractFace(List<Face> faces) {
    //List<Rect> rect = [];
    bool wellPositioned = false;
    bool isSmiling = false;
    bool isBlinking = false;
    bool isMouthOpen = false;
    Face? detectedFace;

    for (Face face in faces) {
      // rect.add(face.boundingBox);
      detectedFace = face;

      // Detect hold
      if (face.headEulerAngleY! < 5 || face.headEulerAngleY! > -5) {
        wellPositioned = true;
      }
      // If landmark detection was enabled with FaceDetectorOptions (mouth, ears,
      // eyes, cheeks, and nose available):
      // final FaceContour? topLip = face.contours[FaceContourType.lowerLipTop];
      // final FaceContour? bottomLip = face.contours[FaceContourType.upperLipBottom];

      // if(wellPositioned==true){
      //   if(topLip!=null && bottomLip!=null){
      //     int delta= topLip.points[4].y - bottomLip.points[4].y;
      //     if(delta>25){
      //       isMouthOpen=true;
      //     }
      //     }
      //   }

      // if(wellPositioned==true){
      //   print("right");
      //   print(face.rightEyeOpenProbability);
      //   print("left");
      //   print(face.leftEyeOpenProbability);
      //   double cek=(face.leftEyeOpenProbability??1.0);
      //   double batas= 0.1;
      //     if(cek<batas){
      //       isBlinking=true;
      //     }
      // }

      if (isMouthOpen = true) {
        if ((face.smilingProbability ?? 0) > 0.8) {
          isSmiling = true;
        }
      }
    }

    return DetectedFace(
        wellPositioned: wellPositioned,
        face: detectedFace!,
        isSmiling: isSmiling,
        isMouthOpen: isMouthOpen,
        isBlinking: isBlinking);
  }
}
