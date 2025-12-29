import 'dart:ui';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'base_game.dart';

class InfinityEngineGame extends BaseGame {
  @override
  String get name => "Baldur's Gate 2 EE";

  @override
  List<String> get stepKeys => ['L', 'M'];

  @override
  Map<String, Size> get targetSizes => {
    // 두 사이즈 모두 동일한 652:1024 비율을 유지하도록 설정
    'L': const Size(652, 1024), 
    'M': const Size(652, 1024), // M도 동일 비율로 크롭하고 저장 시 조절
  };

  @override
  String get extension => ".BMP";

  @override
  String getFileName(String baseName, String stepKey) {
    return "${baseName.toUpperCase()}$stepKey$extension";
  }

  @override
  Uint8List encodeImage(img.Image image) {
    // 24비트 BMP 인코딩 로직은 동일
    int width = image.width;
    int height = image.height;
    int rowSize = ((width * 3 + 3) ~/ 4) * 4;
    var bmp = Uint8List(54 + (rowSize * height));
    var header = ByteData.view(bmp.buffer);
    bmp[0] = 0x42; bmp[1] = 0x4D;
    header.setUint32(2, bmp.length, Endian.little);
    header.setUint16(18, width, Endian.little);
    header.setUint16(22, height, Endian.little);
    // ... (이하 동일한 24bit BMP 헤더 및 데이터 로직)
    header.setUint32(10, 54, Endian.little);
    header.setUint32(14, 40, Endian.little);
    header.setUint16(26, 1, Endian.little);
    header.setUint16(28, 24, Endian.little);
    header.setUint32(34, rowSize * height, Endian.little);
    
    int pos = 54;
    for (int y = height - 1; y >= 0; y--) {
      for (int x = 0; x < width; x++) {
        var p = image.getPixel(x, y);
        bmp[pos++] = p.b.toInt(); 
        bmp[pos++] = p.g.toInt(); 
        bmp[pos++] = p.r.toInt();
      }
      for (int p = 0; p < (rowSize - width * 3); p++) {
        bmp[pos++] = 0;
      }
    }
    return bmp;
  }
}