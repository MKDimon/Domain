import 'package:flutter/material.dart';

class AppColors {
  static const dark = DarkColors();
  static const light = LightColors();

  /// Returns a ColorSet with [accent] overridden by [communityColor] if provided.
  static ColorSet withCommunity(ColorSet base, Color? communityColor) {
    if (communityColor == null) return base;
    return _ThemedColors(base, communityColor);
  }
}

class _ThemedColors implements ColorSet {
  final ColorSet _b;
  final Color _acc;
  const _ThemedColors(this._b, this._acc);

  @override Color get bg => _b.bg;
  @override Color get surface => _b.surface;
  @override Color get surfaceAlt => _b.surfaceAlt;
  @override Color get surfaceHover => _b.surfaceHover;
  @override Color get border => _b.border;
  @override Color get borderHover => _b.borderHover;
  @override Color get inputBorder => _b.inputBorder;
  @override Color get text => _b.text;
  @override Color get textSecondary => _b.textSecondary;
  @override Color get textOnAccent => _b.textOnAccent;
  @override Color get accent => _acc;
  @override Color get accentHover => Color.lerp(_acc, Colors.black, 0.12) ?? _acc;
  @override Color get success => _b.success;
  @override Color get warning => _b.warning;
  @override Color get error => _b.error;
  @override Color get dangerHover => _b.dangerHover;
  @override Color get chatBg => _b.chatBg;
  @override Color get chatPanel => _b.chatPanel;
  @override Color get scrollbar => _b.scrollbar;
  @override Color get scrollbarHover => _b.scrollbarHover;
  @override Color get hoverOverlay => _b.hoverOverlay;
  @override Color get activeOverlay => _b.activeOverlay;
  @override Color get focusRing => _acc.withValues(alpha: 0.15);
  @override Color get calloutInfoBg => _b.calloutInfoBg;
  @override Color get calloutSuccessBg => _b.calloutSuccessBg;
  @override Color get calloutWarningBg => _b.calloutWarningBg;
  @override Color get calloutErrorBg => _b.calloutErrorBg;
  @override Color get code => _b.code;
  @override Color get codeBg => _b.codeBg;
  @override Color get quoteBg => _b.quoteBg;
  @override Color get appGlow1 => _b.appGlow1;
  @override Color get appGlow2 => _b.appGlow2;
  @override Color get appGlow3 => _b.appGlow3;
}

abstract class ColorSet {
  Color get bg;
  Color get surface;
  Color get surfaceAlt;
  Color get surfaceHover;
  Color get border;
  Color get borderHover;
  Color get inputBorder;
  Color get text;
  Color get textSecondary;
  Color get textOnAccent;
  Color get accent;
  Color get accentHover;
  Color get success;
  Color get warning;
  Color get error;
  Color get dangerHover;
  Color get chatBg;
  Color get chatPanel;
  Color get scrollbar;
  Color get scrollbarHover;
  Color get hoverOverlay;
  Color get activeOverlay;
  Color get focusRing;
  Color get calloutInfoBg;
  Color get calloutSuccessBg;
  Color get calloutWarningBg;
  Color get calloutErrorBg;
  Color get code;
  Color get codeBg;
  Color get quoteBg;
  Color get appGlow1;
  Color get appGlow2;
  Color get appGlow3;
}

class DarkColors implements ColorSet {
  const DarkColors();

  @override final Color bg = const Color(0xFF0F0F0F);
  @override final Color surface = const Color(0xFF1A1A1A);
  @override final Color surfaceAlt = const Color(0xFF111111);
  @override final Color surfaceHover = const Color(0xFF1F1F1F);

  @override final Color border = const Color(0xFF2A2A2A);
  @override final Color borderHover = const Color(0xFF444444);
  @override final Color inputBorder = const Color(0xFF333333);

  @override final Color text = const Color(0xFFE0E0E0);
  @override final Color textSecondary = const Color(0xFF888888);
  @override final Color textOnAccent = const Color(0xFFFFFFFF);

  @override final Color accent = const Color(0xFF5B7FF5);
  @override final Color accentHover = const Color(0xFF4A6DE0);

  @override final Color success = const Color(0xFF4CC38A);
  @override final Color warning = const Color(0xFFF5BD41);
  @override final Color error = const Color(0xFFEB5757);
  @override final Color dangerHover = const Color(0xFFD44040);

