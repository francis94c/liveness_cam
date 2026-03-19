import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liveness_cam/camera_page_old.dart';

import 'camera_page.dart';

class LivenessCam {
  final _methodChannel = const MethodChannel('liveness_cam');

  Future<File?> start(BuildContext context, {bool useOldCamera = false}) async {
    try {
      if (Platform.isAndroid) {
        final result = await _methodChannel.invokeMethod("start");
        if (result != null && "$result" != "null" && "$result" != "") {
          return File("$result".replaceAll("file:/", ""));
        }
        return null;
      } else if (Platform.isIOS) {
        final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    useOldCamera ? const CameraPageOld() : const CameraPage()));
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
