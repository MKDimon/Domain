import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShellCommunity {
  final String slug;
  final String name;
  final Color color;
  const ShellCommunity({required this.slug, required this.name, required this.color});
}

final shellCommunityProvider = StateProvider<ShellCommunity?>((ref) => null);

bool isNavHistoryNav = false;

class NavHistory {
  static final NavHistory _instance = NavHistory._();
  factory NavHistory() => _instance;
  NavHistory._();

  final List<String> _back = [];
  final List<String> _forward = [];
  String? _current;

  void push(String location) {
    if (location == _current) return;
    if (_current != null) _back.add(_current!);
    _current = location;
    _forward.clear();
    if (_back.length > 50) _back.removeAt(0);
  }

  bool get canGoBack => _back.isNotEmpty;
  bool get canGoForward => _forward.isNotEmpty;

  String? goBack() {
    if (_back.isEmpty) return null;
    if (_current != null) _forward.add(_current!);
    _current = _back.removeLast();
    return _current;
  }

  String? goForward() {
    if (_forward.isEmpty) return null;
    if (_current != null) _back.add(_current!);
    _current = _forward.removeLast();
    return _current;
  }
}
