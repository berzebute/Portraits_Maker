import 'dart:ui';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

abstract class BaseGame {
  String get name;
  // 단계 이름 (예: L, M, S / Large, Small 등)
  List<String> get stepKeys;
  // 각 단계별 원본 규격 사이즈
  Map<String, Size> get targetSizes;
  // 파일 확장자 (.bmp, .png 등)
  String get extension;

  // 게임별 특수한 인코딩 방식 (BMP 24bit 등) 처리
  Uint8List encodeImage(img.Image image);
  
  // 파일명 생성 규칙 (예: NAME_L.bmp, NAME_lg.png 등)
  String getFileName(String baseName, String stepKey);
}