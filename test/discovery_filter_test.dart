import 'package:flutter_test/flutter_test.dart';

import 'package:dating_app/data/repositories/discovery_repository.dart';
import 'package:dating_app/presentation/home/providers/match_provider/match_provider.dart';

void main() {
  group('DiscoveryRepository.nearbyQuery', () {
    test('omits every unset filter', () {
      expect(
        DiscoveryRepository.nearbyQuery(page: 1, limit: 20),
        {'page': 1, 'limit': 20},
      );
    });

    test('joins list filters with commas', () {
      final query = DiscoveryRepository.nearbyQuery(
        genders: ['woman', 'non_binary'],
        relationshipStatus: ['single'],
        personalityTags: ['gym', 'foodie'],
        preferenceTags: ['deep_conversation'],
      );

      expect(query['genders'], 'woman,non_binary');
      expect(query['relationshipStatus'], 'single');
      expect(query['personalityTags'], 'gym,foodie');
      expect(query['preferenceTags'], 'deep_conversation');
    });

    test('drops empty lists rather than sending blanks', () {
      final query = DiscoveryRepository.nearbyQuery(
        genders: const [],
        personalityTags: const [],
      );
      expect(query.containsKey('genders'), isFalse);
      expect(query.containsKey('personalityTags'), isFalse);
    });

    test('only sends booleans when true', () {
      final off = DiscoveryRepository.nearbyQuery(
        verifiedOnly: false,
        onlineOnly: false,
        recentlyActive: false,
      );
      expect(off.containsKey('verifiedOnly'), isFalse);
      expect(off.containsKey('onlineOnly'), isFalse);
      expect(off.containsKey('recentlyActive'), isFalse);

      final on = DiscoveryRepository.nearbyQuery(recentlyActive: true);
      expect(on['recentlyActive'], true);
    });
  });

  group('DiscoveryFilter', () {
    /// nearbyCountProvider is a family keyed on this object. Without value
    /// equality every rebuild would look like a new filter set and fire another
    /// count request.
    test('two identical filters are equal and hash alike', () {
      const a = DiscoveryFilter(
        genders: ['woman'],
        personalityTags: ['gym'],
      );
      const b = DiscoveryFilter(
        genders: ['woman'],
        personalityTags: ['gym'],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing list contents are not equal', () {
      const a = DiscoveryFilter(genders: ['woman']);
      const b = DiscoveryFilter(genders: ['man']);
      expect(a, isNot(equals(b)));
    });

    test('the untouched age range is treated as no age filter', () {
      expect(const DiscoveryFilter().isFullAgeRange, isTrue);
      expect(
        const DiscoveryFilter(minAge: 25, maxAge: 40).isFullAgeRange,
        isFalse,
      );
      // The top notch means "and above", so it is still the full range.
      expect(
        const DiscoveryFilter(minAge: 18, maxAge: kAgeFilterMax).isFullAgeRange,
        isTrue,
      );
    });

    test('withoutPremium keeps the free filters and drops the rest', () {
      const filter = DiscoveryFilter(
        intent: 'casual',
        genders: ['woman'],
        minAge: 25,
        maxAge: 40,
        verifiedOnly: true,
        onlineOnly: true,
        recentlyActive: true,
        relationshipStatus: ['single'],
        personalityTags: ['gym'],
        preferenceTags: ['deep_conversation'],
      );

      final free = filter.withoutPremium();

      expect(free.intent, 'casual');
      expect(free.genders, ['woman']);
      expect(free.minAge, 25);
      expect(free.maxAge, 40);
      expect(free.usesPremiumFilters, isFalse);
    });

    test('reset clears the sheet but keeps the intent chip', () {
      const filter = DiscoveryFilter(
        intent: 'dating',
        genders: ['man'],
        verifiedOnly: true,
      );

      final reset = filter.clearedToDefaults();

      expect(reset.intent, 'dating');
      expect(reset.genders, isEmpty);
      expect(reset.verifiedOnly, isFalse);
      expect(reset.isFullAgeRange, isTrue);
    });
  });
}
