import 'package:flutter/widgets.dart';

class CommunityNavigation extends InheritedWidget {
  final void Function(int pageId) onPageSelect;

  const CommunityNavigation({
    super.key,
    required this.onPageSelect,
    required super.child,
  });

  static CommunityNavigation? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CommunityNavigation>();
  }

  @override
  bool updateShouldNotify(CommunityNavigation oldWidget) => false;
}
