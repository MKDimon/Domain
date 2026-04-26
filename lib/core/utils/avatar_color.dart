import 'package:flutter/material.dart';

const _avatarColors = [
  Color(0xFF5B7FF5),
  Color(0xFF4CC38A),
  Color(0xFFF5BD41),
  Color(0xFFEB5757),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
  Color(0xFF06B6D4),
  Color(0xFF84CC16),
];

Color avatarColor(int userId) {
  return _avatarColors[userId % _avatarColors.length];
}

String avatarInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
