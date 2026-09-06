
import '../utils/json_parse_utils.dart';

/// Generic, reusable pagination model.
///
/// Works for ANY paginated API response that follows the common
/// `current_page / per_page / total_records / total_pages / next_page / has_more`
/// shape. Just call `Pagination.fromJson(json['pagination'])` in every
/// model that needs it — no need to redefine these fields per feature.
class Pagination {
  final int currentPage;
  final int perPage;
  final int totalRecords;
  final int totalPages;
  final int? nextPage; // nullable: API sends null when there's no next page
  final bool hasMore;

  const Pagination({
    required this.currentPage,
    required this.perPage,
    required this.totalRecords,
    required this.totalPages,
    required this.nextPage,
    required this.hasMore,
  });

  /// Safe, crash-proof parsing using SafeJsonParsing.
  /// Falls back to sane defaults (page 1, no records) if the key
  /// is missing/null/malformed instead of throwing.
  factory Pagination.fromJson(Map<String, dynamic>? json, {String? tag}) {
    final map = json ?? const <String, dynamic>{};
    return Pagination(
      currentPage: map.safeInt('current_page', fallback: 1, tag: tag),
      perPage: map.safeInt('per_page', fallback: 10, tag: tag),
      totalRecords: map.safeInt('total_records', fallback: 0, tag: tag),
      totalPages: map.safeInt('total_pages', fallback: 0, tag: tag),
      nextPage: map.safeIntNullable('next_page', tag: tag),
      hasMore: map.safeBool('has_more', fallback: false, tag: tag),
    );
  }

  Map<String, dynamic> toJson() => {
    'current_page': currentPage,
    'per_page': perPage,
    'total_records': totalRecords,
    'total_pages': totalPages,
    'next_page': nextPage,
    'has_more': hasMore,
  };

  /// Convenience for infinite-scroll / pagination controllers.
  bool get isFirstPage => currentPage <= 1;
  bool get isLastPage => !hasMore || currentPage >= totalPages;

  Pagination copyWith({
    int? currentPage,
    int? perPage,
    int? totalRecords,
    int? totalPages,
    int? nextPage,
    bool? hasMore,
  }) {
    return Pagination(
      currentPage: currentPage ?? this.currentPage,
      perPage: perPage ?? this.perPage,
      totalRecords: totalRecords ?? this.totalRecords,
      totalPages: totalPages ?? this.totalPages,
      nextPage: nextPage ?? this.nextPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  String toString() =>
      'Pagination(page: $currentPage/$totalPages, perPage: $perPage, '
          'total: $totalRecords, nextPage: $nextPage, hasMore: $hasMore)';
}