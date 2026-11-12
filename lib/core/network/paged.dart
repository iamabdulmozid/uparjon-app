/// The one page shape every paged list answers with in `data` (Mobile API
/// changes 2026-11-11 §3): `content`, `number`, `size`, `totalElements`,
/// `totalPages`, `numberOfElements`, `first`, `last`, `hasNext`, `empty`.
///
/// Lives in core because several features page through the same shape
/// (content lists, campaigns, reward history, wallet transactions).
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalElements,
    required this.isLast,
  });

  final List<T> items;
  final int page;
  final int totalPages;
  final int totalElements;
  final bool isLast;

  bool get hasMore => !isLast;

  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) => Paged(
    items: (json['content'] as List? ?? [])
        .map((e) => itemFromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    page: (json['number'] as num?)?.toInt() ?? 0,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
    isLast: switch (json['hasNext']) {
      final bool hasNext => !hasNext,
      _ => json['last'] as bool? ?? true,
    },
  );

  static Paged<T> empty<T>() => Paged<T>(
    items: const [],
    page: 0,
    totalPages: 0,
    totalElements: 0,
    isLast: true,
  );
}
