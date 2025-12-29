import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'base_game.dart';

class PillarsOfEternity2Game extends BaseGame {
  @override
  String get name => "Pillars of Eternity 2";

  @override
  String get extension => "png"; // 누락되었던 extension 추가

  @override
  List<String> get stepKeys => ["Large", "Small"];

  @override
  Map<String, Size> get targetSizes => {
        "Large": const Size(210, 330), // (_lg)
        "Small": const Size(76, 96),   // (_sm)
      };

  @override
  String getFileName(String charName, String key) {
    switch (key) {
      case "Large":
        return "${charName}_lg.png";
      case "Small":
        return "${charName}_sm.png";
      default:
        return "${charName}_$key.png";
    }
  }

  @override
  Uint8List encodeImage(img.Image image) {
    // 반환 타입을 Uint8List로 명확히 캐스팅하여 질서를 맞춥니다.
    return Uint8List.fromList(img.encodePng(image));
  }
}