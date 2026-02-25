import 'package:equatable/equatable.dart';
import 'provider_user.dart';

class ProviderState extends Equatable {
  final bool loading;
  final List<ProviderUser> users;
  final ProviderUser? selectedUser;
  final Map<DateTime, List<String>> recoveryMap;

  const ProviderState({
    this.loading = false,
    this.users = const [],
    this.selectedUser,
    this.recoveryMap = const {},
  });

  ProviderState copyWith({
    bool? loading,
    List<ProviderUser>? users,
    ProviderUser? selectedUser,
    Map<DateTime, List<String>>? recoveryMap,
  }) {
    return ProviderState(
      loading: loading ?? this.loading,
      users: users ?? this.users,
      selectedUser: selectedUser ?? this.selectedUser,
      recoveryMap: recoveryMap ?? this.recoveryMap,
    );
  }

  @override
  List<Object?> get props => [loading, users, selectedUser, recoveryMap];
}