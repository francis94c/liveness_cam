import 'dart:io';

import 'package:flutter/material.dart';
import 'package:liveness_cam/src/smart_face_camera.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(body: Builder(builder: (context) {
          return SmartFaceCamera(onCapture: (File? image) {
            Navigator.of(context).pop(image);
          }, messageBuilder: (context, face) {
            if (face == null) {
              return _message('Position your face in front of the camera.');
            }
            if (!face.wellPositioned) {
              return _message('Position your face properly');
            }
            if (!face.isSmiling) {
              return _message('Please smile');
            }
            return const SizedBox.shrink();
          });
        })),
        SizedBox(
          height: 50,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(''),
            ),
          ),
        )
      ],
    );
  }

  Widget _message(String msg) => Padding(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height / 1.5,
            bottom: 16,
            right: 16,
            left: 16),
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                fontWeight: FontWeight.w400,
                color: Colors.white)),
      );
}
