import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'update_provider.dart';

class UpdateGate extends ConsumerStatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
    } else {
      _ready = true;
    }
  }

  Future<void> _runCheck() async {
    try {
      final result = ref.read(updateProvider.notifier).checkAndApply();
      final willRestart = await result.timeout(const Duration(seconds: 8));
      if (!willRestart && mounted) {
        setState(() => _ready = true);
      }
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;

    final update = ref.watch(updateProvider);
    return _UpdateSplash(state: update);
  }
}

class _UpdateSplash extends StatelessWidget {
  final UpdateState state;
  const _UpdateSplash({required this.state});

  @override
  Widget build(BuildContext context) {
    final statusText = switch (state.phase) {
      UpdatePhase.checking => 'Проверка обновлений...',
      UpdatePhase.downloading => 'Загрузка обновления${state.version != null ? ' ${state.version}' : ''}...',
      UpdatePhase.installing => 'Установка обновления...',
      UpdatePhase.idle => '',
    };

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF1a1a2e),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('assets/logo.svg', width: 64, height: 64),
              const SizedBox(height: 32),
              if (state.phase == UpdatePhase.downloading) ...[
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: state.progress > 0 ? state.progress : null,
                      backgroundColor: Colors.white12,
                      color: const Color(0xFF5b7ff5),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                statusText,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
