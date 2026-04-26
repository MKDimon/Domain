import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MarkdownEditorWithToolbar extends StatefulWidget {
  final String text;
  final ValueChanged<String>? onChanged;
  final ColorSet colors;
  final int minLines;
  final int? maxLines;
  final String hintText;

  const MarkdownEditorWithToolbar({
    super.key,
    required this.text,
    this.onChanged,
    required this.colors,
    this.minLines = 8,
    this.maxLines,
    this.hintText = 'Markdown...',
  });

  @override
  State<MarkdownEditorWithToolbar> createState() => _MarkdownEditorWithToolbarState();
}

class _MarkdownEditorWithToolbarState extends State<MarkdownEditorWithToolbar> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.text);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant MarkdownEditorWithToolbar old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text && _ctrl.text != widget.text) {
      _ctrl.text = widget.text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _insertAtCursor(String before, [String after = '']) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final selected = text.substring(start, end);
    final placeholder = selected.isEmpty ? 'текст' : selected;
    final newValue = '${text.substring(0, start)}$before$placeholder$after${text.substring(end)}';
    _ctrl.text = newValue;
    final pos = start + before.length + placeholder.length;
    _ctrl.selection = TextSelection.collapsed(offset: pos);
    _focusNode.requestFocus();
    widget.onChanged?.call(newValue);
  }

  void _insertLine(String prefix) {
    final text = _ctrl.text;
    final start = _ctrl.selection.start < 0 ? text.length : _ctrl.selection.start;
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    final newValue = '${text.substring(0, lineStart)}$prefix${text.substring(lineStart)}';
    _ctrl.text = newValue;
    _ctrl.selection = TextSelection.collapsed(offset: start + prefix.length);
    _focusNode.requestFocus();
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToolbar(c),
        TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(fontSize: 13, color: c.textSecondary.withValues(alpha: 0.5)),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: c.border),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: c.border),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: c.accent),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: c.text, height: 1.6),
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          onChanged: widget.onChanged,
        ),
      ],
    );
  }

  Widget _buildToolbar(ColorSet c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.border),
          left: BorderSide(color: c.border),
          right: BorderSide(color: c.border),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _btn('B', () => _insertAtCursor('**', '**'), c),
          _btn('I', () => _insertAtCursor('*', '*'), c, fontStyle: FontStyle.italic),
          _btn('S', () => _insertAtCursor('~~', '~~'), c, decoration: TextDecoration.lineThrough),
          _sep(c),
          _btn('H1', () => _insertLine('# '), c),
          _btn('H2', () => _insertLine('## '), c),
          _btn('H3', () => _insertLine('### '), c),
          _sep(c),
          _btn('—', () => _insertLine('- '), c),
          _btn('🔗', () => _insertAtCursor('[', '](url)'), c),
          _btn('<>', () => _insertAtCursor('`', '`'), c),
          _btn('❝', () => _insertLine('> '), c),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap, ColorSet c, {FontStyle? fontStyle, TextDecoration? decoration}) {
    return _ToolbarButton(
      label: label,
      onTap: onTap,
      colors: c,
      fontStyle: fontStyle,
      decoration: decoration,
    );
  }

  Widget _sep(ColorSet c) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: c.border,
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final ColorSet colors;
  final FontStyle? fontStyle;
  final TextDecoration? decoration;

  const _ToolbarButton({
    required this.label,
    required this.onTap,
    required this.colors,
    this.fontStyle,
    this.decoration,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered ? c.hoverOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: _hovered ? c.text : c.textSecondary,
              fontStyle: widget.fontStyle,
              decoration: widget.decoration,
            ),
          ),
        ),
      ),
    );
  }
}
