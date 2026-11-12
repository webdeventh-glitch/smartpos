/// Generic container for server-side paginated and keyset-cursor query results.
class PagedResult<T> {
  final List<T> items;
  final int totalCount;
  final int currentPage;
  final int pageSize;
  final int? nextCursorId;
  final String? nextCursorSortValue;
  final bool hasMore;

  PagedResult({
    required this.items,
    required this.totalCount,
    this.currentPage = 1,
    this.pageSize = 25,
    this.nextCursorId,
    this.nextCursorSortValue,
    bool? hasMore,
  }) : hasMore = hasMore ??
            (items.isNotEmpty &&
                totalCount > 0 &&
                (((currentPage - 1) * pageSize + items.length) < totalCount));

  int get totalPages =>
      totalCount <= 0 ? 1 : (totalCount / pageSize).ceil().clamp(1, 999999);

  PagedResult<R> map<R>(R Function(T item) mapper) {
    return PagedResult<R>(
      items: items.map(mapper).toList(),
      totalCount: totalCount,
      currentPage: currentPage,
      pageSize: pageSize,
      nextCursorId: nextCursorId,
      nextCursorSortValue: nextCursorSortValue,
      hasMore: hasMore,
    );
  }
}
