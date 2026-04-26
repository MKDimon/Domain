import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/api/polls_api.dart';
import '../../../data/models/page.dart';
import '../../../providers/auth_provider.dart';

class PollSectionWidget extends ConsumerStatefulWidget {
  final Section section;
  const PollSectionWidget({super.key, required this.section});

  @override
  ConsumerState<PollSectionWidget> createState() => _PollSectionWidgetState();
}

class _PollSectionWidgetState extends ConsumerState<PollSectionWidget> {
  late final PollsApi _api;
  bool _loading = true;
  bool _voting = false;
  bool _cancelling = false;
  String _question = '';
  List<_PollOption> _options = [];
  int _totalVotes = 0;
  bool _hasVoted = false;
  String? _userVote;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = PollsApi(ref.read(apiClientProvider));
    _loadPoll();
  }

  Future<void> _loadPoll() async {
    if (_options.isEmpty) setState(() => _loading = true);
    try {
      final data = await _api.get(widget.section.id);
      final sectionData = data['data'] as Map<String, dynamic>? ?? {};
      final rawOptions = sectionData['options'] as List<dynamic>? ?? [];
      final voteCounts = data['vote_counts'] as Map<String, dynamic>? ?? {};

      _question = sectionData['question'] as String? ?? '';
      _options = rawOptions.asMap().entries.map((e) {
        final o = e.value as Map<String, dynamic>;
        final id = o['id']?.toString() ?? '${e.key}';
        return _PollOption(
          id: id,
          text: o['text'] as String? ?? '',
          votes: voteCounts[id] as int? ?? 0,
        );
      }).toList();
      _totalVotes = data['total_votes'] as int? ?? 0;
      _userVote = data['user_vote'] as String?;
      _hasVoted = _userVote != null;
      _error = null;
    } catch (_) {
      final sd = widget.section.data;
      final cfg = widget.section.config;
      _question = sd['question'] as String? ?? cfg['question'] as String? ?? '';
      final raw = sd['options'] as List<dynamic>? ?? cfg['options'] as List<dynamic>? ?? [];
      _options = raw.asMap().entries.map((e) {
        final o = e.value;
        return _PollOption(
          id: (o is Map ? o['id']?.toString() : null) ?? '${e.key}',
          text: o is Map ? (o['text'] as String? ?? '') : '$o',
          votes: 0,
        );
      }).toList();
      _totalVotes = 0;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _vote(String optionId) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || _hasVoted || _voting) return;
    setState(() { _voting = true; _error = null; });
    try {
      await _api.vote(widget.section.id, optionId);
      _hasVoted = true;
      _userVote = optionId;
      await _loadPoll();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already') || msg.contains('poll_already_voted')) {
        _hasVoted = true;
        await _loadPoll();
      } else {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _cancelVote() async {
    if (_cancelling) return;
    setState(() { _cancelling = true; _error = null; });
    try {
      await _api.unvote(widget.section.id);
      _hasVoted = false;
      _userVote = null;
      await _loadPoll();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  int _votePercent(int votes) {
    if (_totalVotes == 0) return 0;
    return (votes / _totalVotes * 100).round();
  }

  int get _maxVotes {
    if (_options.isEmpty) return 0;
    return _options.map((o) => o.votes).reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.brightness == Brightness.dark ? AppColors.dark : AppColors.light;
    final auth = ref.watch(authProvider);
    final title = widget.section.config['title'] as String?;
    final allowCancel = widget.section.config['allow_vote_cancel'] != false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 18, color: c.textSecondary),
            const SizedBox(width: 8),
            Text(title ?? 'Опрос', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),

        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_question.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Опрос не настроен', style: theme.textTheme.bodySmall?.copyWith(color: c.textSecondary)),
          ))
        else ...[
          Text(_question, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: c.error, fontSize: 13)),
            ),

          if (_hasVoted && auth.isAuthenticated && allowCancel)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: _cancelling ? null : _cancelVote,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.error,
                    side: BorderSide(color: c.error),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: _cancelling
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Отменить голос'),
                ),
              ),
            ),

          ..._options.map((opt) => _buildOption(opt, theme, c, auth)),

          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.people_outline, size: 14, color: c.textSecondary),
              const SizedBox(width: 6),
              Text('$_totalVotes голосов', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          ),

          if (!auth.isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(child: Text('Войдите, чтобы голосовать', style: TextStyle(fontSize: 13, color: c.textSecondary))),
            ),
        ],
      ],
    );
  }

  Widget _buildOption(_PollOption opt, ThemeData theme, ColorSet c, AuthState auth) {
    final isLeading = _hasVoted && opt.votes == _maxVotes && opt.votes > 0;
    final isSelected = _userVote == opt.id;
    final pct = _votePercent(opt.votes);
    final accentColor = theme.colorScheme.primary;

    if (!_hasVoted && auth.isAuthenticated) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: _voting ? null : () => _vote(opt.id),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(opt.text, style: TextStyle(fontSize: 14, color: c.text)),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: isLeading ? accentColor.withValues(alpha: 0.4) : c.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    height: 40,
                    width: double.infinity,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: pct / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.15)
                              : accentColor.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.check_circle, size: 16, color: accentColor),
                          ),
                        Expanded(child: Text(opt.text, style: TextStyle(fontSize: 14, color: c.text, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500))),
                        Text('$pct%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accentColor, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PollOption {
  final String id;
  final String text;
  final int votes;
  _PollOption({required this.id, required this.text, required this.votes});
}
