import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/theme/app_colors.dart';

/// Dialog for picking a screen/window to share.
/// Thumbnails arrive asynchronously — the picker listens and rebuilds.
class ScreenSourcePicker extends StatefulWidget {
  final ColorSet c;
  const ScreenSourcePicker({super.key, required this.c});

  static Future<DesktopCapturerSource?> show(BuildContext context, ColorSet c) {
    return showDialog<DesktopCapturerSource>(
      context: context,
      builder: (_) => ScreenSourcePicker(c: c),
    );
  }

  @override
  State<ScreenSourcePicker> createState() => _ScreenSourcePickerState();
}

class _ScreenSourcePickerState extends State<ScreenSourcePicker> {
  List<DesktopCapturerSource> _screens = [];
  List<DesktopCapturerSource> _windows = [];
  bool _loading = true;
  int _tab = 0;
  Timer? _refreshTimer;
  StreamSubscription? _thumbSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _thumbSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final sources = await desktopCapturer.getSources(
        types: [SourceType.Screen, SourceType.Window],
        thumbnailSize: ThumbnailSize(320, 180),
      );
      if (!mounted) return;

      // Listen for async thumbnail updates
      _thumbSub = desktopCapturer.onThumbnailChanged.stream.listen((_) {
        if (mounted) setState(() {});
      });

      // Also periodically rebuild to pick up late thumbnails
      _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });

      setState(() {
        _screens = sources.where((s) => s.type == SourceType.Screen).toList();
        _windows = sources.where((s) => s.type == SourceType.Window).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final sources = _tab == 0 ? _screens : _windows;

    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
              child: Row(
                children: [
                  Icon(Icons.screen_share_outlined, size: 18, color: c.accent),
                  const SizedBox(width: 8),
                  Text('Поделиться экраном', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                  const Spacer(),
                  IconButton(icon: Icon(Icons.close, size: 18, color: c.textSecondary), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                _tabBtn(0, 'Экраны (${_screens.length})', c),
                const SizedBox(width: 8),
                _tabBtn(1, 'Окна (${_windows.length})', c),
              ]),
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: c.accent))
                  : sources.isEmpty
                      ? Center(child: Text('Нет источников', style: TextStyle(color: c.textSecondary)))
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 16 / 11,
                          ),
                          itemCount: sources.length,
                          itemBuilder: (ctx, i) => _card(sources[i], c),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(int idx, String label, ColorSet c) {
    final active = _tab == idx;
    return InkWell(
      onTap: () => setState(() => _tab = idx),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: active ? c.accent : c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? c.accent : c.text)),
      ),
    );
  }

  Widget _card(DesktopCapturerSource source, ColorSet c) {
    final thumb = source.thumbnail;
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(8),
      hoverColor: c.accent.withValues(alpha: 0.08),
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                child: thumb != null && thumb.isNotEmpty
                    ? Image.memory(thumb, fit: BoxFit.cover, width: double.infinity, gaplessPlayback: true)
                    : Container(
                        color: c.surface,
                        child: Center(child: Icon(
                          source.type == SourceType.Screen ? Icons.desktop_windows : Icons.web_asset,
                          size: 28, color: c.textSecondary.withValues(alpha: 0.4),
                        )),
                      ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.text)),
            ),
          ],
        ),
      ),
    );
  }
}
