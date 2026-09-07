/// What the grid card already knows about this person.
///
/// The sheet opens on top of a card that has a name and a photo on screen
/// already; making the person watch a spinner to see them again would be a
/// step backwards. The seed paints immediately and the full profile fills in
/// underneath it.
class ProfileSeed {
  const ProfileSeed({
    required this.name,
    required this.colorIndex,
    this.age,
    this.photoUrl,
    this.distanceBand,
    this.isOnline = false,
  });

  final String name;
  final int colorIndex;
  final int? age;
  final String? photoUrl;
  final String? distanceBand;
  final bool isOnline;
}