import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'lua_sandbox.dart';

class ScriptRunner extends StatefulWidget {
  final String code;
  final SandboxContext context;
  final ColorSet c;
  final Color? communityColor;

  const ScriptRunner({
    super.key,
    required this.code,
    required this.context,
    required this.c,
    this.communityColor,
  });

  @override
  State<ScriptRunner> createState() => _ScriptRunnerState();
}

class _ScriptRunnerState extends State<ScriptRunner> {
  late LuaSandbox _sandbox;
  SandboxResult? _result;

  Color get accent => widget.communityColor ?? widget.c.accent;

  @override
  void initState() {
    super.initState();
    _sandbox = LuaSandbox();
    _run();
  }

  @override
  void didUpdateWidget(ScriptRunner old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) _run();
  }

  @override
  void dispose() {
    _sandbox.destroy();
    super.dispose();
  }

  void _run() {
    final result = _sandbox.execute(widget.code, widget.context);
    setState(() => _result = result);
  }

  void _onCallback(int id, [String? input]) {
    final result = _sandbox.invokeCallback(id, input);
    setState(() => _result = SandboxResult(
      success: _result?.success ?? true,
      blocks: result.blocks,
      logs: [...?_result?.logs, ...result.logs],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r == null) return const SizedBox.shrink();

    final c = widget.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!r.success && r.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.error.withValues(alpha: 0.1),
              border: Border.all(color: c.error.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(r.error!, style: TextStyle(fontSize: 13, color: c.error, fontFamily: 'monospace')),
          ),
        ...r.blocks.map((b) => _buildBlock(b, c)),
      ],
    );
  }

  Widget _buildBlock(ScriptBlock block, ColorSet c) {
    return switch (block.type) {
      'paragraph' => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(block.props['text'] ?? '', style: TextStyle(fontSize: 14, color: c.text, height: 1.6)),
      ),
      'heading' => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        child: Text(
          block.props['text'] ?? '',
          style: TextStyle(
            fontSize: _headingSize(block.props['level'] as int? ?? 2),
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
      ),
      'callout' => _buildCallout(block, c),
      'code' => _buildCode(block, c),
      'divider' => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(color: c.border, height: 1),
      ),
      'quote' => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 3))),
        child: Text(block.props['text'] ?? '', style: TextStyle(fontSize: 14, color: c.textSecondary, fontStyle: FontStyle.italic)),
      ),
      'list' => _buildList(block, c),
      'table' => _buildTable(block, c),
      'image' => _buildImage(block, c),
      'accordion' => _buildAccordion(block, c),
      'columns' => _buildColumns(block, c),
      '_button' => _buildButton(block, c),
      '_input' => _buildInput(block, c),
      _ => const SizedBox.shrink(),
    };
  }

  double _headingSize(int level) => switch (level) {
    1 => 28,
    2 => 22,
    3 => 18,
    4 => 16,
    5 => 14,
    _ => 13,
  };

  Widget _buildCallout(ScriptBlock block, ColorSet c) {
    final style = block.props['style'] ?? 'info';
    final color = switch (style) {
      'warning' => c.warning,
      'success' => c.success,
      'error' => c.error,
      'tip' => accent,
      _ => accent,
    };
    final icon = switch (style) {
      'warning' => Icons.warning_amber,
      'success' => Icons.check_circle_outline,
      'error' => Icons.error_outline,
      'tip' => Icons.lightbulb_outline,
      _ => Icons.info_outline,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(left: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(block.props['text'] ?? '', style: TextStyle(fontSize: 14, color: c.text))),
        ],
      ),
    );
  }

  Widget _buildCode(ScriptBlock block, ColorSet c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        block.props['content'] ?? '',
        style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: c.text, height: 1.5),
      ),
    );
  }

  Widget _buildList(ScriptBlock block, ColorSet c) {
    final items = (block.props['items'] as List?)?.cast<String>() ?? [];
    final ordered = block.props['style'] == 'ordered';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((e) {
          final prefix = ordered ? '${e.key + 1}.' : '•';
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 20, child: Text(prefix, style: TextStyle(fontSize: 14, color: c.textSecondary))),
                Expanded(child: Text(e.value, style: TextStyle(fontSize: 14, color: c.text))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTable(ScriptBlock block, ColorSet c) {
    final headers = (block.props['headers'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final rows = (block.props['rows'] as List?)?.map((r) {
      if (r is List) return r.map((e) => e.toString()).toList();
      return <String>[];
    }).toList() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.symmetric(inside: BorderSide(color: c.border, width: 0.5)),
        children: [
          if (headers.isNotEmpty)
            TableRow(
              decoration: BoxDecoration(color: c.surfaceAlt),
              children: headers.map((h) => Padding(
                padding: const EdgeInsets.all(10),
                child: Text(h, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
              )).toList(),
            ),
          ...rows.map((row) => TableRow(
            children: List.generate(
              headers.isEmpty ? (row.length) : headers.length,
              (i) => Padding(
                padding: const EdgeInsets.all(10),
                child: Text(i < row.length ? row[i] : '', style: TextStyle(fontSize: 13, color: c.text)),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildImage(ScriptBlock block, ColorSet c) {
    final url = block.props['url'] as String? ?? '';
    if (url.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) =>
          Text('Failed to load image', style: TextStyle(color: c.textSecondary, fontSize: 13))),
      ),
    );
  }

  Widget _buildAccordion(ScriptBlock block, ColorSet c) {
    final items = (block.props['items'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: items.whereType<Map>().map((item) {
          return ExpansionTile(
            title: Text(item['title']?.toString() ?? '', style: TextStyle(fontSize: 14, color: c.text)),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [Text(item['content']?.toString() ?? '', style: TextStyle(fontSize: 14, color: c.textSecondary))],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildColumns(ScriptBlock block, ColorSet c) {
    final columns = (block.props['columns'] as List?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns.asMap().entries.map((e) {
          final blocks = (e.value is Map ? (e.value as Map)['blocks'] as List? : null) ?? [];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: e.key > 0 ? 12 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: blocks.map((b) {
                  if (b is Map<String, dynamic>) {
                    return _buildBlock(ScriptBlock(b['type'] ?? '', Map.from(b)..remove('type')), c);
                  }
                  return const SizedBox.shrink();
                }).toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildButton(ScriptBlock block, ColorSet c) {
    final label = block.props['label'] ?? '';
    final cbId = block.props['callbackId'] as int?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: cbId != null ? () => _onCallback(cbId) : null,
        style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
        child: Text(label),
      ),
    );
  }

  Widget _buildInput(ScriptBlock block, ColorSet c) {
    final placeholder = block.props['placeholder'] ?? '';
    final cbId = block.props['callbackId'] as int?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: TextStyle(color: c.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.border)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        style: TextStyle(fontSize: 14, color: c.text),
        onSubmitted: cbId != null ? (val) => _onCallback(cbId, val) : null,
      ),
    );
  }
}
