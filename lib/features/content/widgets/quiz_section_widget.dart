import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/quiz_api.dart';
import '../../../data/models/page.dart';

class QuizSectionWidget extends ConsumerStatefulWidget {
  final Section section;
  final Color? communityColor;
  const QuizSectionWidget({super.key, required this.section, this.communityColor});

  @override
  ConsumerState<QuizSectionWidget> createState() => _QuizSectionWidgetState();
}

class _QuizSectionWidgetState extends ConsumerState<QuizSectionWidget> {
  late final QuizApi _api;
  String? _selectedMode;
  Color get _accentColor => widget.communityColor ?? (Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light).accent;
  bool _completed = false;
  Map<String, dynamic>? _existingResult;
  bool _loading = true;

  List<Map<String, dynamic>> get _cards {
    final raw = widget.section.data['cards'] as List<dynamic>? ??
        widget.section.config['cards'] as List<dynamic>? ?? [];
    return raw.cast<Map<String, dynamic>>();
  }

  bool get _isOneTime => widget.section.config['one_time'] == true;
  bool get _shuffle => widget.section.config['shuffle'] == true;

  Map<String, dynamic> get _modes {
    return widget.section.config['modes'] as Map<String, dynamic>? ?? {};
  }

  bool _modeEnabled(String mode) {
    final m = _modes[mode] as Map<String, dynamic>?;
    if (m == null) return true;
    return m['enabled'] != false;
  }

  String _modeLabel(String mode) {
    final m = _modes[mode] as Map<String, dynamic>?;
    final custom = m?['label'] as String?;
    if (custom != null && custom.isNotEmpty) return custom;
    return switch (mode) {
      'flashcards' => 'Карточки',
      'test' => 'Тест',
      'type' => 'Ввод ответа',
      _ => mode,
    };
  }

  bool get _canTest {
    if (_cards.length < 4) return false;
    return _cards.every((c) => (c['options'] as List<dynamic>?)?.isNotEmpty == true) || _cards.length >= 4;
  }

  @override
  void initState() {
    super.initState();
    _api = QuizApi(ref.read(apiClientProvider));
    _checkExistingResult();
  }

  Future<void> _checkExistingResult() async {
    if (!_isOneTime) {
      setState(() => _loading = false);
      return;
    }
    try {
      final result = await _api.myResult(widget.section.id);
      if (result['score'] != null) {
        _existingResult = result;
        _completed = true;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submitResult(String mode, int score, int total) async {
    try {
      await _api.submit(widget.section.id, mode: mode, score: score, total: total);
      if (_isOneTime) {
        _existingResult = {'mode': mode, 'score': score, 'total': total};
        _completed = true;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final title = widget.section.config['title'] as String?;

    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)));
    }

    if (_cards.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Карточки не настроены', style: TextStyle(fontSize: 13, color: c.textSecondary)),
      ));
    }

    if (_completed && _existingResult != null) {
      return _buildCompletedView(theme, c);
    }

    if (_selectedMode != null) {
      return _buildQuizMode(theme, c);
    }

    return _buildModeSelector(theme, c, title);
  }

  Widget _buildCompletedView(ThemeData theme, ColorSet c) {
    final score = _existingResult!['score'] as int? ?? 0;
    final total = _existingResult!['total'] as int? ?? 1;
    final pct = (score / total * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 48, color: c.success),
            const SizedBox(height: 12),
            Text('Квиз пройден', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('$score / $total ($pct%)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _accentColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme, ColorSet c, String? title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.quiz_outlined, size: 18, color: c.textSecondary),
            const SizedBox(width: 8),
            Text(title ?? 'Квиз', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_cards.length} карточек', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_modeEnabled('flashcards'))
              Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: _modeCard('flashcards', Icons.style_outlined, c, true))),
            if (_modeEnabled('test'))
              Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: _modeCard('test', Icons.checklist_outlined, c, _canTest))),
            if (_modeEnabled('type'))
              Expanded(child: _modeCard('type', Icons.keyboard_outlined, c, true)),
          ],
        ),
      ],
    );
  }

  Widget _modeCard(String mode, IconData icon, ColorSet c, bool enabled) {
    return InkWell(
      onTap: enabled ? () => setState(() => _selectedMode = mode) : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: _accentColor),
              const SizedBox(height: 8),
              Text(_modeLabel(mode), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
              if (!enabled)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Мало карточек', style: TextStyle(fontSize: 10, color: c.textSecondary)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizMode(ThemeData theme, ColorSet c) {
    final cards = List<Map<String, dynamic>>.from(_cards);
    if (_shuffle) cards.shuffle(Random());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              onPressed: () => setState(() => _selectedMode = null),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            Text(_modeLabel(_selectedMode!), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        switch (_selectedMode!) {
          'flashcards' => _FlashcardsView(cards: cards, onComplete: (s, t) => _submitResult('flashcards', s, t), communityColor: widget.communityColor),
          'test' => _TestView(cards: cards, onComplete: (s, t) => _submitResult('test', s, t), communityColor: widget.communityColor),
          'type' => _TypeView(cards: cards, onComplete: (s, t) => _submitResult('type', s, t), communityColor: widget.communityColor),
          _ => const SizedBox(),
        },
      ],
    );
  }
}

