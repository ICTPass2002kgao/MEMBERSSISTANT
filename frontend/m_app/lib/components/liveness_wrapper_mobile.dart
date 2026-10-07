import 'package:flutter/material.dart';
import 'package:flutter_face_liveness/flutter_face_liveness.dart';

Widget getLivenessWidget({
  required Function(dynamic) onSuccess,
  required Function(String) onFailed,
}) {
  return FlutterFaceLiveness(
    actions: const [
      LivenessAction.blink,
      LivenessAction.smile,
      LivenessAction.turnLeft,
    ],
    config: const LivenessConfig(
      enableAntiSpoof: true,
      enableVideoReplayDetection: true,
      randomizeActions: true,
      videoReplayInputSize: 20,
      videoReplayThreshold: 0.15,
      videoReplayModelPath: 'assets/MiniFASNetV2.tflite',
      antiSpoofThreshold: 0.25,

      showDebugOverlay: false,
    ),
    onSuccess: onSuccess,
    onFailed: onFailed,
  );
}
