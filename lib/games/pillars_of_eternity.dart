import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'base_game.dart';

class PillarsOfEternityGame extends BaseGame {
  @override
  String get name => "Pillars of Eternity";

  @override
  String get extension => "png";

  @override
  List<String> get stepKeys => ["Large", "Small"];

  @override
  Map<String, Size> get targetSizes => {
    // 필라스 1, 2 공통 고해상도 규격 (원본의 2배수)
    "Large": const Size(420, 660), 
    "Small": const Size(152, 192),
  };

  @override
  String getFileName(String baseName, String key) {
    if (key == "Large") return "${baseName}_lg.png";
    return "${baseName}_sm.png";
  }

  @override
  Uint8List encodeImage(img.Image image) {
    return Uint8List.fromList(img.encodePng(image));
  }
}