class _FlashcardsView extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final void Function(int score, int total) onComplete;
  final Color? communityColor;
  const _FlashcardsView({required this.cards, required this.onComplete, this.communityColor});

  @override
  State<_FlashcardsView> createState() => _FlashcardsViewState();
}

class _FlashcardsViewState extends State<_FlashcardsView> {
  int _index = 0;
  bool _flipped = false;
  int _known = 0;
  int _unknown = 0;
  Color get _accentColor => widget.communityColor ?? (Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light).accent;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;

    if (_done) {
      widget.onComplete(_known, widget.cards.length);
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text('Результат', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Знаю: $_known / ${widget.cards.length}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.success)),
            Text('Не знаю: $_unknown', style: TextStyle(fontSize: 14, color: c.error)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => setState(() { _index = 0; _known = 0; _unknown = 0; _done = false; _flipped = false; }), child: const Text('Начать заново')),
          ],
        ),
      );
    }

    final card = widget.cards[_index];
    final front = card['front'] as String? ?? '';
    final back = card['back'] as String? ?? '';
    final frontImage = card['frontImage'] as String? ?? card['front_image'] as String?;
    final backImage = card['backImage'] as String? ?? card['back_image'] as String?;
    final currentImage = _flipped ? backImage : frontImage;

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) { setState(() => _flipped = !_flipped); return KeyEventResult.handled; }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) { _markKnown(); return KeyEventResult.handled; }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) { _markUnknown(); return KeyEventResult.handled; }
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          LinearProgressIndicator(value: (_index + 1) / widget.cards.length, minHeight: 3),
          const SizedBox(height: 8),
          Text('${_index + 1} / ${widget.cards.length}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _flipped = !_flipped),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 140),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _flipped ? _accentColor.withValues(alpha: 0.08) : c.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _flipped ? _accentColor.withValues(alpha: 0.3) : c.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentImage != null && currentImage.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(currentImage, height: 120, fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    _flipped ? back : front,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.text),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _markUnknown,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Не знаю'),
                style: ElevatedButton.styleFrom(backgroundColor: c.error, foregroundColor: Colors.white),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _markKnown,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Знаю'),
                style: ElevatedButton.styleFrom(backgroundColor: c.success, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Пробел — перевернуть, ← не знаю, → знаю', style: TextStyle(fontSize: 11, color: c.textSecondary)),
        ],
      ),
    );
  }

  void _markKnown() {
    _known++;
    _advance();
  }

  void _markUnknown() {
    _unknown++;
    _advance();
  }

  void _advance() {
    if (_index + 1 >= widget.cards.length) {
      setState(() => _done = true);
    } else {
      setState(() { _index++; _flipped = false; });
    }
  }
}

class _TestView extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final void Function(int score, int total) onComplete;
  final Color? communityColor;
  const _TestView({required this.cards, required this.onComplete, this.communityColor});

  @override
  State<_TestView> createState() => _TestViewState();
}

class _TestViewState extends State<_TestView> {
  int _index = 0;
  int _score = 0;
  Color get _accentColor => widget.communityColor ?? (Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light).accent;
  String? _selected;
  bool _answered = false;
  bool _done = false;
  late List<String> _options;

  @override
  void initState() {
    super.initState();
    _generateOptions();
  }

