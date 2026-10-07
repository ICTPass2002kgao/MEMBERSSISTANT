import 'package:flutter/material.dart';

Widget getLivenessWidget({
  required Function(dynamic) onSuccess,
  required Function(String) onFailed,
}) {
  return const Center(
    child: Text(
      'Liveness not supported on Web',
      style: TextStyle(color: Colors.white),
    ),
  );
}