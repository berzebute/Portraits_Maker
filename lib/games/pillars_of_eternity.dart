import 'dart:ui';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'base_game.dart';

class PillarsOfEternity1Game extends BaseGame {
  @override
  String get name => "Pillars of Eternity I";

  @override
  List<String> get stepKeys => ['L', 'S'];

  @override
  Map<String, Size> get targetSizes => {
    'L': const Size(210, 330),
    'S': const Size(76, 96),
  };

  @override
  String get extension => ".BMP";

  @override
  String getFileName(String baseName, String stepKey) => "${baseName}_$stepKey$extension";

  @override
  Uint8List encodeImage(img.Image image) {
    // 24비트 BMP 로직 (중괄호 포함)
    int width = image.width;
    int height = image.height;
    int rowSize = ((width * 3 + 3) ~/ 4) * 4;
    var bmp = Uint8List(54 + (rowSize * height));
    var header = ByteData.view(bmp.buffer);
    bmp[0] = 0x42; bmp[1] = 0x4D;
    header.setUint32(2, bmp.length, Endian.little);
    header.setUint32(10, 54, Endian.little);
    header.setUint32(14, 40, Endian.little);
    header.setUint32(18, width, Endian.little);
    header.setUint32(22, height, Endian.little);
    header.setUint16(26, 1, Endian.little);
    header.setUint16(28, 24, Endian.little);
    
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