  void _generateOptions() {
    final card = widget.cards[_index];
    final correct = card['back'] as String? ?? '';
    final customOpts = card['options'] as List<dynamic>?;
    if (customOpts != null && customOpts.isNotEmpty) {
      _options = customOpts.cast<String>();
      if (!_options.contains(correct)) _options.add(correct);
    } else {
      final others = widget.cards
          .where((c) => c != card)
          .map((c) => c['back'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList()
        ..shuffle();
      _options = [correct, ...others.take(3)]..shuffle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;

    if (_done) {
      widget.onComplete(_score, widget.cards.length);
      final pct = (_score / widget.cards.length * 100).round();
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text('Результат теста', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('$_score / ${widget.cards.length} ($pct%)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _accentColor)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => setState(() { _index = 0; _score = 0; _selected = null; _answered = false; _done = false; _generateOptions(); }), child: const Text('Начать заново')),
          ],
        ),
      );
    }

    final card = widget.cards[_index];
    final correct = card['back'] as String? ?? '';
    final question = card['front'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: (_index + 1) / widget.cards.length, minHeight: 3),
        const SizedBox(height: 8),
        Text('${_index + 1} / ${widget.cards.length}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        const SizedBox(height: 12),
        Text(question, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 16),
        ..._options.map((opt) {
          final isCorrect = opt == correct;
          final isSelected = opt == _selected;
          Color? bgColor;
          Color? borderColor;
          if (_answered) {
            if (isCorrect) { bgColor = c.success.withValues(alpha: 0.1); borderColor = c.success; }
            else if (isSelected) { bgColor = c.error.withValues(alpha: 0.1); borderColor = c.error; }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: _answered ? null : () {
                setState(() { _selected = opt; _answered = true; });
                if (isCorrect) _score++;
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor ?? c.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor ?? c.border),
                ),
                child: Text(opt, style: TextStyle(fontSize: 14, color: c.text)),
              ),
            ),
          );
        }),
        if (_answered)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton(
              onPressed: () {
                if (_index + 1 >= widget.cards.length) {
                  setState(() => _done = true);
                } else {
                  setState(() { _index++; _selected = null; _answered = false; });
                  _generateOptions();
                }
              },
              child: const Text('Далее'),
            ),
          ),
      ],
    );
  }
}

class _TypeView extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final void Function(int score, int total) onComplete;
  final Color? communityColor;
  const _TypeView({required this.cards, required this.onComplete, this.communityColor});

  @override
  State<_TypeView> createState() => _TypeViewState();
}

class _TypeViewState extends State<_TypeView> {
  int _index = 0;
  int _score = 0;
  bool _answered = false;
  bool _isCorrect = false;
  Color get _accentColor => widget.communityColor ?? (Theme.of(context).brightness == Brightness.dark ? AppColors.dark : AppColors.light).accent;
  bool _done = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _normalize(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  void _checkAnswer() {
    final correct = widget.cards[_index]['back'] as String? ?? '';
    _isCorrect = _normalize(_ctrl.text) == _normalize(correct);
    if (_isCorrect) _score++;
    setState(() => _answered = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;

    if (_done) {
      widget.onComplete(_score, widget.cards.length);
      final pct = (_score / widget.cards.length * 100).round();
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text('Результат', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('$_score / ${widget.cards.length} ($pct%)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _accentColor)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => setState(() { _index = 0; _score = 0; _answered = false; _done = false; _ctrl.clear(); }), child: const Text('Начать заново')),
          ],
        ),
      );
    }

    final card = widget.cards[_index];
    final question = card['front'] as String? ?? '';
    final correct = card['back'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: (_index + 1) / widget.cards.length, minHeight: 3),
        const SizedBox(height: 8),
        Text('${_index + 1} / ${widget.cards.length}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        const SizedBox(height: 12),
        Text(question, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          enabled: !_answered,
          decoration: InputDecoration(
            hintText: 'Введите ответ...',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onSubmitted: _answered ? null : (_) => _checkAnswer(),
        ),
        const SizedBox(height: 12),
        if (!_answered)
          ElevatedButton(onPressed: _ctrl.text.isNotEmpty ? _checkAnswer : null, child: const Text('Проверить'))
        else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isCorrect ? c.success.withValues(alpha: 0.1) : c.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(_isCorrect ? Icons.check_circle : Icons.cancel, size: 18, color: _isCorrect ? c.success : c.error),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _isCorrect ? 'Правильно!' : 'Неправильно. Ответ: $correct',
                  style: TextStyle(fontSize: 14, color: _isCorrect ? c.success : c.error),
                )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              if (_index + 1 >= widget.cards.length) {
                setState(() => _done = true);
              } else {
                setState(() { _index++; _answered = false; _isCorrect = false; _ctrl.clear(); });
              }
            },
            child: const Text('Далее'),
          ),
        ],
      ],
    );
  }
}
