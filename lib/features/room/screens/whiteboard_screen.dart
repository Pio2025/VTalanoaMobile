import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/room_provider.dart';

/// Full-screen collaborative whiteboard, pushed on top of the room screen.
/// The in-app back button and the Android hardware back button both just
/// pop this route (Flutter's default Navigator behaviour), which returns to
/// the still-live room screen underneath — i.e. "minimise" (same pattern as
/// [openParticipantsScreen]/[openWaitingRoomScreen]/[openChatScreen]).
///
/// Strokes are relayed/persisted server-side as short line segments
/// `{x0, y0, x1, y1, color, width}` — the same wire shape the web app uses
/// (`meet.navulifiji.com/public/js/whiteboard.js`), so a mixed web/mobile
/// session stays compatible.
void openWhiteboardScreen(BuildContext context, RoomProvider room) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider.value(
      value: room,
      child: const WhiteboardScreen(),
    ),
  ));
}

const List<Color> _kWbColors = [
  Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange,
];

class WhiteboardScreen extends StatefulWidget {
  const WhiteboardScreen({super.key});

  @override
  State<WhiteboardScreen> createState() => _WhiteboardScreenState();
}

class _WhiteboardScreenState extends State<WhiteboardScreen> {
  Color _color = _kWbColors.first;
  bool _erasing = false;
  Offset? _lastPoint;

  @override
  void initState() {
    super.initState();
    context.read<RoomProvider>().requestWbState();
  }

  String _colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _onPanStart(DragStartDetails d) {
    _lastPoint = d.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final from = _lastPoint;
    final to = d.localPosition;
    _lastPoint = to;
    if (from == null) return;
    final stroke = {
      'x0': from.dx, 'y0': from.dy,
      'x1': to.dx, 'y1': to.dy,
      'color': _erasing ? '#ffffff' : _colorToHex(_color),
      'width': _erasing ? 20.0 : 3.0,
    };
    context.read<RoomProvider>().sendWbStroke(stroke);
  }

  void _onPanEnd(DragEndDetails d) {
    _lastPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, room, _) {
        return Scaffold(
          backgroundColor: VtColors.bg,
          appBar: AppBar(
            backgroundColor: VtColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: VtColors.text),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Whiteboard', style: TextStyle(color: VtColors.text, fontSize: 17)),
            actions: [
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.delete_outline_rounded, color: VtColors.text2),
                onPressed: room.clearWhiteboard,
              ),
            ],
          ),
          body: Column(children: [
            Container(
              color: VtColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                for (final c in _kWbColors) ...[
                  _ColorDot(
                    color: c,
                    selected: !_erasing && _color.toARGB32() == c.toARGB32(),
                    onTap: () => setState(() { _color = c; _erasing = false; }),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                _EraserToggle(
                  active: _erasing,
                  onTap: () => setState(() => _erasing = !_erasing),
                ),
              ]),
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _WhiteboardPainter(
                      strokes: room.wbStrokes,
                      hexToColor: _hexToColor,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? VtColors.primary : VtColors.border,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

class _EraserToggle extends StatelessWidget {
  const _EraserToggle({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? VtColors.primaryBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? VtColors.primary : VtColors.border),
        ),
        child: Icon(Icons.auto_fix_normal_rounded, size: 18,
            color: active ? VtColors.primary : VtColors.text2),
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  _WhiteboardPainter({required this.strokes, required this.hexToColor});
  final List<Map<String, dynamic>> strokes;
  final Color Function(String) hexToColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = hexToColor(s['color'] as String? ?? '#000000')
        ..strokeWidth = (s['width'] as num?)?.toDouble() ?? 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset((s['x0'] as num).toDouble(), (s['y0'] as num).toDouble()),
        Offset((s['x1'] as num).toDouble(), (s['y1'] as num).toDouble()),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) =>
      oldDelegate.strokes.length != strokes.length;
}