  @override final Color chatBg = const Color(0xFF1A1A1A);
  @override final Color chatPanel = const Color(0xFF121212);

  @override final Color scrollbar = const Color(0xFF333333);
  @override final Color scrollbarHover = const Color(0xFF444444);

  @override Color get hoverOverlay => Colors.white.withValues(alpha: 0.05);
  @override Color get activeOverlay => Colors.white.withValues(alpha: 0.08);
  @override Color get focusRing => const Color(0xFF5B7FF5).withValues(alpha: 0.15);

  @override Color get calloutInfoBg => const Color(0xFF5B7FF5).withValues(alpha: 0.10);
  @override Color get calloutSuccessBg => const Color(0xFF4CC38A).withValues(alpha: 0.10);
  @override Color get calloutWarningBg => const Color(0xFFF5BD41).withValues(alpha: 0.10);
  @override Color get calloutErrorBg => const Color(0xFFEB5757).withValues(alpha: 0.10);

  @override final Color code = const Color(0xFFC8F07E);
  @override Color get codeBg => const Color(0xFFC8F07E).withValues(alpha: 0.10);

  @override Color get quoteBg => const Color(0xFF5B7FF5).withValues(alpha: 0.05);

  @override Color get appGlow1 => const Color(0xFF5B7FF5).withValues(alpha: 0.18);
  @override Color get appGlow2 => const Color(0xFF8B5CF6).withValues(alpha: 0.15);
  @override Color get appGlow3 => const Color(0xFFD94066).withValues(alpha: 0.06);
}

class LightColors implements ColorSet {
  const LightColors();

  @override final Color bg = const Color(0xFFF4F5F7);
  @override final Color surface = const Color(0xFFFFFFFF);
  @override final Color surfaceAlt = const Color(0xFFF0F1F3);
  @override final Color surfaceHover = const Color(0xFFE8E9EB);

  @override final Color border = const Color(0xFFDCDEE2);
  @override final Color borderHover = const Color(0xFFBBBBBB);
  @override final Color inputBorder = const Color(0xFFCCCCCC);

  @override final Color text = const Color(0xFF1A1A1A);
  @override final Color textSecondary = const Color(0xFF666666);
  @override final Color textOnAccent = const Color(0xFFFFFFFF);

  @override final Color accent = const Color(0xFF4A6BD4);
  @override final Color accentHover = const Color(0xFF3A5BC0);

  @override final Color success = const Color(0xFF2E9E6A);
  @override final Color warning = const Color(0xFFC99520);
  @override final Color error = const Color(0xFFD44040);
  @override final Color dangerHover = const Color(0xFFB83030);

  @override final Color chatBg = const Color(0xFFFFFFFF);
  @override final Color chatPanel = const Color(0xFFF0F1F3);

  @override final Color scrollbar = const Color(0xFFCCCCCC);
  @override final Color scrollbarHover = const Color(0xFFAAAAAA);

  @override Color get hoverOverlay => Colors.black.withValues(alpha: 0.04);
  @override Color get activeOverlay => Colors.black.withValues(alpha: 0.07);
  @override Color get focusRing => const Color(0xFF4A6BD4).withValues(alpha: 0.20);

  @override Color get calloutInfoBg => const Color(0xFF4A6BD4).withValues(alpha: 0.08);
  @override Color get calloutSuccessBg => const Color(0xFF2E9E6A).withValues(alpha: 0.08);
  @override Color get calloutWarningBg => const Color(0xFFC99520).withValues(alpha: 0.08);
  @override Color get calloutErrorBg => const Color(0xFFD44040).withValues(alpha: 0.08);

  @override final Color code = const Color(0xFF476582);
  @override Color get codeBg => const Color(0xFF476582).withValues(alpha: 0.08);

  @override Color get quoteBg => const Color(0xFF4A6BD4).withValues(alpha: 0.05);

  @override Color get appGlow1 => const Color(0xFF4A6BD4).withValues(alpha: 0.10);
  @override Color get appGlow2 => const Color(0xFF8B5CF6).withValues(alpha: 0.09);
  @override Color get appGlow3 => const Color(0xFFD94066).withValues(alpha: 0.05);
}
