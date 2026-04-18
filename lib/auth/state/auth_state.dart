part of 'auth_cubit.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class AuthNeedsUsername extends AuthState {
  const AuthNeedsUsername({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.message,
    this.isSubmitting = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? message;
  final bool isSubmitting;

  AuthNeedsUsername copyWith({
    String? message,
    bool? isSubmitting,
  }) {
    return AuthNeedsUsername(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      message: message,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        photoUrl,
        message,
        isSubmitting,
      ];
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.profile);

  final UserProfile profile;

  @override
  List<Object?> get props => [profile];
}
