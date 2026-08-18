const belowOnePercentBucketKey = '__below_one_percent_bucket__';

class CategoryDonutBreakdown {
  CategoryDonutBreakdown(Map<String, int> data, this.total)
    : detailedEntries = (data.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))) {
    final visible = <MapEntry<String, int>>[];
    var groupedTotal = 0;
    for (final entry in detailedEntries) {
      if (isBelowOnePercent(entry)) {
        groupedTotal += entry.value;
      } else {
        visible.add(entry);
      }
    }
    chartEntries = [
      ...visible,
      if (groupedTotal > 0)
        MapEntry<String, int>(belowOnePercentBucketKey, groupedTotal),
    ];
    roundedPercentages = _roundedPercentages(detailedEntries, total);
  }

  final int total;
  final List<MapEntry<String, int>> detailedEntries;
  late final List<MapEntry<String, int>> chartEntries;
  late final List<int> roundedPercentages;

  bool isBelowOnePercent(MapEntry<String, int> entry) =>
      entry.value > 0 && entry.value * 100 < total;

  String percentageLabel(int index) {
    final entry = detailedEntries[index];
    if (isBelowOnePercent(entry)) return '<1%';
    return '${roundedPercentages[index]}%';
  }

  int chartIndexForDetailedEntry(MapEntry<String, int> entry) {
    if (isBelowOnePercent(entry)) {
      return chartEntries.indexWhere(
        (item) => item.key == belowOnePercentBucketKey,
      );
    }
    return chartEntries.indexWhere((item) => item.key == entry.key);
  }
}

List<int> _roundedPercentages(List<MapEntry<String, int>> entries, int total) {
  if (entries.isEmpty || total <= 0) return const [];
  final exact = entries.map((entry) => entry.value / total * 100).toList();
  final result = exact.map((value) => value.floor()).toList();
  final remaining = 100 - result.fold<int>(0, (sum, value) => sum + value);
  final remainderOrder = List<int>.generate(entries.length, (index) => index)
    ..sort(
      (a, b) =>
          (exact[b] - exact[b].floor()).compareTo(exact[a] - exact[a].floor()),
    );
  for (var index = 0; index < remaining; index++) {
    result[remainderOrder[index % remainderOrder.length]]++;
  }
  return result;
}
