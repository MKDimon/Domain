import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/slug.dart';
import '../../../data/api/pages_api.dart';
import '../../../data/api/sections_api.dart';

class _PageTemplate {
  final String id;
  final String name;
  final String description;
  final String icon;
  final List<_SectionDef> sections;
  const _PageTemplate({required this.id, required this.name, required this.description, required this.icon, this.sections = const []});
}

class _SectionDef {
  final String sectionType;
  final Map<String, dynamic> config;
  final Map<String, dynamic> data;
  const _SectionDef({required this.sectionType, this.config = const {}, this.data = const {}});
}

const _templates = <_PageTemplate>[
  _PageTemplate(id: 'empty', name: 'Пустая страница', description: 'Чистый лист — добавьте секции вручную', icon: '[ ]'),
  _PageTemplate(id: 'info', name: 'Информация', description: 'Текстовая страница с вкладками', icon: 'i', sections: [
    _SectionDef(sectionType: 'content', config: {'title': 'Content', 'visible': true, 'editable': true}, data: {
      'version': 1,
      'blocks': [
        {'type': 'heading', 'level': 1, 'text': ''},
        {'type': 'tabs', 'tabs': [
          {'label': '', 'blocks': [{'type': 'paragraph', 'text': ''}]},
          {'label': '', 'blocks': [{'type': 'paragraph', 'text': ''}]},
          {'label': '', 'blocks': [{'type': 'paragraph', 'text': ''}]},
        ]},
        {'type': 'callout', 'style': 'info', 'text': ''},
      ],
    }),
  ]),
  _PageTemplate(id: 'faq', name: 'FAQ', description: 'Вопросы и ответы в формате аккордеона', icon: '?', sections: [
    _SectionDef(sectionType: 'content', config: {'title': 'FAQ', 'visible': true, 'editable': true}, data: {
      'version': 1,
      'blocks': [
        {'type': 'heading', 'level': 1, 'text': 'FAQ'},
        {'type': 'accordion', 'items': [
          {'title': '', 'content': ''},
          {'title': '', 'content': ''},
          {'title': '', 'content': ''},
        ], 'allowMultipleOpen': true},
      ],
    }),
  ]),
  _PageTemplate(id: 'chat', name: 'Чат', description: 'Канал для общения в реальном времени', icon: '#', sections: [
    _SectionDef(sectionType: 'chat', config: {'title': 'Chat', 'visible': true, 'moderated': false}, data: {'messages': [], 'settings': {'max_length': 500, 'moderated': false}}),
  ]),
  _PageTemplate(id: 'voice', name: 'Голосовой канал', description: 'Комната для голосового общения', icon: '🎙'),
  _PageTemplate(id: 'catalog', name: 'Каталог товаров', description: 'Витрина с карточками товаров', icon: '\$', sections: [
    _SectionDef(sectionType: 'content', config: {'title': 'Catalog', 'visible': true, 'editable': true}, data: {
      'version': 1,
      'blocks': [
        {'type': 'heading', 'level': 1, 'text': ''},
        {'type': 'product-card', 'items': [{'name': '', 'price': '', 'image': '', 'description': '', 'tags': []}], 'layout': 'grid'},
      ],
    }),
  ]),
  _PageTemplate(id: 'quiz', name: 'Квиз', description: 'Интерактивные карточки с вопросами', icon: '▶', sections: [
    _SectionDef(sectionType: 'quiz', config: {'title': 'Quiz', 'visible': true}, data: {'cards': [], 'settings': {'shuffleOnStart': true, 'showProgress': true}}),
  ]),
  _PageTemplate(id: 'booking', name: 'Запись', description: 'Система онлайн-записи с календарём', icon: '📅', sections: [
    _SectionDef(sectionType: 'booking', config: {
      'title': 'Booking', 'visible': true, 'slot_duration_minutes': 60, 'max_advance_days': 30,
      'require_confirmation': true, 'allow_cancel_before_minutes': 120,
      'working_hours': {
        'mon': {'start': '09:00', 'end': '18:00', 'enabled': true},
        'tue': {'start': '09:00', 'end': '18:00', 'enabled': true},
        'wed': {'start': '09:00', 'end': '18:00', 'enabled': true},
        'thu': {'start': '09:00', 'end': '18:00', 'enabled': true},
        'fri': {'start': '09:00', 'end': '18:00', 'enabled': true},
        'sat': {'start': '09:00', 'end': '18:00', 'enabled': false},
        'sun': {'start': '09:00', 'end': '18:00', 'enabled': false},
      },
    }, data: {}),
  ]),
  _PageTemplate(id: 'announcements', name: 'Объявления', description: 'Лента новостей и объявлений', icon: '📢', sections: [
    _SectionDef(sectionType: 'announcements', config: {'title': 'Announcements', 'visible': true}, data: {}),
  ]),
  _PageTemplate(id: 'poll', name: 'Опрос', description: 'Голосование с несколькими вариантами', icon: '📊', sections: [
    _SectionDef(sectionType: 'polls', config: {'title': 'Poll', 'visible': true}, data: {'question': '', 'options': []}),
  ]),
  _PageTemplate(id: 'calendar', name: 'Календарь', description: 'Расписание событий', icon: '🗓️', sections: [
    _SectionDef(sectionType: 'calendar', config: {'title': 'Calendar', 'visible': true}, data: {}),
  ]),
];

