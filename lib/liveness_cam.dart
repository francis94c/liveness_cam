import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camerapage.dart';

class LivenessCam {
  final _methodChannel = const MethodChannel('liveness_cam');

  Future<File?> start(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        final result = await _methodChannel.invokeMethod("start");
        if (result != null && "$result" != "null" && "$result" != "") {
          return File("$result".replaceAll("file:/", ""));
        }
        return null;
      } else if (Platform.isIOS) {
        final result = await Navigator.push(context,
            MaterialPageRoute(builder: (context) => const CameraPage()));
        if (result != null) {
          return result as File;
        }
      }
    } catch (e) {
      debugPrint("error: $e");
    }
    return null;
  }
}
