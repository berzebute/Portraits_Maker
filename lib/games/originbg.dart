import 'dart:ui';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'base_game.dart';

class OriginBGGame extends BaseGame {
  @override
  String get name => "D&D Classics (BG1, BG2, IWD1)";

  @override
  List<String> get stepKeys => ['L', 'M', 'S'];

  @override
  Map<String, Size> get targetSizes => {
    'L': const Size(210, 330),
    'M': const Size(110, 170),
    'S': const Size(38, 60),
  };

  @override
  String get extension => ".BMP";

  @override
  String getFileName(String baseName, String stepKey) {
    String shortName = baseName.length > 7 ? baseName.substring(0, 7) : baseName;
    return "${shortName.toUpperCase()}$stepKey$extension";
  }

  @override
  Uint8List encodeImage(img.Image image) {
    // S 사이즈는 8비트, 나머지는 24비트 연성
    if (image.width == 38) {
      return _encode8BitBmp(image);
    }
    return _encode24BitBmp(image);
  }

  Uint8List _encode8BitBmp(img.Image image) {
    final quantized = img.quantize(image, numberOfColors: 256);
    final palette = quantized.palette!;
    int width = quantized.width;
    int height = quantized.height;
    int rowSize = ((width + 3) ~/ 4) * 4;
    int fileSize = 54 + 1024 + (rowSize * height);
    var bmp = Uint8List(fileSize);
    var header = ByteData.view(bmp.buffer);

    bmp[0] = 0x42; bmp[1] = 0x4D;
    header.setUint32(2, fileSize, Endian.little);
    header.setUint32(10, 54 + 1024, Endian.little);
    header.setUint32(14, 40, Endian.little);
    header.setUint32(18, width, Endian.little);
    header.setUint32(22, height, Endian.little);
    header.setUint16(26, 1, Endian.little);
    header.setUint16(28, 8, Endian.little);
    header.setUint32(46, 256, Endian.little);

    int palettePos = 54;
    for (int i = 0; i < 256; i++) {
      if (i < palette.numColors) {
        bmp[palettePos++] = palette.getBlue(i).toInt();
        bmp[palettePos++] = palette.getGreen(i).toInt();
        bmp[palettePos++] = palette.getRed(i).toInt();
        bmp[palettePos++] = 0;
      } else {
        palettePos += 4;
      }
    }

    int pos = 54 + 1024;
    for (int y = height - 1; y >= 0; y--) {
      for (int x = 0; x < width; x++) {
        bmp[pos++] = quantized.getPixel(x, y).index.toInt();
      }
      for (int p = 0; p < (rowSize - width); p++) {
        bmp[pos++] = 0; // 중괄호 추가로 문법 에러 정화
      }
    }
    return bmp;
  }

  Uint8List _encode24BitBmp(img.Image image) {
    int width = image.width;
    int height = image.height;
    int rowSize = ((width * 3 + 3) ~/ 4) * 4;
    var bmp = Uint8List(54 + (rowSize * height));
    var header = ByteData.view(bmp.buffer);
    bmp[0] = 0x42; bmp[1] = 0x4D;
    header.setUint32(2, bmp.length, Endian.little);
    header.setUint16(18, width, Endian.little);
    header.setUint16(22, height, Endian.little);
    header.setUint32(10, 54, Endian.little);
    header.setUint32(14, 40, Endian.little);
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
        bmp[pos++] = 0; // 중괄호 추가
      }
    }
    return bmp;
  }
}