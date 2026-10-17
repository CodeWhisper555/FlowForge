import 'package:flutter/foundation.dart';

@immutable
class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final bool isAnonymous;

  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.isAnonymous = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'isAnonymous': isAnonymous,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      isAnonymous: map['isAnonymous'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          other.id == id &&
          other.email == email &&
          other.displayName == displayName &&
          other.isAnonymous == isAnonymous;

  @override
  int get hashCode => Object.hash(id, email, displayName, isAnonymous);
}
