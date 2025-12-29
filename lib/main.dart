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
import 'games/pillars_of_eternity2.dart';

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
    PillarsOfEternity1Game(),
    PillarsOfEternity2Game(),
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

  @override
  void initState() {
    super.initState();
    _selectedGame = _games[0];
  }

  void _resetEditor() {
    setState(() {
      _stepIdx = 0;
      _croppedRaws.clear();
      _previews.clear();
      _initStep();
    });
  }

  void _initStep() {
    if (_stepIdx >= _selectedGame.stepKeys.length) return;
    String key = _selectedGame.stepKeys[_stepIdx];
    Size target = _selectedGame.targetSizes[key]!;
    double aspect = target.width / target.height;
    double h = 400.0; 
    double w = h * aspect;
    _posNotifier.value = Offset.zero;
    _sizeNotifier.value = Size(w, h);
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
          _resetEditor();
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
        _initStep();
      }
    });
  }

  // 🛡️ 수정된 저장 로직: 메시지 색상을 흰색으로 변경
  Future<void> _saveAll() async {
    final String baseDir = Directory.current.path;
    String safeGameName = _selectedGame.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').replaceAll(' ', '_');
    String charName = _nameController.text.trim().isEmpty ? "UNKNOWN" : _nameController.text.trim();
    String safeCharName = charName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').replaceAll(' ', '_');

    final String path = "$baseDir/Portraits_$safeGameName/$safeCharName";
    
    try {
      await Directory(path).create(recursive: true);
      for (var key in _selectedGame.stepKeys) {
        if (_croppedRaws[key] != null) {
          img.Image raw = _croppedRaws[key]!;
          Size targetSize = _selectedGame.targetSizes[key]!;
          int targetW = (targetSize.width * (_scalePercent / 100.0)).toInt();
          int targetH = (targetSize.height * (_scalePercent / 100.0)).toInt();

          img.Image finalImg;
          if (raw.width > targetW || raw.height > targetH) {
            finalImg = img.copyResize(raw, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
          } else {
            finalImg = raw;
          }
          
          await File("$path/${_selectedGame.getFileName(charName, key)}").writeAsBytes(_selectedGame.encodeImage(finalImg));
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '[$charName] 연성 완료: $path', 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold) // 글자색 흰색
            ), 
            backgroundColor: const Color(0xFF2C2C2C), // 배경을 더 어두운 회색으로
            duration: const Duration(seconds: 4),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e', style: const TextStyle(color: Colors.white)), 
            backgroundColor: Colors.redAccent
          )
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
    String currentStepKey = _selectedGame.stepKeys[_stepIdx];
    return LayoutBuilder(builder: (context, constraints) {
      double availableW = constraints.maxWidth - 80;
      double availableH = constraints.maxHeight - 80;
      double imgAspect = _imgSize!.width / _imgSize!.height;
      double drawW = (availableW / availableH > imgAspect) ? availableH * imgAspect : availableW;
      double drawH = (availableW / availableH > imgAspect) ? availableH : availableW / imgAspect;

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
                child: ElevatedButton(
                  onPressed: () => _cropCurrent(drawW, drawH), 
                  child: Text("[$currentStepKey 단계] 영역 확정")
                )
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

            newW = newW.clamp(30.0, drawW - newPos.dx);
            double newH = newW / aspect;
            if (newPos.dy + newH > drawH) { newH = drawH - newPos.dy; newW = newH * aspect; }
            if (newPos.dx < 0 || newPos.dy < 0) return;

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
          Text("${_selectedGame.name} 연성 결과", style: const TextStyle(fontSize: 22, color: Colors.amber, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: _selectedGame.stepKeys.map((key) {
              int currentW = _croppedRaws[key]?.width ?? 0;
              int currentH = _croppedRaws[key]?.height ?? 0;
              int targetW = (_selectedGame.targetSizes[key]!.width * (_scalePercent / 100.0)).toInt();
              int targetH = (_selectedGame.targetSizes[key]!.height * (_scalePercent / 100.0)).toInt();
              bool willResize = currentW > targetW || currentH > targetH;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("$key 단계", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (_previews[key] != null) Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.white10)), 
                      child: Image.memory(_previews[key]!, height: imageHeight, fit: BoxFit.contain)
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 40,
                      child: Column(
                        children: [
                          Text("현재 크기: ${currentW}x$currentH", style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          if (willResize)
                            Text("(저장 시 ${targetW}x$targetH로 조정됨)", style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold))
                          else
                            const Text("(원본 크기로 저장됨)", style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
                        ],
                      ),
                    ),
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
        const Text("저장 해상도 비율", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        Text("${_scalePercent.toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 24)),
        Slider(value: _scalePercent, min: 10, max: 100, divisions: 9, activeColor: Colors.amber, onChanged: (v) => setState(() => _scalePercent = v)),
        const Spacer(),
        ElevatedButton(onPressed: _pickImage, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text("이미지 불러오기")),
      ]),
    );
  }
}