import 'dart:typed_data';
import 'dart:ui';
import 'package:image/image.dart' as img;
import 'base_game.dart';

class PathfinderGame extends BaseGame {
  @override
  String get name => "Pathfinder: Kingmaker";

  @override
  String get extension => "png";

  @override
  List<String> get stepKeys => ["Large", "Medium", "Small"];

  @override
  Map<String, Size> get targetSizes => {
        "Large": const Size(692, 1024),
        "Medium": const Size(330, 432),
        "Small": const Size(185, 242),
      };

  @override
  String getFileName(String charName, String key) {
    switch (key) {
      case "Large":
        return "Large.png";
      case "Medium":
        return "Medium.png";
      case "Small":
        return "Small.png";
      default:
        // 중괄호를 제거하여 Dart의 권장 스타일을 따릅니다.
        return "$key.png";
    }
  }

  @override
  Uint8List encodeImage(img.Image image) {
    return Uint8List.fromList(img.encodePng(image));
  }
}