class CreatePageDialog extends StatefulWidget {
  final int communityId;
  final String communitySlug;
  final ApiClient apiClient;
  final ColorSet c;
  final bool canSetVisibility;

  const CreatePageDialog({
    super.key,
    required this.communityId,
    required this.communitySlug,
    required this.apiClient,
    required this.c,
    this.canSetVisibility = false,
  });

  static Future<bool?> show(BuildContext context, {
    required int communityId,
    required String communitySlug,
    required ApiClient apiClient,
    required ColorSet c,
    bool canSetVisibility = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CreatePageDialog(
        communityId: communityId,
        communitySlug: communitySlug,
        apiClient: apiClient,
        c: c,
        canSetVisibility: canSetVisibility,
      ),
    );
  }

  @override
  State<CreatePageDialog> createState() => _CreatePageDialogState();
}

class _CreatePageDialogState extends State<CreatePageDialog> {
  int _stage = 1;
  _PageTemplate? _selected;

  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  bool _slugManual = false;
  String _chatMode = 'public';
  String _visibility = 'public';
  String? _error;
  bool _creating = false;

  ColorSet get c => widget.c;

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  void _selectTemplate(_PageTemplate tpl) {
    setState(() { _selected = tpl; _stage = 2; });
  }

  void _backToTemplates() {
    setState(() {
      _stage = 1;
      _selected = null;
      _titleController.clear();
      _slugController.clear();
      _slugManual = false;
      _chatMode = 'public';
      _visibility = 'public';
      _error = null;
    });
  }

  void _onTitleChanged(String value) {
    if (!_slugManual) {
      _slugController.text = generateSlug(value);
    }
    setState(() {});
  }

