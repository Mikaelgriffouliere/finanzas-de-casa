import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class PersonAvatar extends StatelessWidget {
  final String name;
  final String color;
  final String avatar;
  final double radius;

  const PersonAvatar({
    super.key,
    required this.name,
    this.color = '',
    this.avatar = '',
    this.radius = 20,
  });

  Color _resolveColor() {
    if (color.isNotEmpty) {
      return AppConstants.parseColor(color);
    }
    final index = name.hashCode.abs() % AppConstants.personColors.length;
    return AppConstants.parseColor(AppConstants.personColors[index]);
  }

  String get _initial {
    if (name.isEmpty) return '?';
    return name.trim().characters.first.toUpperCase();
  }

  bool get _isPhoto => avatar.startsWith(AppConstants.avatarPhotoPrefix);
  bool get _isEmoji => avatar.startsWith(AppConstants.avatarEmojiPrefix);

  String get _emoji {
    final value = avatar.substring(AppConstants.avatarEmojiPrefix.length);
    return value.isEmpty ? _initial : value;
  }

  String get _photoPath {
    return avatar.substring(AppConstants.avatarPhotoPrefix.length);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _resolveColor();
    final Widget child;
    if (_isPhoto) {
      child = ClipOval(
        child: Image.file(
          File(_photoPath),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _fallback(backgroundColor),
        ),
      );
    } else if (_isEmoji) {
      child = Center(
        child: Text(
          _emoji,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: radius * 1.1, height: 1),
        ),
      );
    } else {
      child = _fallback(backgroundColor);
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isPhoto ? null : backgroundColor,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _fallback(Color backgroundColor) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
