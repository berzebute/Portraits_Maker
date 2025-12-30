import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import 'games/base_game.dart';
import 'games/infinity.dart';
import 'games/originbg.dart';       
import 'games/originiwd2.dart';     
import 'games/pathfinder.dart';
import 'games/pillars_of_eternity.dart';

void main() => runApp(const PortraitApp());

class PortraitApp extends StatelessWidget {
  const PortraitApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '포트레이트 메이커',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const PortraitEditor(),
    );
  }
}

class PortraitEditor extends StatefulWidget {
  const PortraitEditor({super.key});
  @override
  State<PortraitEditor> createState() => _PortraitEditorState();
}

class _PortraitEditorState extends State<PortraitEditor> {
  final List<BaseGame> _games = [
    InfinityEngineGame(),
    OriginBGGame(),        
    IWD2Game(),            
    PathfinderGame(),
    PillarsOfEternityGame(),
  ];

  late BaseGame _selectedGame;
  File? _image;
  img.Image? _decodedImage;
  Size? _imgSize;
  final picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController(text: "MYCHAR");

  int _stepIdx = 0; 
  final ValueNotifier<Offset> _posNotifier = ValueNotifier(Offset.zero);
  final ValueNotifier<Size> _sizeNotifier = ValueNotifier(const Size(200, 200));

  final Map<String, img.Image> _croppedRaws = {};
  final Map<String, Uint8List> _previews = {};
  double _scalePercent = 100.0;

  double _lastDrawW = 0;
  double _lastDrawH = 0;

  @override
  void initState() {
    super.initState();
    _selectedGame = _games[0];
  }

