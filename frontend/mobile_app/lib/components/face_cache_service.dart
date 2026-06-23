import 'dart:typed_data';

class FaceCacheService {
  static final FaceCacheService _instance = FaceCacheService._internal();
  factory FaceCacheService() => _instance;
  FaceCacheService._internal();

  // Stores the decrypted bytes mapped to the student's ID
  final Map<String, Uint8List> _cache = {};

  Uint8List? getFace(String studentId) {
    return _cache[studentId];
  }

  void saveFace(String studentId, Uint8List bytes) {
    _cache[studentId] = bytes;
  }

  void clearCache() {
    _cache.clear();
  }
}