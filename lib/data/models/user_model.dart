import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';  // ✅ ADDED

/// User model representing a RingTask application user
class UserModel extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? phoneNumber;
  final String? bio;
  final bool isEmailVerified;
  final bool isActive;
  final List<String>? preferences;
  final Map<String, dynamic>? metadata;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.phoneNumber,
    this.bio,
    this.isEmailVerified = false,
    this.isActive = true,
    this.preferences,
    this.metadata,
  });

  /// ✅ NEW: Create UserModel from Firebase User (for AuthRepository)
  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      photoUrl: user.photoURL ?? '',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      updatedAt: user.metadata.lastSignInTime ?? DateTime.now(),
      phoneNumber: user.phoneNumber,
      isEmailVerified: user.emailVerified,
      isActive: true,
    );
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? phoneNumber,
    String? bio,
    bool? isEmailVerified,
    bool? isActive,
    List<String>? preferences,
    Map<String, dynamic>? metadata,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isActive: isActive ?? this.isActive,
      preferences: preferences ?? this.preferences,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert user to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'phoneNumber': phoneNumber,
      'bio': bio,
      'isEmailVerified': isEmailVerified,
      'isActive': isActive,
      'preferences': preferences,
      'metadata': metadata,
    };
  }

  /// Create a UserModel from Firestore map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
      phoneNumber: map['phoneNumber'] as String?,
      bio: map['bio'] as String?,
      isEmailVerified: map['isEmailVerified'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      preferences: map['preferences'] != null
          ? List<String>.from(map['preferences'] as List)
          : null,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Check if user is verified
  bool get isVerified => isEmailVerified && isActive;

  /// Check if user profile is complete
  bool get isProfileComplete =>
      displayName.isNotEmpty &&
          photoUrl.isNotEmpty &&
          phoneNumber != null &&
          phoneNumber!.isNotEmpty;

  /// Get account age in days
  int get accountAgeDays => DateTime.now().difference(createdAt).inDays;

  /// Check if account was created recently (within 30 days)
  bool get isNewAccount => accountAgeDays <= 30;

  /// Check if user has updated profile recently (within 7 days)
  bool get hasRecentUpdate => DateTime.now().difference(updatedAt).inDays <= 7;

  @override
  List<Object?> get props => [
    id,
    email,
    displayName,
    photoUrl,
    createdAt,
    updatedAt,
    phoneNumber,
    bio,
    isEmailVerified,
    isActive,
    preferences,
    metadata,
  ];

  @override
  String toString() =>
      'UserModel(id: $id, email: $email, displayName: $displayName, isVerified: $isVerified)';
}