  void _initStep(double drawW, double drawH) {
    if (_stepIdx >= _selectedGame.stepKeys.length) return;
    
    String key = _selectedGame.stepKeys[_stepIdx];
    Size target = _selectedGame.targetSizes[key]!;
    double targetAspect = target.width / target.height;

    double initH = drawH * 0.8;
    double initW = initH * targetAspect;

    if (initW > drawW) {
      initW = drawW * 0.8;
      initH = initW / targetAspect;
    }

    _sizeNotifier.value = Size(initW, initH);
    _posNotifier.value = Offset((drawW - initW) / 2, (drawH - initH) / 2);
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        setState(() {
          _image = File(pickedFile.path);
          _decodedImage = decoded;
          _imgSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
          _stepIdx = 0;
          _croppedRaws.clear();
          _previews.clear();
          _lastDrawW = 0; 
        });
      }
    }
  }

  Future<void> _cropCurrent(double drawW, double drawH) async {
    if (_decodedImage == null) return;
    String key = _selectedGame.stepKeys[_stepIdx];
    final currentPos = _posNotifier.value;
    final currentSize = _sizeNotifier.value;

    double scaleX = _decodedImage!.width / drawW;
    double scaleY = _decodedImage!.height / drawH;

    int sX = (currentPos.dx * scaleX).toInt().clamp(0, _decodedImage!.width - 1);
    int sY = (currentPos.dy * scaleY).toInt().clamp(0, _decodedImage!.height - 1);
    int sW = (currentSize.width * scaleX).toInt().clamp(1, _decodedImage!.width - sX);
    int sH = (currentSize.height * scaleY).toInt().clamp(1, _decodedImage!.height - sY);
    
    img.Image cropped = img.copyCrop(_decodedImage!, x: sX, y: sY, width: sW, height: sH);

    setState(() {
      _croppedRaws[key] = cropped;
      _previews[key] = Uint8List.fromList(img.encodePng(cropped));
      _stepIdx++;
      if (_stepIdx < _selectedGame.stepKeys.length) {
        _initStep(drawW, drawH);
      }
    });
  }

  Future<void> _saveAll() async {
    final String baseDir = Directory.current.path;
    String safeGameName = _selectedGame.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').replaceAll(' ', '_');
    String charName = _nameController.text.trim().isEmpty ? "UNKNOWN" : _nameController.text.trim();
    String safeCharName = charName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').replaceAll(' ', '_');

    // 패스파인더만 캐릭터명 폴더 생성, 나머지는 게임명 폴더에 바로 저장
    String path;
    if (_selectedGame is PathfinderGame) {
      path = "$baseDir/Portraits_$safeGameName/$safeCharName";
    } else {
      path = "$baseDir/Portraits_$safeGameName";
    }
    
    try {
      await Directory(path).create(recursive: true);
      for (var key in _selectedGame.stepKeys) {
        if (_croppedRaws[key] != null) {
          img.Image raw = _croppedRaws[key]!;
          Size targetSize = _selectedGame.targetSizes[key]!;
          
          // 고정 해상도 사용 게임 체크 (OriginBG, IWD2, PoE)
          bool isFixedScaleGame = _selectedGame is OriginBGGame || 
                                 _selectedGame is IWD2Game || 
                                 _selectedGame is PillarsOfEternityGame;

          double currentScale = isFixedScaleGame ? 100.0 : _scalePercent;

          int targetW = (targetSize.width * (currentScale / 100.0)).toInt();
          int targetH = (targetSize.height * (currentScale / 100.0)).toInt();

          img.Image finalImg;
          if (raw.width != targetW || raw.height != targetH) {
            finalImg = img.copyResize(raw, width: targetW, height: targetH, interpolation: img.Interpolation.average);
          } else {
            finalImg = raw;
          }
          
          await File("$path/${_selectedGame.getFileName(charName, key)}").writeAsBytes(_selectedGame.encodeImage(finalImg));
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('[$charName] 연성 완료: $path', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
            backgroundColor: const Color(0xFF2C2C2C),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDone = _stepIdx >= _selectedGame.stepKeys.length;
    return Scaffold(
      appBar: AppBar(title: const Text('포트레이트 메이커'), centerTitle: true),
      body: Row(
        children: [
          Expanded(child: Container(color: const Color(0xFF121212), child: _image == null ? const Center(child: Text("이미지를 불러오세요")) : (isDone ? _buildResultView() : _buildCroppingView()))),
          _buildSidePanel(),
        ],
      ),
    );
  }

  Widget _buildCroppingView() {
    return LayoutBuilder(builder: (context, constraints) {
      double availableW = constraints.maxWidth - 80;
      double availableH = constraints.maxHeight - 80;
      double imgAspect = _imgSize!.width / _imgSize!.height;
      double drawW = (availableW / availableH > imgAspect) ? availableH * imgAspect : availableW;
      double drawH = (availableW / availableH > imgAspect) ? availableH : availableW / imgAspect;

      if (_lastDrawW != drawW || _lastDrawH != drawH) {
        _lastDrawW = drawW;
        _lastDrawH = drawH;
        Future.microtask(() => _initStep(drawW, drawH));
      }

      String currentStepKey = _selectedGame.stepKeys[_stepIdx];
      return Center(
        child: Container(
          width: drawW, height: drawH,
          decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15)]),
          child: Stack(children: [
            Image.file(_image!, width: drawW, height: drawH, fit: BoxFit.fill),
            ValueListenableBuilder<Offset>(
              valueListenable: _posNotifier,
              builder: (context, pos, child) {
                return ValueListenableBuilder<Size>(
                  valueListenable: _sizeNotifier,
                  builder: (context, size, child) {
                    return Positioned(left: pos.dx, top: pos.dy, child: _buildResizableRect(size, drawW, drawH));
                  },
                );
              },
            ),
            Align(
              alignment: Alignment.bottomCenter, 
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20), 
                child: ElevatedButton(onPressed: () => _cropCurrent(drawW, drawH), child: Text("[$currentStepKey 단계] 영역 확정"))
              )
            ),
          ]),
        ),
      );
    });
  }

  Widget _buildResizableRect(Size size, double drawW, double drawH) {
    return GestureDetector(
      onPanUpdate: (details) {
        _posNotifier.value = Offset(
          (_posNotifier.value.dx + details.delta.dx).clamp(0.0, drawW - size.width),
          (_posNotifier.value.dy + details.delta.dy).clamp(0.0, drawH - size.height),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          width: size.width, height: size.height,
          decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2), color: Colors.amber.withValues(alpha: 0.05)),
          child: Stack(children: [
            for (var align in [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight, Alignment.topCenter, Alignment.bottomCenter, Alignment.centerLeft, Alignment.centerRight])
              _buildEdge(align, drawW, drawH),
          ]),
        ),
      ),
    );
  }

  Widget _buildEdge(Alignment align, double drawW, double drawH) {
    return Align(
      alignment: align,
      child: MouseRegion(
        cursor: _getCursor(align),
        child: GestureDetector(
          onPanUpdate: (details) {
            final double aspect = _selectedGame.targetSizes[_selectedGame.stepKeys[_stepIdx]]!.width / _selectedGame.targetSizes[_selectedGame.stepKeys[_stepIdx]]!.height;
            double newW = _sizeNotifier.value.width;
            Offset newPos = _posNotifier.value;

            if (align.x < 0) {
              newW -= details.delta.dx;
              newPos = Offset(newPos.dx + details.delta.dx, newPos.dy);
            } else if (align.x > 0) {
              newW += details.delta.dx;
            } else if (align.y != 0) {
              newW += (details.delta.dy * aspect * (align.y > 0 ? 1 : -1));
              if (align.y < 0) newPos = Offset(newPos.dx, newPos.dy + details.delta.dy);
            }

            newW = newW.clamp(30.0, drawW);
            if (newPos.dx < 0) { newW += newPos.dx; newPos = Offset(0, newPos.dy); }
            if (newPos.dx + newW > drawW) { newW = drawW - newPos.dx; }

            double newH = newW / aspect;
            if (newPos.dy < 0) { newH += newPos.dy; newPos = Offset(newPos.dx, 0); newW = newH * aspect; }
            if (newPos.dy + newH > drawH) { newH = drawH - newPos.dy; newW = newH * aspect; }

            _sizeNotifier.value = Size(newW, newH);
            _posNotifier.value = newPos;
          },
          child: Container(width: align.x == 0 ? double.infinity : 25, height: align.y == 0 ? double.infinity : 25, color: Colors.transparent),
        ),
      ),
    );
  }

  MouseCursor _getCursor(Alignment a) {
    if (a == Alignment.topLeft || a == Alignment.bottomRight) return SystemMouseCursors.resizeDownRight;
    if (a == Alignment.topRight || a == Alignment.bottomLeft) return SystemMouseCursors.resizeDownLeft;
    return a.y != 0 ? SystemMouseCursors.resizeUpDown : SystemMouseCursors.resizeLeftRight;
  }

  Widget _buildResultView() {
    return LayoutBuilder(builder: (context, constraints) {
      double imageHeight = constraints.maxHeight * 0.55;
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text("연성 결과 확인", style: TextStyle(fontSize: 22, color: Colors.amber, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: _selectedGame.stepKeys.map((key) {
              int currentW = _croppedRaws[key]?.width ?? 0;
              
              bool isFixedScale = _selectedGame is OriginBGGame || 
                                 _selectedGame is IWD2Game || 
                                 _selectedGame is PillarsOfEternityGame;

              double currentScale = isFixedScale ? 100.0 : _scalePercent;

              int targetW = (_selectedGame.targetSizes[key]!.width * (currentScale / 100.0)).toInt();
              int targetH = (_selectedGame.targetSizes[key]!.height * (currentScale / 100.0)).toInt();
              bool willResize = currentW != targetW || _croppedRaws[key]?.height != targetH;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("$key 단계", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (_previews[key] != null) Image.memory(_previews[key]!, height: imageHeight, fit: BoxFit.contain),
                    const SizedBox(height: 15),
                    Text("현재 크기: ${currentW}x${_croppedRaws[key]?.height}", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    Text(willResize ? "(저장 시 ${targetW}x$targetH로 조정됨)" : "(원본 크기로 저장됨)", style: TextStyle(fontSize: 11, color: willResize ? Colors.redAccent : Colors.greenAccent)),
                  ],
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton(onPressed: () => setState(() => _stepIdx = 0), child: const Text("영역 다시 잡기")),
            const SizedBox(width: 20),
            ElevatedButton(onPressed: _saveAll, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)), child: const Text("최종 저장")),
          ]),
        ]),
      );
    });
  }

  Widget _buildSidePanel() {
    // 게임별 메시지 설정
    String? specialMessage;
    bool hideSlider = false;

    if (_selectedGame is OriginBGGame || _selectedGame is IWD2Game) {
      specialMessage = "시스템 상 공식 해상도만 지원됩니다";
      hideSlider = true;
    } else if (_selectedGame is PillarsOfEternityGame) {
      specialMessage = "시스템 상 공식 해상도 이외에는\n화질이 저하될 수 있습니다";
      hideSlider = true;
    }

    return Container(
      width: 300, padding: const EdgeInsets.all(25), color: const Color(0xFF1E262D),
      child: Column(children: [
        const Text("대상 게임 선택", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        DropdownButton<BaseGame>(
          value: _selectedGame, isExpanded: true, dropdownColor: const Color(0xFF1E262D),
          items: _games.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
          onChanged: (val) { if (val != null) setState(() { _selectedGame = val; _image = null; }); },
        ),
        const SizedBox(height: 30),
        const Text("캐릭터 이름", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        TextField(controller: _nameController, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 30),
        
        if (hideSlider) ...[
          const Icon(Icons.info_outline, color: Colors.amber, size: 28),
          const SizedBox(height: 10),
          Text(
            specialMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ] else ...[
          const Text("저장 해상도 비율", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          Text("${_scalePercent.toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 24)),
          Slider(value: _scalePercent, min: 10, max: 100, divisions: 9, activeColor: Colors.amber, onChanged: (v) => setState(() => _scalePercent = v)),
        ],

        const Spacer(),
        ElevatedButton(onPressed: _pickImage, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text("이미지 불러오기")),
      ]),
    );
  }
}