  Future<void> _createPage() async {
    final title = _titleController.text.trim();
    final slug = _slugController.text.trim();
    if (title.isEmpty || slug.isEmpty) {
      setState(() => _error = 'Заполните название и slug');
      return;
    }
    if (_selected == null) return;

    setState(() { _creating = true; _error = null; });
    try {
      final pagesApi = PagesApi(widget.apiClient);
      final sectionsApi = SectionsApi(widget.apiClient);

      final isChatPage = _selected!.id == 'chat';
      final isVoicePage = _selected!.id == 'voice';

      final pageData = await pagesApi.create(
        communityId: widget.communityId,
        title: title,
        slug: slug,
        pageType: _selected!.id,
        visibility: _visibility != 'public' ? _visibility : null,
      );

      final pageId = pageData['id'] as int;

      if (!isChatPage && !isVoicePage) {
        final sections = _selected!.sections;
        for (var i = 0; i < sections.length; i++) {
          final sec = sections[i];
          await sectionsApi.create(
            pageId: pageId,
            sectionType: sec.sectionType,
            order: i,
            config: sec.config,
            data: sec.data,
          );
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
        child: _stage == 1 ? _buildTemplateStage() : _buildFormStage(),
      ),
    );
  }

  Widget _buildTemplateStage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Создать страницу', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
              const Spacer(),
              IconButton(icon: Icon(Icons.close, color: c.textSecondary), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Выберите шаблон', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          const SizedBox(height: 20),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1,
              ),
              itemCount: _templates.length,
              itemBuilder: (ctx, i) => _TemplateCard(
                template: _templates[i], c: c,
                onTap: () => _selectTemplate(_templates[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormStage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: Icon(Icons.arrow_back, color: c.textSecondary), onPressed: _backToTemplates),
              const SizedBox(width: 8),
              Text('Детали страницы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
              const Spacer(),
              IconButton(icon: Icon(Icons.close, color: c.textSecondary), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),

          // Selected template badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.1),
                    border: Border.all(color: c.accent.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(_selected!.icon, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: _selected!.name, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                    TextSpan(text: ' — ${_selected!.description}', style: TextStyle(color: c.textSecondary)),
                  ], style: const TextStyle(fontSize: 14))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text('Название', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            autofocus: true,
            onChanged: _onTitleChanged,
            style: TextStyle(color: c.text),
            decoration: InputDecoration(
              hintText: 'Введите название страницы',
              hintStyle: TextStyle(color: c.textSecondary),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          // Slug
          Text('Slug (URL)', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: _slugController,
            onChanged: (_) { _slugManual = true; setState(() {}); },
            style: TextStyle(color: c.text),
            decoration: InputDecoration(
              hintText: 'url-страницы',
              hintStyle: TextStyle(color: c.textSecondary),
              isDense: true,
            ),
          ),

          // Chat mode (only for chat template)
          if (_selected?.id == 'chat') ...[
            const SizedBox(height: 16),
            Text('Режим чата', style: TextStyle(fontSize: 14, color: c.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                _ModeChip(label: 'П��бличный', selected: _chatMode == 'public', onTap: () => setState(() => _chatMode = 'public'), c: c),
                const SizedBox(width: 8),
                _ModeChip(label: 'Приватный', selected: _chatMode == 'private', onTap: () => setState(() => _chatMode = 'private'), c: c),
              ],
            ),
          ],

          // Visibility (owner/moderator only)
          if (widget.canSetVisibility) ...[
            const SizedBox(height: 16),
            Text('Видимость', style: TextStyle(fontSize: 14, color: c.textSecondary)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              dropdownColor: c.surface,
              style: TextStyle(color: c.text, fontSize: 14),
              decoration: const InputDecoration(isDense: true),
              items: [
                DropdownMenuItem(value: 'public', child: Text('Публичная', style: TextStyle(color: c.text))),
                DropdownMenuItem(value: 'moderator', child: Text('Только модераторы', style: TextStyle(color: c.text))),
                DropdownMenuItem(value: 'owner', child: Text('Только владелец', style: TextStyle(color: c.text))),
              ],
              onChanged: (v) { if (v != null) setState(() => _visibility = v); },
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: c.error, fontSize: 13)),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _creating ? null : _createPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _creating
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Создать', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final _PageTemplate template;
  final ColorSet c;
  final VoidCallback onTap;
  const _TemplateCard({required this.template, required this.c, required this.onTap});
  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final c = widget.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _hovered ? Matrix4.translationValues(0, -2, 0) : Matrix4.identity(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: _hovered ? c.accent : c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.1),
                  border: Border.all(color: c.accent.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(t.icon, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.accent)),
              ),
              const SizedBox(height: 10),
              Text(t.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(t.description, style: TextStyle(fontSize: 12, color: c.textSecondary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorSet c;
  const _ModeChip({required this.label, required this.selected, required this.onTap, required this.c});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? c.accent : Colors.transparent,
        border: Border.all(color: selected ? c.accent : c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : c.text)),
    ),
  );
}
