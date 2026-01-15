import 'dart:io';
import 'package:flutter/material.dart';
import 'package:liveness_cam/liveness_cam.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final _livenessCam = LivenessCam();

  File? result;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Liveness Cam')),
        body: Center(
          child: Column(
            children: [
              result != null ? Image.file(result!) : Container(),
              const SizedBox(height: 20),
              Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      _livenessCam.start(context).then((value) {
                        if (value != null) {
                          setState(() {
                            result = value;
                          });
                        }
                      });
                    },
                    child: const Text("Start", style: TextStyle(fontSize: 19)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
