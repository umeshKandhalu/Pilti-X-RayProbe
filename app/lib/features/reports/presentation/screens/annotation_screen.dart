import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:painter/painter.dart';

class AnnotationScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;

  const AnnotationScreen({
    super.key,
    required this.imageBytes,
    this.title = "Annotate Image",
  });

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  late PainterController _controller;
  final GlobalKey _stackKey = GlobalKey(); // Key to capture the composite

  @override
  void initState() {
    super.initState();
    _controller = _newController();
  }

  PainterController _newController() {
    PainterController controller = PainterController();
    controller.thickness = 5.0;
    controller.backgroundColor = Colors.transparent;
    controller.drawColor = Colors.red;
    return controller;
  }

  Future<Uint8List?> _captureCompositeImage() async {
    try {
      // Capture the entire stack (image + drawings) as PNG
      RenderRepaintBoundary boundary = 
          _stackKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing composite image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () {
              if (!_controller.isEmpty) {
                _controller.undo();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _controller.clear();
            },
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              // Capture the composite image (X-ray + annotations)
              final bytes = await _captureCompositeImage();
              
              if (bytes != null && mounted) {
                Navigator.of(context).pop(bytes);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 1.0, // Should ideally match the image aspect ratio
          child: RepaintBoundary(
            key: _stackKey,
            child: Stack(
              children: [
                // Base Image
                Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
                // Drawing Layer
                Painter(_controller),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ColorButton(
              color: Colors.red,
              onPressed: () => setState(() => _controller.drawColor = Colors.red),
              isSelected: _controller.drawColor == Colors.red,
            ),
            _ColorButton(
              color: Colors.blue,
              onPressed: () => setState(() => _controller.drawColor = Colors.blue),
              isSelected: _controller.drawColor == Colors.blue,
            ),
            _ColorButton(
              color: Colors.yellow,
              onPressed: () => setState(() => _controller.drawColor = Colors.yellow),
              isSelected: _controller.drawColor == Colors.yellow,
            ),
            _ColorButton(
              color: Colors.green,
              onPressed: () => setState(() => _controller.drawColor = Colors.green),
              isSelected: _controller.drawColor == Colors.green,
            ),
            const VerticalDivider(),
            IconButton(
              icon: Icon(
                _controller.eraseMode ? Icons.edit : Icons.auto_fix_normal,
                color: _controller.eraseMode ? Colors.blue : Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _controller.eraseMode = !_controller.eraseMode;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final VoidCallback onPressed;
  final bool isSelected;

  const _ColorButton({
    required this.color,
    required this.onPressed,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: IconButton(
        icon: Icon(Icons.circle, color: color),
        onPressed: onPressed,
      ),
    );
  }
}
