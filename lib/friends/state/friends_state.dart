part of 'friends_cubit.dart';

class FriendsState extends Equatable {
  const FriendsState({
    this.isLoading = false,
    this.isSearching = false,
    this.leaderboard = const [],
    this.searchResults = const [],
    this.friendIds = const {},
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.incomingRequestIds = const {},
    this.outgoingRequestIds = const {},
    this.searchQuery = '',
    this.error,
  });

  final bool isLoading;
  final bool isSearching;
  final List<FriendProfile> leaderboard;
  final List<UserProfile> searchResults;
  final Set<String> friendIds;
  final List<FriendRequest> incomingRequests;
  final List<FriendRequest> outgoingRequests;
  final Set<String> incomingRequestIds;
  final Set<String> outgoingRequestIds;
  final String searchQuery;
  final String? error;

  FriendsState copyWith({
    bool? isLoading,
    bool? isSearching,
    List<FriendProfile>? leaderboard,
    List<UserProfile>? searchResults,
    Set<String>? friendIds,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? outgoingRequests,
    Set<String>? incomingRequestIds,
    Set<String>? outgoingRequestIds,
    String? searchQuery,
    String? error,
  }) {
    return FriendsState(
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      leaderboard: leaderboard ?? this.leaderboard,
      searchResults: searchResults ?? this.searchResults,
      friendIds: friendIds ?? this.friendIds,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      incomingRequestIds: incomingRequestIds ?? this.incomingRequestIds,
      outgoingRequestIds: outgoingRequestIds ?? this.outgoingRequestIds,
      searchQuery: searchQuery ?? this.searchQuery,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSearching,
    leaderboard,
    searchResults,
    friendIds,
    incomingRequests,
    outgoingRequests,
    incomingRequestIds,
    outgoingRequestIds,
    searchQuery,
    error,
  ];
}
