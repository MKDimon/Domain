import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/editor_defaults.dart';
import '../../../providers/editor_provider.dart';
import 'block_editors.dart';

class BlockEditorList extends ConsumerWidget {
  final int sectionIndex;

  const BlockEditorList({super.key, required this.sectionIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final editor = ref.watch(editorProvider);
    final section = editor.sections[sectionIndex];
    final blocks = section.data['blocks'] as List<dynamic>? ?? [];

    if (blocks.isEmpty) {
      return _emptyState(c, ref);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...blocks.asMap().entries.map((e) {
          final block = e.value as Map<String, dynamic>;
          return _BlockItem(
            key: ValueKey('block_${sectionIndex}_${e.key}'),
            sectionIndex: sectionIndex,
            blockIndex: e.key,
            block: block,
            c: c,
            canMoveUp: e.key > 0,
            canMoveDown: e.key < blocks.length - 1,
          );
        }),
        const SizedBox(height: 4),
        _addBlockButton(c, ref, blocks.length),
      ],
    );
  }

  Widget _emptyState(ColorSet c, WidgetRef ref) {
    return Column(
      children: [
        Text('Нет блоков', style: TextStyle(fontSize: 13, color: c.textSecondary)),
        const SizedBox(height: 8),
        _addBlockButton(c, ref, 0),
      ],
    );
  }

  Widget _addBlockButton(ColorSet c, WidgetRef ref, int atIndex) {
    return Center(
      child: Builder(
        builder: (context) => TextButton.icon(
          onPressed: () => _showBlockMenu(context, ref, atIndex),
          icon: Icon(Icons.add, size: 14, color: c.accent),
          label: Text('Добавить блок', style: TextStyle(fontSize: 12, color: c.accent)),
        ),
      ),
    );
  }

  void _showBlockMenu(BuildContext context, WidgetRef ref, int atIndex) {
    final c = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => _BlockTypeMenu(
        c: c,
        onSelect: (type) {
          Navigator.pop(ctx);
          final defaults = blockDefaults[type];
          if (defaults == null) return;
          final block = json.decode(json.encode(defaults)) as Map<String, dynamic>;
          ref.read(editorProvider.notifier).addBlock(sectionIndex, block, atIndex: atIndex);
        },
      ),
    );
  }
}

class _BlockItem extends ConsumerWidget {
  final int sectionIndex;
  final int blockIndex;
  final Map<String, dynamic> block;
  final ColorSet c;
  final bool canMoveUp;
  final bool canMoveDown;

  const _BlockItem({
    super.key,
    required this.sectionIndex,
    required this.blockIndex,
    required this.block,
    required this.c,
    this.canMoveUp = false,
    this.canMoveDown = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = block['type'] as String? ?? 'paragraph';
    final label = blockTypeLabels[type] ?? type;
    final iconCode = blockTypeIcons[type];

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.surfaceAlt.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              children: [
                if (canMoveUp)
                  InkWell(
                    onTap: () => ref.read(editorProvider.notifier).moveBlock(sectionIndex, blockIndex, blockIndex - 1),
                    borderRadius: BorderRadius.circular(3),
                    child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.arrow_upward, size: 12, color: c.textSecondary)),
                  ),
                if (canMoveDown)
                  InkWell(
                    onTap: () => ref.read(editorProvider.notifier).moveBlock(sectionIndex, blockIndex, blockIndex + 1),
                    borderRadius: BorderRadius.circular(3),
                    child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.arrow_downward, size: 12, color: c.textSecondary)),
                  ),
                const SizedBox(width: 4),
                Icon(IconData(iconCode ?? 0xe261, fontFamily: 'MaterialIcons'), size: 12, color: c.textSecondary),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textSecondary)),
                const Spacer(),
                InkWell(
                  onTap: () => _showInsertMenu(context, ref),
                  borderRadius: BorderRadius.circular(3),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.add, size: 14, color: c.textSecondary),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => ref.read(editorProvider.notifier).removeBlock(sectionIndex, blockIndex),
                  borderRadius: BorderRadius.circular(3),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 14, color: c.error.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: BlockEditor(
              sectionIndex: sectionIndex,
              blockIndex: blockIndex,
              block: block,
            ),
          ),
        ],
      ),
    );
  }

  void _showInsertMenu(BuildContext context, WidgetRef ref) {
    final c2 = Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    showModalBottomSheet(
      context: context,
      backgroundColor: c2.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => _BlockTypeMenu(
        c: c2,
        onSelect: (type) {
          Navigator.pop(ctx);
          final defaults = blockDefaults[type];
          if (defaults == null) return;
          final newBlock = Map<String, dynamic>.from(defaults);
          ref.read(editorProvider.notifier).addBlock(sectionIndex, newBlock, atIndex: blockIndex + 1);
        },
      ),
    );
  }
}

class _BlockTypeMenu extends StatelessWidget {
  final ColorSet c;
  final void Function(String type) onSelect;

  const _BlockTypeMenu({required this.c, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Добавить блок', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.5,
              children: blockDefaults.keys.map((type) {
                final label = blockTypeLabels[type] ?? type;
                final iconCode = blockTypeIcons[type];
                return InkWell(
                  onTap: () => onSelect(type),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Icon(IconData(iconCode ?? 0xe261, fontFamily: 'MaterialIcons'), size: 16, color: c.accent),
                        const SizedBox(width: 4),
                        Expanded(child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.text), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
