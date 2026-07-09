/// Up to 2 uppercase initials derived from the first two words of [name].
/// Used as the avatar-circle fallback everywhere a photo isn't available
/// (waiting room, participants list, chat).
String avatarInitials(String name) {
  final initials = name.trim().split(RegExp(r'\s+')).take(2)
      .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
      .join();
  return initials.isNotEmpty ? initials : '?';
}
