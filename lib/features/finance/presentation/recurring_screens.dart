import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/finflow_app.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/finflow_action_icon.dart';
import '../../auth/services/auth_service.dart';
import '../models/recurring_model.dart';
import '../models/transaction_category.dart';
import '../models/wallet_model.dart';
import '../providers/recurring_provider.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';

const _pageMint = Color(0xFFF1FBF7);
const _surfaceMint = Color(0xFFE7F8F2);
const _primary = Color(0xFF006C53);
const _primaryDark = Color(0xFF00513E);
const _mint = Color(0xFF00C49A);
const _ink = Color(0xFF05201B);
const _muted = Color(0xFF52655E);
const _outline = Color(0xFFBEC9C3);
const _coral = Color(0xFFEF6262);
const _amber = Color(0xFFFFBF00);
const _darkPage = Color(0xFF081C18);
const _darkCard = Color(0xFF112622);
const _darkInput = Color(0xFF0A241F);
const _darkBorder = Color(0xFF29483F);
const _darkText = Color(0xFFF4FBF8);
const _darkSecondaryText = Color(0xFFA9C1B9);
const _darkMutedText = Color(0xFF8FA89F);
const _darkPositive = Color(0xFF38D6AC);
const _darkNegative = Color(0xFFFF6B70);
const _darkWarning = Color(0xFFFFD166);
const _headlineFont = 'Manrope';
const _bodyFont = 'Hanken Grotesk';

class RecurringControlCenterScreen extends ConsumerStatefulWidget {
  const RecurringControlCenterScreen({super.key});

  @override
  ConsumerState<RecurringControlCenterScreen> createState() =>
      _RecurringControlCenterScreenState();
}

class _RecurringControlCenterScreenState
    extends ConsumerState<RecurringControlCenterScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  bool _showDatePopover = false;
  _HubFilter _filter = _HubFilter.all;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    Future.microtask(() async {
      await Future.wait([
        ref.read(recurringServiceProvider).fetch(),
        WalletService.instance.fetchWallets(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(recurringServiceRevisionProvider);
    final service = ref.read(recurringServiceProvider);
    final schedules = [...service.schedules]
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
    final filteredSchedules = schedules
        .where((schedule) => _matchesHubFilter(schedule, _filter))
        .toList(growable: false);
    final upcomingSchedules = _filter == _HubFilter.paused
        ? filteredSchedules
        : filteredSchedules
              .where((schedule) => schedule.isActive)
              .toList(growable: false);
    final occurrences = _calendarOccurrencesForMonth(
      filteredSchedules,
      _visibleMonth,
    );
    final popoverOverflow = _showDatePopover
        ? _calendarPopoverOverflow(_visibleMonth, _selectedDate)
        : 0.0;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? _darkPage : _pageMint,
      appBar: _RecurringAppBar(
        context: context,
        dark: dark,
        title: AppStrings.choose('Recurring', 'Định kỳ'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  key: const Key('recurring-filter-button'),
                  tooltip: AppStrings.choose('Filter', 'Bộ lọc'),
                  onPressed: _showFilterDialog,
                  icon: const Icon(Icons.filter_list_rounded, size: 24),
                ),
                if (_filter != _HubFilter.all)
                  const Positioned(
                    right: 4,
                    top: 4,
                    child: CircleAvatar(
                      key: Key('recurring-filter-badge'),
                      radius: 8,
                      backgroundColor: _coral,
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'refresh') service.fetch();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'refresh',
                  child: Text(AppStrings.choose('Refresh', 'Làm mới')),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('recurring-add-fab'),
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRoutes.recurringNew),
        tooltip: AppStrings.choose('Add recurring', 'Thêm lịch định kỳ'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 26),
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: service.fetch,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
          children: [
            _UpcomingCarousel(
              schedules: upcomingSchedules,
              onOpenSchedule: (schedule) => Navigator.of(
                context,
              ).pushNamed(AppRoutes.recurringDetails, arguments: schedule.id),
              onAddSchedule: () =>
                  Navigator.of(context).pushNamed(AppRoutes.recurringNew),
            ),
            const SizedBox(height: 16),
            _MonthlyHubCalendar(
              visibleMonth: _visibleMonth,
              selectedDate: _selectedDate,
              occurrences: occurrences,
              showPopover: _showDatePopover,
              onPreviousMonth: () => _moveMonth(-1, filteredSchedules),
              onNextMonth: () => _moveMonth(1, filteredSchedules),
              onDateSelected: (date, hasTransactions) => setState(() {
                final sameSelected = _sameCalendarDay(_selectedDate, date);
                _selectedDate = date;
                _showDatePopover = hasTransactions
                    ? (sameSelected ? !_showDatePopover : true)
                    : false;
              }),
              onOpenSchedule: (schedule) => Navigator.of(
                context,
              ).pushNamed(AppRoutes.recurringDetails, arguments: schedule.id),
            ),
            SizedBox(height: 18 + popoverOverflow),
            _MonthlyOccurrenceList(
              occurrences: occurrences,
              selectedDate: _selectedDate,
            ),
          ],
        ),
      ),
    );
  }

  void _moveMonth(int offset, List<RecurringSchedule> schedules) {
    final nextMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + offset,
    );
    final occurrences = _calendarOccurrencesForMonth(schedules, nextMonth);
    final now = DateTime.now();
    final isCurrentMonth =
        nextMonth.year == now.year && nextMonth.month == now.month;
    setState(() {
      _visibleMonth = nextMonth;
      _selectedDate = isCurrentMonth
          ? DateTime(now.year, now.month, now.day)
          : occurrences.isNotEmpty
          ? occurrences.first.date
          : nextMonth;
      _showDatePopover = false;
    });
  }

  Future<void> _showFilterDialog() async {
    final selected = await showDialog<_HubFilter>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .42),
      builder: (context) => _HubFilterDialog(selected: _filter),
    );
    if (selected != null && mounted) {
      setState(() {
        _filter = selected;
        _showDatePopover = false;
      });
    }
  }
}

double _calendarPopoverOverflow(DateTime month, DateTime selectedDate) {
  if (selectedDate.year != month.year || selectedDate.month != month.month) {
    return 0;
  }
  final first = DateTime(month.year, month.month);
  final dayCount = DateTime(month.year, month.month + 1, 0).day;
  final rows = ((first.weekday - 1 + dayCount) / 7).ceil();
  final row = (first.weekday - 1 + selectedDate.day - 1) ~/ 7;
  // Keep the popover above dates in the last three calendar rows. This gives
  // mid-to-late month dates (for example Aug 17-19) the same placement as the
  // final rows and prevents the card from covering the dates below it.
  final opensBelow = row < rows - 3;
  if (!opensBelow) return 0;

  const cellHeight = 40.0;
  const popoverHeight = 174.0;
  const calendarBottomPadding = 12.0;
  final popoverBottom = (row + 1) * cellHeight - 2 + popoverHeight;
  final gridBottom = rows * cellHeight + calendarBottomPadding;
  return math.max(0, popoverBottom - gridBottom + 8);
}

enum _HubFilter { all, income, expense, automatic, review, active, paused }

class _CalendarOccurrence {
  const _CalendarOccurrence({required this.schedule, required this.date});

  final RecurringSchedule schedule;
  final DateTime date;
}

bool _matchesHubFilter(RecurringSchedule schedule, _HubFilter filter) =>
    switch (filter) {
      _HubFilter.all => true,
      _HubFilter.income => schedule.amount > 0,
      _HubFilter.expense => schedule.amount < 0,
      _HubFilter.automatic =>
        schedule.postingMode == RecurringPostingMode.automatic,
      _HubFilter.review => schedule.postingMode == RecurringPostingMode.review,
      _HubFilter.active => schedule.isActive,
      _HubFilter.paused => !schedule.isActive,
    };

List<_CalendarOccurrence> _calendarOccurrencesForMonth(
  List<RecurringSchedule> schedules,
  DateTime month,
) {
  final result = <_CalendarOccurrence>[];
  for (final schedule in schedules) {
    for (final date in schedule.occurrencesInMonth(month)) {
      result.add(_CalendarOccurrence(schedule: schedule, date: date));
    }
  }
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

class _UpcomingCarousel extends StatelessWidget {
  const _UpcomingCarousel({
    required this.schedules,
    required this.onOpenSchedule,
    required this.onAddSchedule,
  });

  final List<RecurringSchedule> schedules;
  final ValueChanged<RecurringSchedule> onOpenSchedule;
  final VoidCallback onAddSchedule;

  @override
  Widget build(BuildContext context) {
    final upcoming = [...schedules]
      ..sort(
        (a, b) => a
            .nextOccurrenceOnOrAfter(DateTime.now())
            .compareTo(b.nextOccurrenceOnOrAfter(DateTime.now())),
      );
    return Column(
      key: const Key('recurring-upcoming-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  AppStrings.choose('Upcoming', 'Sắp tới'),
                  style: _headline(context, 18),
                ),
              ),
              Text(
                AppStrings.choose(
                  '${upcoming.length} scheduled',
                  '${upcoming.length} lịch',
                ),
                style: _body(context, 12, muted: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          _UpcomingEmptyCard(onAddSchedule: onAddSchedule)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = upcoming.length == 1
                  ? constraints.maxWidth
                  : math.min(260.0, constraints.maxWidth * .74);
              return SizedBox(
                key: const Key('recurring-upcoming-carousel'),
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: upcoming.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final schedule = upcoming[index];
                    return SizedBox(
                      width: cardWidth,
                      child: _UpcomingScheduleCard(
                        schedule: schedule,
                        onTap: () => onOpenSchedule(schedule),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _UpcomingScheduleCard extends StatelessWidget {
  const _UpcomingScheduleCard({required this.schedule, required this.onTap});

  final RecurringSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = TransactionCategory.resolve(schedule.category);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final positive = dark ? _darkPositive : _primary;
    final expense = schedule.amount < 0;
    final review = schedule.postingMode == RecurringPostingMode.review;
    final accent = expense ? (dark ? _darkNegative : _coral) : positive;
    return Material(
      key: Key('recurring-upcoming-${schedule.id}'),
      color: dark ? _darkCard : Colors.white,
      elevation: dark ? 0 : 4,
      shadowColor: _primary.withValues(alpha: .22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? _darkBorder : const Color(0xFFD5E9E1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    key: Key('recurring-upcoming-icon-${schedule.id}'),
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: category.buildIcon(size: 20, color: category.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                schedule.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _headline(context, 16),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _signedMoney(schedule.amount),
                                  maxLines: 1,
                                  style: _headline(
                                    context,
                                    14,
                                  ).copyWith(color: accent),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppStrings.categoryName(schedule.category)} · ${_frequencyLabel(schedule.frequency)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _body(context, 13, muted: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _hubDueLabel(
                        schedule.nextOccurrenceOnOrAfter(DateTime.now()),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _body(context, 13, muted: true),
                    ),
                  ),
                  _UpcomingStatusChip(schedule: schedule, review: review),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingStatusChip extends StatelessWidget {
  const _UpcomingStatusChip({required this.schedule, required this.review});

  final RecurringSchedule schedule;
  final bool review;

  @override
  Widget build(BuildContext context) {
    final color = review ? _coral : _primary;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        review
            ? AppStrings.choose('Needs review', 'Cần duyệt')
            : AppStrings.choose('Auto-post', 'Tự động ghi'),
        style: _body(
          context,
          11,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
    if (!review || !schedule.isActive) return chip;
    return InkWell(
      onTap: () => ReviewOccurrenceSheet.show(context, schedule),
      borderRadius: BorderRadius.circular(6),
      child: chip,
    );
  }
}

class _UpcomingEmptyCard extends StatelessWidget {
  const _UpcomingEmptyCard({required this.onAddSchedule});

  final VoidCallback onAddSchedule;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: _hubElevatedCardDecoration(context, radius: 18),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 19,
          backgroundColor: _surfaceMint,
          child: Icon(Icons.event_repeat_rounded, color: _primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            AppStrings.choose('No upcoming payments', 'Chưa có khoản sắp tới'),
            style: _body(context, 13).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          onPressed: onAddSchedule,
          child: Text(AppStrings.choose('Create', 'Tạo lịch')),
        ),
      ],
    ),
  );
}

class _MonthlyHubCalendar extends StatelessWidget {
  const _MonthlyHubCalendar({
    required this.visibleMonth,
    required this.selectedDate,
    required this.occurrences,
    required this.showPopover,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDateSelected,
    required this.onOpenSchedule,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<_CalendarOccurrence> occurrences;
  final bool showPopover;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final void Function(DateTime date, bool hasTransactions) onDateSelected;
  final ValueChanged<RecurringSchedule> onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(visibleMonth.year, visibleMonth.month);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final dayCount = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final rows = ((first.weekday - 1 + dayCount) / 7).ceil();
    final days = List.generate(
      rows * 7,
      (index) => gridStart.add(Duration(days: index)),
    );
    final byDay = <String, List<_CalendarOccurrence>>{};
    for (final occurrence in occurrences) {
      byDay
          .putIfAbsent(_calendarKey(occurrence.date), () => [])
          .add(occurrence);
    }
    final selectedItems = byDay[_calendarKey(selectedDate)] ?? const [];

    return Container(
      key: const Key('recurring-calendar-card'),
      decoration: _hubElevatedCardDecoration(context, radius: 24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            key: const Key('recurring-calendar-header'),
            height: 58,
            color: _primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  key: const Key('recurring-previous-month'),
                  onPressed: onPreviousMonth,
                  tooltip: AppStrings.choose('Previous month', 'Tháng trước'),
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: Text(
                    _monthYearLabel(visibleMonth),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _headlineFont,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('recurring-next-month'),
                  onPressed: onNextMonth,
                  tooltip: AppStrings.choose('Next month', 'Tháng sau'),
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              children: [
                const _MonthlyWeekdayHeader(),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const cellHeight = 40.0;
                    final gridHeight = rows * cellHeight;
                    final selectedIndex = days.indexWhere(
                      (date) => _sameCalendarDay(date, selectedDate),
                    );
                    return SizedBox(
                      height: gridHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GridView.builder(
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisExtent: cellHeight,
                                ),
                            itemCount: days.length,
                            itemBuilder: (context, index) {
                              final date = days[index];
                              final items =
                                  byDay[_calendarKey(date)] ?? const [];
                              final transactionColor = items.isEmpty
                                  ? null
                                  : TransactionCategory.resolve(
                                      items.first.schedule.category,
                                    ).color;
                              return _MonthlyDateCell(
                                date: date,
                                inVisibleMonth:
                                    date.month == visibleMonth.month &&
                                    date.year == visibleMonth.year,
                                selected: _sameCalendarDay(date, selectedDate),
                                hasTransactions: items.isNotEmpty,
                                transactionColor: transactionColor,
                                transactionCount: items.length,
                                onTap: () =>
                                    onDateSelected(date, items.isNotEmpty),
                              );
                            },
                          ),
                          if (showPopover &&
                              selectedItems.isNotEmpty &&
                              selectedIndex >= 0)
                            _positionedPopover(
                              context,
                              constraints.maxWidth,
                              rows,
                              selectedIndex,
                              selectedItems,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionedPopover(
    BuildContext context,
    double width,
    int rows,
    int selectedIndex,
    List<_CalendarOccurrence> items,
  ) {
    const cellHeight = 40.0;
    const popoverHeight = 174.0;
    final cellWidth = width / 7;
    final column = selectedIndex % 7;
    final row = selectedIndex ~/ 7;
    final popoverWidth = math.min(180.0, width * .62);
    final preferredLeft = (column + .5) * cellWidth - popoverWidth / 2;
    final left = preferredLeft.clamp(0.0, width - popoverWidth);
    final opensBelow = row < rows - 3;
    final top = opensBelow
        ? (row + 1) * cellHeight - 2
        : row * cellHeight - popoverHeight + 3;
    final anchorX = ((column + .5) * cellWidth - left).clamp(
      16.0,
      popoverWidth - 16,
    );
    return Positioned(
      left: left,
      top: top,
      width: popoverWidth,
      height: popoverHeight,
      child: _CalendarPopover(
        items: items,
        pointerX: anchorX,
        pointerOnTop: opensBelow,
        onTap: () => onOpenSchedule(items.first.schedule),
      ),
    );
  }
}

class _MonthlyWeekdayHeader extends StatelessWidget {
  const _MonthlyWeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const en = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const vi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final labels = AppLanguage.instance.locale == AppLocale.english ? en : vi;
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: _body(
                context,
                11,
                muted: true,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .15),
            ),
          ),
      ],
    );
  }
}

class _MonthlyDateCell extends StatelessWidget {
  const _MonthlyDateCell({
    required this.date,
    required this.inVisibleMonth,
    required this.selected,
    required this.hasTransactions,
    required this.transactionColor,
    required this.transactionCount,
    required this.onTap,
  });

  final DateTime date;
  final bool inVisibleMonth;
  final bool selected;
  final bool hasTransactions;
  final Color? transactionColor;
  final int transactionCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = _sameCalendarDay(now, date);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = dark ? _darkPositive : _primary;
    final circleColor = hasTransactions
        ? transactionColor ?? _primary
        : selected
        ? (dark ? const Color(0xFF174B3F) : _surfaceMint)
        : Colors.transparent;
    final textColor = hasTransactions
        ? Colors.white
        : selected
        ? selectedColor
        : today
        ? (dark ? const Color(0xFFFF8A8E) : _coral)
        : inVisibleMonth
        ? (dark ? const Color(0xFFF4FBF8) : _ink)
        : _muted.withValues(alpha: .3);
    return InkResponse(
      key: Key('recurring-date-${_calendarKey(date)}'),
      onTap: onTap,
      radius: 20,
      child: Center(
        child: SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (today)
                Container(
                  key: Key('recurring-date-today-ring-${_calendarKey(date)}'),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _coral.withValues(alpha: dark ? .14 : .09),
                    shape: BoxShape.circle,
                    border: Border.all(color: _coral, width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: _coral.withValues(alpha: .22),
                        blurRadius: 7,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              if (selected)
                Container(
                  key: Key(
                    'recurring-date-selected-ring-${_calendarKey(date)}',
                  ),
                  width: today ? 33 : 38,
                  height: today ? 33 : 38,
                  decoration: BoxDecoration(
                    color: selectedColor.withValues(alpha: dark ? .16 : .10),
                    shape: BoxShape.circle,
                    border: Border.all(color: selectedColor, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: selectedColor.withValues(alpha: .22),
                        blurRadius: 7,
                        spreadRadius: .5,
                      ),
                    ],
                  ),
                ),
              Container(
                key: Key('recurring-date-marker-${_calendarKey(date)}'),
                width: selected || today ? 28 : 32,
                height: selected || today ? 28 : 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasTransactions && (selected || today)
                        ? Colors.white.withValues(alpha: .9)
                        : Colors.transparent,
                    width: hasTransactions && (selected || today) ? 1.4 : 0,
                  ),
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: 14,
                    fontWeight: selected || today
                        ? FontWeight.w800
                        : FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              if (transactionCount > 1)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _coral,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$transactionCount',
                      style: const TextStyle(
                        fontFamily: _bodyFont,
                        fontSize: 6.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarPopover extends StatelessWidget {
  const _CalendarPopover({
    required this.items,
    required this.pointerX,
    required this.pointerOnTop,
    required this.onTap,
  });

  final List<_CalendarOccurrence> items;
  final double pointerX;
  final bool pointerOnTop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = items.first;
    final schedule = item.schedule;
    final category = TransactionCategory.resolve(schedule.category);
    final review = schedule.postingMode == RecurringPostingMode.review;
    final amountColor = schedule.amount < 0 ? _coral : _primary;
    return Stack(
      key: const Key('recurring-date-popover'),
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: pointerOnTop ? 5 : 0,
          bottom: pointerOnTop ? 0 : 5,
          child: Material(
            key: const Key('recurring-popover-surface'),
            color: Theme.of(context).brightness == Brightness.dark
                ? _darkCard
                : _surfaceMint,
            elevation: 10,
            shadowColor: _primary.withValues(alpha: .24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: Theme.of(context).brightness == Brightness.dark
                  ? const BorderSide(color: _darkBorder)
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: category.color.withValues(alpha: .12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: category.buildIcon(
                            size: 13,
                            color: category.color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            schedule.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _headline(context, 15),
                          ),
                        ),
                        if (items.length > 1)
                          Text(
                            '+${items.length - 1}',
                            style: _body(context, 8).copyWith(
                              color: _primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _signedMoney(schedule.amount),
                      maxLines: 1,
                      style: _headline(
                        context,
                        17,
                      ).copyWith(color: amountColor),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${AppStrings.categoryName(schedule.category)} · ${_frequencyLabel(schedule.frequency)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _body(context, 13, muted: true),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        _MiniPopoverChip(
                          label: _hubDueLabel(item.date),
                          color: _primary,
                        ),
                        _MiniPopoverChip(
                          label: review
                              ? AppStrings.choose(
                                  'Confirmation required',
                                  'Cần xác nhận',
                                )
                              : AppStrings.choose('Auto-post', 'Tự động ghi'),
                          color: review ? _coral : _primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          key: const Key('recurring-popover-pointer'),
          left: pointerX - 7,
          top: pointerOnTop ? 0 : null,
          bottom: pointerOnTop ? null : 0,
          child: CustomPaint(
            size: const Size(14, 9),
            painter: _PopoverPointerPainter(
              pointsUp: pointerOnTop,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? _darkCard
                  : _surfaceMint,
            ),
          ),
        ),
      ],
    );
  }
}

class _PopoverPointerPainter extends CustomPainter {
  const _PopoverPointerPainter({
    required this.pointsUp,
    required this.fillColor,
  });

  final bool pointsUp;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fillColor);
  }

  @override
  bool shouldRepaint(covariant _PopoverPointerPainter oldDelegate) =>
      pointsUp != oldDelegate.pointsUp || fillColor != oldDelegate.fillColor;
}

class _MiniPopoverChip extends StatelessWidget {
  const _MiniPopoverChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: _body(
        context,
        10,
      ).copyWith(color: color, fontWeight: FontWeight.w800),
    ),
  );
}

class _MonthlyOccurrenceList extends StatelessWidget {
  const _MonthlyOccurrenceList({
    required this.occurrences,
    required this.selectedDate,
  });

  final List<_CalendarOccurrence> occurrences;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final selected = occurrences
        .where((item) => _sameCalendarDay(item.date, selectedDate))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HubSectionLabel(label: _hubDateGroupLabel(selectedDate)),
        const SizedBox(height: 8),
        if (selected.isEmpty)
          _HubInlineEmpty(
            message: AppStrings.choose(
              'No recurring transactions on this date.',
              'Không có giao dịch định kỳ trong ngày này.',
            ),
          )
        else
          for (var index = 0; index < selected.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _HubScheduleCard(
              schedule: selected[index].schedule,
              showReviewAction: _sameCalendarDay(
                selected[index].date,
                selected[index].schedule.nextOccurrenceOnOrAfter(
                  DateTime.now(),
                ),
              ),
              showChevron: false,
              occurrenceLabel: _hubDueLabel(selected[index].date),
            ),
          ],
      ],
    );
  }
}

class _HubFilterDialog extends StatefulWidget {
  const _HubFilterDialog({required this.selected});
  final _HubFilter selected;

  @override
  State<_HubFilterDialog> createState() => _HubFilterDialogState();
}

class _HubFilterDialogState extends State<_HubFilterDialog> {
  late _HubFilter _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    final items = <(_HubFilter, String, IconData)>[
      (_HubFilter.all, AppStrings.choose('All', 'Tất cả'), Icons.apps_rounded),
      (
        _HubFilter.income,
        AppStrings.choose('Income', 'Thu nhập'),
        Icons.south_west_rounded,
      ),
      (
        _HubFilter.expense,
        AppStrings.choose('Expenses', 'Chi tiêu'),
        Icons.north_east_rounded,
      ),
      (
        _HubFilter.review,
        AppStrings.choose('Confirmation required', 'Cần xác nhận'),
        Icons.fact_check_outlined,
      ),
      (
        _HubFilter.automatic,
        AppStrings.choose('Auto-post', 'Tự động ghi'),
        Icons.sync_rounded,
      ),
      (
        _HubFilter.active,
        AppStrings.choose('Active', 'Đang hoạt động'),
        Icons.play_circle_outline_rounded,
      ),
      (
        _HubFilter.paused,
        AppStrings.choose('Paused', 'Đã tạm dừng'),
        Icons.pause_circle_outline_rounded,
      ),
    ];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      key: const Key('recurring-filter-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      elevation: 18,
      shadowColor: _primary.withValues(alpha: .18),
      backgroundColor: dark ? _darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: MediaQuery.sizeOf(context).height - 48,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: _surfaceMint,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.filter_list_rounded,
                        color: _primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        AppStrings.choose(
                          'Filter schedules',
                          'Lọc lịch định kỳ',
                        ),
                        style: _headline(context, 18),
                      ),
                    ),
                    IconButton(
                      key: const Key('recurring-filter-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: _muted,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: Text(
                  AppStrings.choose(
                    'Choose one view for upcoming schedules and the calendar.',
                    'Chọn một chế độ hiển thị cho lịch sắp tới và lịch tháng.',
                  ),
                  style: _body(context, 12, muted: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 54,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = _selected == item.$1;
                    return _HubFilterOption(
                      filter: item.$1,
                      label: item.$2,
                      icon: item.$3,
                      selected: selected,
                      onTap: () => setState(() => _selected = item.$1),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: dark
                          ? _darkBorder
                          : _outline.withValues(alpha: .3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      key: const Key('recurring-filter-reset'),
                      onPressed: () =>
                          setState(() => _selected = _HubFilter.all),
                      child: Text(AppStrings.choose('Reset', 'Đặt lại')),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('recurring-filter-apply'),
                      onPressed: () => Navigator.of(context).pop(_selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(AppStrings.choose('Apply', 'Áp dụng')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubFilterOption extends StatelessWidget {
  const _HubFilterOption({
    required this.filter,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final _HubFilter filter;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: Key('recurring-filter-${filter.name}'),
    color: selected ? _surfaceMint : Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? _primary : _outline.withValues(alpha: .48),
        width: selected ? 1.4 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Row(
          children: [
            Icon(icon, color: selected ? _primary : _muted, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(context, 12).copyWith(
                  color: selected
                      ? (Theme.of(context).brightness == Brightness.dark
                            ? _mint
                            : _primaryDark)
                      : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : _ink),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, color: _primary, size: 17),
          ],
        ),
      ),
    ),
  );
}

String _calendarKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

String _monthYearLabel(DateTime date) {
  const monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return AppStrings.choose(
    '${monthsEn[date.month - 1]} ${date.year}',
    'Tháng ${date.month}, ${date.year}',
  );
}

// Kept temporarily for compatibility with older golden references.
// ignore: unused_element
class _HubSegment extends StatelessWidget {
  const _HubSegment({required this.upcomingSelected, required this.onChanged});

  final bool upcomingSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? _darkInput : const Color(0xFFDDF5ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _item(
            context,
            label: AppStrings.choose('Upcoming', 'Sắp tới'),
            value: true,
          ),
          _item(
            context,
            label: AppStrings.choose('All schedules', 'Tất cả lịch'),
            value: false,
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required String label,
    required bool value,
  }) {
    final selected = upcomingSelected == value;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? (dark ? _darkCard : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected && !dark
                ? const [
                    BoxShadow(
                      color: Color(0x14006C53),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: _body(context, 12).copyWith(
              color: selected ? _primary : _muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _HubSummary extends StatelessWidget {
  const _HubSummary({required this.schedules});

  final List<RecurringSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    final total = schedules.fold<int>(
      0,
      (sum, schedule) => sum + schedule.amount.abs(),
    );
    final reviewCount = schedules
        .where((item) => item.postingMode == RecurringPostingMode.review)
        .length;
    final next = schedules.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconBubble(
                icon: Icons.calendar_month_rounded,
                color: _primary,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.choose(
                        'Upcoming in 30 days',
                        'Sắp tới trong 30 ngày',
                      ),
                      style: _headline(context, 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.choose(
                        '${schedules.length} scheduled payments',
                        '${schedules.length} khoản thanh toán',
                      ),
                      style: _body(context, 12, muted: true),
                    ),
                  ],
                ),
              ),
              if (reviewCount > 0)
                _HubStatusChip(
                  label: AppStrings.choose(
                    '$reviewCount needs review',
                    '$reviewCount cần duyệt',
                  ),
                  color: _coral,
                  icon: Icons.error_outline_rounded,
                ),
            ],
          ),
          const SizedBox(height: 13),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: _money(total), style: _headline(context, 23)),
                  TextSpan(
                    text: AppStrings.choose(' total', ' tổng cộng'),
                    style: _body(context, 12, muted: true),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 13),
          Divider(height: 1, color: _outline.withValues(alpha: .35)),
          const SizedBox(height: 11),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: AppStrings.choose('Next: ', 'Gần nhất: '),
                  style: _body(context, 12, muted: true),
                ),
                TextSpan(
                  text: '${next.name} · ${_hubDueLabel(next.nextOccurrence)}',
                  style: _body(
                    context,
                    12,
                  ).copyWith(color: _primaryDark, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _HubWeekCalendar extends StatelessWidget {
  const _HubWeekCalendar({
    required this.schedules,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onFullCalendar,
  });

  final List<RecurringSchedule> schedules;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onFullCalendar;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final dates = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    final activeDate = selectedDate ?? today;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: _cardDecoration(context, radius: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.choose('This week', 'Tuần này'),
                  style: _headline(context, 16),
                ),
              ),
              TextButton(
                onPressed: onFullCalendar,
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  AppStrings.choose('Full calendar', 'Xem lịch'),
                  style: _body(
                    context,
                    11,
                  ).copyWith(color: _primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final date in dates)
                Expanded(
                  child: _HubCalendarDay(
                    date: date,
                    selected: _sameCalendarDay(date, activeDate),
                    hasIncome: schedules.any(
                      (item) =>
                          item.amount > 0 &&
                          _sameCalendarDay(item.nextOccurrence, date),
                    ),
                    hasExpense: schedules.any(
                      (item) =>
                          item.amount < 0 &&
                          _sameCalendarDay(item.nextOccurrence, date),
                    ),
                    onTap: () => onDateSelected(date),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubCalendarDay extends StatelessWidget {
  const _HubCalendarDay({
    required this.date,
    required this.selected,
    required this.hasIncome,
    required this.hasExpense,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool hasIncome;
  final bool hasExpense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const weekdaysEn = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const weekdaysVi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final weekday = AppStrings.choose(
      weekdaysEn[date.weekday - 1],
      weekdaysVi[date.weekday - 1],
    );
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          children: [
            Text(
              weekday,
              style: _body(context, 9).copyWith(
                color: selected ? _primary : _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 31,
              height: 31,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${date.day}',
                style: _body(context, 12).copyWith(
                  color: selected ? Colors.white : _ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasIncome) const _HubDot(color: _mint),
                  if (hasIncome && hasExpense) const SizedBox(width: 3),
                  if (hasExpense) const _HubDot(color: _coral),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubDot extends StatelessWidget {
  const _HubDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ignore: unused_element
class _HubUpcomingList extends StatelessWidget {
  const _HubUpcomingList({
    required this.schedules,
    // ignore: unused_element_parameter
    this.selectedDate,
  });

  final List<RecurringSchedule> schedules;
  final DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    final visible = selectedDate == null
        ? schedules
        : schedules
              .where(
                (item) => _sameCalendarDay(item.nextOccurrence, selectedDate!),
              )
              .toList(growable: false);
    if (visible.isEmpty) {
      return _HubInlineEmpty(
        message: AppStrings.choose(
          'No scheduled payments on this day.',
          'Không có khoản định kỳ trong ngày này.',
        ),
      );
    }

    final children = <Widget>[];
    DateTime? previous;
    for (final schedule in visible) {
      if (previous == null ||
          !_sameCalendarDay(previous, schedule.nextOccurrence)) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 18));
        children.add(
          _HubSectionLabel(label: _hubDateGroupLabel(schedule.nextOccurrence)),
        );
        children.add(const SizedBox(height: 8));
        previous = schedule.nextOccurrence;
      } else {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        _HubScheduleCard(
          schedule: schedule,
          showReviewAction: true,
          showChevron: false,
          occurrenceLabel: _hubDueLabel(schedule.nextOccurrence),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

// ignore: unused_element
class _HubFilters extends StatelessWidget {
  const _HubFilters({required this.selected, required this.onChanged});

  final _HubFilter selected;
  final ValueChanged<_HubFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <(_HubFilter, String)>[
      (_HubFilter.all, AppStrings.choose('All', 'Tất cả')),
      (_HubFilter.income, AppStrings.choose('Income', 'Thu nhập')),
      (_HubFilter.expense, AppStrings.choose('Expenses', 'Chi tiêu')),
      (_HubFilter.automatic, AppStrings.choose('Auto-post', 'Tự động')),
      (_HubFilter.review, AppStrings.choose('Needs review', 'Cần duyệt')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            ChoiceChip(
              label: Text(items[index].$2),
              selected: selected == items[index].$1,
              onSelected: (_) => onChanged(items[index].$1),
              showCheckmark: false,
              selectedColor: _primary,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? _darkCard
                  : Colors.white,
              side: BorderSide(
                color: selected == items[index].$1
                    ? _primary
                    : _outline.withValues(alpha: .55),
              ),
              labelStyle: _body(context, 11).copyWith(
                color: selected == items[index].$1 ? Colors.white : _muted,
                fontWeight: FontWeight.w700,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

// ignore: unused_element
class _HubAllSchedules extends StatelessWidget {
  const _HubAllSchedules({required this.schedules, required this.filter});

  final List<RecurringSchedule> schedules;
  final _HubFilter filter;

  @override
  Widget build(BuildContext context) {
    final visible = schedules
        .where((schedule) {
          return switch (filter) {
            _HubFilter.all => true,
            _HubFilter.income => schedule.amount > 0,
            _HubFilter.expense => schedule.amount < 0,
            _HubFilter.automatic =>
              schedule.postingMode == RecurringPostingMode.automatic,
            _HubFilter.review =>
              schedule.postingMode == RecurringPostingMode.review,
            _HubFilter.active => schedule.isActive,
            _HubFilter.paused => !schedule.isActive,
          };
        })
        .toList(growable: false);

    if (visible.isEmpty) {
      return _HubInlineEmpty(
        message: AppStrings.choose(
          'No schedules match this filter.',
          'Không có lịch phù hợp với bộ lọc.',
        ),
      );
    }

    final income = visible.where((item) => item.amount > 0).toList();
    final expenses = visible.where((item) => item.amount <= 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (income.isNotEmpty) ...[
          _HubGroupTitle(
            title: AppStrings.choose('Income', 'Thu nhập'),
            count: income.length,
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < income.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _HubScheduleCard(
              schedule: income[index],
              showReviewAction: false,
              showChevron: true,
              occurrenceLabel: AppStrings.choose(
                'Next: ${_hubDueLabel(income[index].nextOccurrence)}',
                'Tiếp theo: ${_hubDueLabel(income[index].nextOccurrence)}',
              ),
            ),
          ],
        ],
        if (income.isNotEmpty && expenses.isNotEmpty)
          const SizedBox(height: 22),
        if (expenses.isNotEmpty) ...[
          _HubGroupTitle(
            title: AppStrings.choose(
              'Bills & subscriptions',
              'Hóa đơn & đăng ký',
            ),
            count: expenses.length,
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < expenses.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _HubScheduleCard(
              schedule: expenses[index],
              showReviewAction: false,
              showChevron: true,
              occurrenceLabel: AppStrings.choose(
                'Next: ${_hubDueLabel(expenses[index].nextOccurrence)}',
                'Tiếp theo: ${_hubDueLabel(expenses[index].nextOccurrence)}',
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _HubScheduleCard extends StatelessWidget {
  const _HubScheduleCard({
    required this.schedule,
    required this.showReviewAction,
    required this.showChevron,
    required this.occurrenceLabel,
  });

  final RecurringSchedule schedule;
  final bool showReviewAction;
  final bool showChevron;
  final String occurrenceLabel;

  @override
  Widget build(BuildContext context) {
    final category = TransactionCategory.resolve(schedule.category);
    final review = schedule.postingMode == RecurringPostingMode.review;
    final amountColor = schedule.amount > 0 ? _primary : _coral;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      key: Key('recurring-occurrence-card-${schedule.id}'),
      color: dark ? _darkCard : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dark ? _darkBorder : _surfaceMint),
      ),
      elevation: dark ? 0 : 1,
      shadowColor: _primary.withValues(alpha: .08),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).pushNamed(AppRoutes.recurringDetails, arguments: schedule.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: category.buildIcon(size: 20, color: category.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _headline(context, 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppStrings.categoryName(schedule.category)} · ${_frequencyLabel(schedule.frequency)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _body(context, 14, muted: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 132),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _signedMoney(schedule.amount),
                              maxLines: 1,
                              style: _headline(
                                context,
                                16,
                              ).copyWith(color: amountColor),
                            ),
                          ),
                        ),
                        if (showChevron) ...[
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: _muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (showReviewAction && review && schedule.isActive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: FilledButton(
                    onPressed: () =>
                        ReviewOccurrenceSheet.show(context, schedule),
                    style: FilledButton.styleFrom(
                      backgroundColor: _coral,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      AppStrings.choose('Review', 'Duyệt'),
                      style: _body(context, 13).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ] else if (!review) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _HubStatusChip(
                    label: AppStrings.choose('Auto-post', 'Tự động ghi'),
                    color: _primary,
                    icon: Icons.sync_rounded,
                  ),
                ),
              ] else if (occurrenceLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    occurrenceLabel,
                    style: _body(context, 11, muted: true),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HubStatusChip extends StatelessWidget {
  const _HubStatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _body(
              context,
              9,
            ).copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _HubGroupTitle extends StatelessWidget {
  const _HubGroupTitle({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(title, style: _headline(context, 14)),
      const SizedBox(width: 7),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          '$count',
          style: _body(
            context,
            10,
          ).copyWith(color: _primary, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _HubSectionLabel extends StatelessWidget {
  const _HubSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: _body(
      context,
      10,
    ).copyWith(color: _muted, fontWeight: FontWeight.w800, letterSpacing: .6),
  );
}

class _HubInlineEmpty extends StatelessWidget {
  const _HubInlineEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
    decoration: _cardDecoration(context, radius: 16),
    child: Column(
      children: [
        const Icon(Icons.event_busy_rounded, color: _muted, size: 28),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: _body(context, 12, muted: true),
        ),
      ],
    ),
  );
}

// ignore: unused_element
class _HubEmpty extends StatelessWidget {
  const _HubEmpty({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
    decoration: _cardDecoration(context, radius: 18),
    child: Column(
      children: [
        const _IconBubble(
          icon: Icons.event_repeat_rounded,
          color: _primary,
          size: 56,
          iconSize: 27,
        ),
        const SizedBox(height: 14),
        Text(
          AppStrings.choose(
            'No recurring schedules yet',
            'Chưa có lịch định kỳ',
          ),
          textAlign: TextAlign.center,
          style: _headline(context, 18),
        ),
        const SizedBox(height: 7),
        Text(
          AppStrings.choose(
            'Add bills, subscriptions, or regular income to see what is coming next.',
            'Thêm hóa đơn, đăng ký hoặc thu nhập định kỳ để xem các khoản sắp tới.',
          ),
          textAlign: TextAlign.center,
          style: _body(context, 12, muted: true),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onCreate,
          style: FilledButton.styleFrom(backgroundColor: _primary),
          icon: const Icon(Icons.add_rounded),
          label: Text(AppStrings.choose('Add recurring', 'Thêm lịch định kỳ')),
        ),
      ],
    ),
  );
}

// Retained temporarily for visual rollback of the previous control center.
// ignore: unused_element
class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.income,
    required this.expense,
    required this.onCreate,
  });

  final int income;
  final int expense;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final difference = income - expense;
    final total = income + expense;
    final incomeRatio = total == 0 ? .5 : income / total;
    final start = DateTime.now();
    final end = start.add(const Duration(days: 29));

    return Container(
      decoration: _cardDecoration(
        context,
        radius: 22,
      ).copyWith(border: Border.all(color: dark ? _darkBorder : _surfaceMint)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 4, color: dark ? _mint : _primary),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _IconBubble(
                      icon: Icons.calendar_view_month_rounded,
                      color: _primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.choose(
                              '30-Day Forecast',
                              'Dự báo 30 ngày',
                            ),
                            style: _headline(context, 19),
                          ),
                          Text(
                            '${_monthDay(start)} – ${_monthDay(end)}',
                            style: _body(context, 12, muted: true),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppStrings.choose('Details', 'Chi tiết')),
                          const Icon(Icons.chevron_right_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  AppStrings.choose(
                    'Expected cash-flow difference',
                    'Chênh lệch dòng tiền dự kiến',
                  ),
                  style: _body(context, 13, muted: true),
                ),
                const SizedBox(height: 4),
                Text(
                  _signedMoney(difference),
                  style: _headline(context, 27).copyWith(
                    color: difference < 0
                        ? _coral
                        : (difference > 0 ? _primary : null),
                  ),
                ),
                if (difference < 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _amber.withValues(alpha: .25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFB77900),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppStrings.choose(
                              'Expenses exceed income by ${_money(difference.abs())}',
                              'Chi vượt thu ${_money(difference.abs())}',
                            ),
                            style: _body(context, 12).copyWith(
                              color: const Color(0xFF8A6200),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ForecastMetric(
                        title: AppStrings.choose('Income', 'Thu nhập'),
                        amount: income,
                        positive: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ForecastMetric(
                        title: AppStrings.choose('Expenses', 'Chi tiêu'),
                        amount: expense,
                        positive: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Row(
                    children: [
                      Expanded(
                        flex: math.max(1, (incomeRatio * 100).round()),
                        child: Container(height: 7, color: _mint),
                      ),
                      Expanded(
                        flex: math.max(1, ((1 - incomeRatio) * 100).round()),
                        child: Container(height: 7, color: _coral),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(
                      color: _mint,
                      label:
                          '${AppStrings.choose("Income", "Thu")} ${(incomeRatio * 100).round()}%',
                    ),
                    const SizedBox(width: 30),
                    _LegendDot(
                      color: _coral,
                      label:
                          '${AppStrings.choose("Expenses", "Chi")} ${((1 - incomeRatio) * 100).round()}%',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: onCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      AppStrings.choose('New Recurring', 'Tạo định kỳ'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastMetric extends StatelessWidget {
  const _ForecastMetric({
    required this.title,
    required this.amount,
    required this.positive,
  });
  final String title;
  final int amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? _primary : _coral;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                positive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 17,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(title, style: _body(context, 10, muted: true)),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${positive ? '+' : '-'}${_money(amount)}',
              style: _headline(context, 13).copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: _body(context, 10, muted: true)),
    ],
  );
}

// ignore: unused_element
class _NextPaymentStrip extends StatelessWidget {
  const _NextPaymentStrip({required this.schedule});
  final RecurringSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final days = _daysUntil(schedule.nextOccurrence);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(
        context,
      ).pushNamed(AppRoutes.recurringDetails, arguments: schedule.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            const _IconBubble(
              icon: Icons.calendar_month_rounded,
              color: _primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.choose(
                      'Next payment: ${schedule.name} · ${_monthDay(schedule.nextOccurrence)}',
                      'Kỳ tiếp theo: ${schedule.name} · ${_monthDay(schedule.nextOccurrence)}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(context, 10, muted: true),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _money(schedule.amount.abs()),
                    style: _headline(context, 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _amber.withValues(alpha: .25)),
              ),
              child: Text(
                days <= 0
                    ? AppStrings.choose('Today', 'Hôm nay')
                    : AppStrings.choose('$days days', '$days ngày'),
                style: _body(context, 10).copyWith(
                  color: const Color(0xFF9A6A00),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ViewSegment extends StatelessWidget {
  const _ViewSegment({required this.timelineSelected, required this.onChanged});
  final bool timelineSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? _darkInput : const Color(0xFFDDF5ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _segment(
            context,
            AppStrings.choose('Timeline', 'Dòng thời gian'),
            true,
          ),
          _segment(
            context,
            AppStrings.choose('Schedules', 'Lịch định kỳ'),
            false,
          ),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, bool value) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: timelineSelected == value
              ? (Theme.of(context).brightness == Brightness.dark
                    ? _darkCard
                    : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: timelineSelected == value
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: .08),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: _body(context, 12).copyWith(
            color: timelineSelected == value ? _primary : _muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

// ignore: unused_element
class _RecurringTimeline extends StatelessWidget {
  const _RecurringTimeline({required this.schedules});
  final List<RecurringSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    final sorted = [...schedules]
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
    return Column(
      children: [
        for (var index = 0; index < sorted.length; index++)
          _TimelineEntry(
            schedule: sorted[index],
            showRail: index != sorted.length - 1,
          ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.schedule, required this.showRail});
  final RecurringSchedule schedule;
  final bool showRail;

  @override
  Widget build(BuildContext context) {
    final days = _daysUntil(schedule.nextOccurrence);
    final due = days <= 0;
    final color = due
        ? const Color(0xFF6F46BB)
        : (days <= 7 ? _amber : _primary);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 38,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (showRail)
                  Positioned(
                    top: 12,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: _outline.withValues(alpha: .45),
                    ),
                  ),
                Positioned(
                  top: 5,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: _pageMint, width: 4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: due
                        ? BoxDecoration(
                            color: color.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(5),
                          )
                        : null,
                    child: Text(
                      due
                          ? AppStrings.choose('TODAY', 'HÔM NAY')
                          : _monthDay(schedule.nextOccurrence).toUpperCase(),
                      style: _body(context, 10).copyWith(
                        color: due ? color : _muted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ScheduleCard(schedule: schedule, accent: color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.schedules});
  final List<RecurringSchedule> schedules;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final schedule in schedules)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ScheduleCard(
            schedule: schedule,
            accent: schedule.isActive ? _primary : _muted,
          ),
        ),
    ],
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.accent});
  final RecurringSchedule schedule;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final category = TransactionCategory.resolve(schedule.category);
    final review = schedule.postingMode == RecurringPostingMode.review;
    return Container(
      decoration: _cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).pushNamed(AppRoutes.recurringDetails, arguments: schedule.id),
        child: Stack(
          children: [
            if (review)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: accent),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: .11),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: category.buildIcon(
                          size: 21,
                          color: category.color,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(schedule.name, style: _headline(context, 15)),
                            Text(
                              AppStrings.categoryName(schedule.category),
                              style: _body(context, 12, muted: true),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _signedMoney(schedule.amount),
                        style: _headline(context, 13).copyWith(
                          color: schedule.amount > 0 ? _primary : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Tag(label: _frequencyLabel(schedule.frequency)),
                      _Tag(
                        label: review
                            ? AppStrings.choose(
                                'Confirm required',
                                'Cần xác nhận',
                              )
                            : AppStrings.choose('Auto-post', 'Tự động ghi'),
                        color: review ? accent : _primary,
                      ),
                      if (!schedule.isActive)
                        _Tag(
                          label: AppStrings.choose('Paused', 'Đã tạm dừng'),
                          color: _muted,
                        ),
                    ],
                  ),
                  if (review && schedule.isActive) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: FilledButton(
                        onPressed: () =>
                            ReviewOccurrenceSheet.show(context, schedule),
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: accent.withValues(alpha: .14),
                          foregroundColor: accent == _amber
                              ? const Color(0xFF8A6200)
                              : accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: Text(
                          AppStrings.choose('Review', 'Xem lại'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final source = color ?? _muted;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final resolved = !dark
        ? source
        : source == _primary
        ? _darkPositive
        : source == _coral
        ? _darkNegative
        : source == _amber
        ? _darkWarning
        : _darkSecondaryText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: _body(
          context,
          10,
        ).copyWith(color: resolved, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ignore: unused_element
class _EmptyRecurring extends StatelessWidget {
  const _EmptyRecurring({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: _cardDecoration(context),
    child: Column(
      children: [
        const _IconBubble(
          icon: Icons.event_available_rounded,
          color: _primary,
          size: 58,
          iconSize: 29,
        ),
        const SizedBox(height: 14),
        Text(
          AppStrings.choose(
            'No recurring schedules yet',
            'Chưa có lịch định kỳ',
          ),
          style: _headline(context, 18),
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.choose(
            'Create a schedule to forecast and record regular payments.',
            'Tạo lịch để dự báo và ghi lại các khoản thanh toán thường xuyên.',
          ),
          textAlign: TextAlign.center,
          style: _body(context, 13, muted: true),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: Text(AppStrings.choose('Create schedule', 'Tạo lịch')),
        ),
      ],
    ),
  );
}

class NewRecurringScreen extends ConsumerStatefulWidget {
  const NewRecurringScreen({super.key, this.schedule});
  final RecurringSchedule? schedule;

  @override
  ConsumerState<NewRecurringScreen> createState() => _NewRecurringScreenState();
}

class _NewRecurringScreenState extends ConsumerState<NewRecurringScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late String _category;
  late RecurringFrequency _frequency;
  late bool _isIncome;
  late DateTime _nextDate;
  late RecurringPostingMode _postingMode;
  late int _reminderDays;
  String? _walletId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    _nameController = TextEditingController(text: schedule?.name ?? '');
    _amountController = TextEditingController(
      text: schedule == null ? '' : _digits(schedule.amount.abs()),
    );
    _frequency = schedule?.frequency ?? RecurringFrequency.monthly;
    _isIncome = schedule != null && schedule.amount > 0;
    _category = schedule == null
        ? 'Bills'
        : TransactionCategory.normalizedKey(
            schedule.category,
            isIncome: _isIncome,
          );
    _nextDate =
        schedule?.nextOccurrence ?? DateTime.now().add(const Duration(days: 1));
    _postingMode = schedule?.postingMode ?? RecurringPostingMode.review;
    _reminderDays = schedule?.reminderDays ?? 1;
    _walletId = schedule?.walletId;
    Future.microtask(() async {
      if (WalletService.instance.currentUserWallets.isEmpty) {
        await WalletService.instance.fetchWallets();
      }
      if (mounted && _walletId == null) {
        setState(() {
          _walletId = WalletService.instance.currentUserWallets
              .where((wallet) => wallet.isActive)
              .firstOrNull
              ?.id;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null) {
      _message(
        AppStrings.choose('Please sign in first.', 'Vui lòng đăng nhập.'),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final rawAmount = int.parse(_amountController.text.replaceAll(',', ''));
      final old = widget.schedule;
      await ref
          .read(recurringServiceProvider)
          .save(
            RecurringSchedule(
              id:
                  old?.id ??
                  'recurring-${DateTime.now().microsecondsSinceEpoch}',
              userId: old?.userId ?? userId,
              name: _nameController.text.trim(),
              category: _category,
              amount: _isIncome ? rawAmount : -rawAmount,
              frequency: _frequency,
              nextOccurrence: _nextDate,
              isActive: old?.isActive ?? true,
              walletId: _walletId,
              postingMode: _postingMode,
              reminderDays: _reminderDays,
              // Monthly schedules use the day selected for the first
              // occurrence. The old separate "last day" option is no longer
              // exposed by the form.
              useLastDay: false,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final amountAccent = dark
        ? (_isIncome ? _darkPositive : _darkNegative)
        : (_isIncome ? _primary : const Color(0xFFD84D4D));
    return Scaffold(
      backgroundColor: dark ? _darkPage : _pageMint,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: dark ? _darkPage : _pageMint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: dark
            ? const Border(bottom: BorderSide(color: _darkBorder))
            : null,
        iconTheme: IconThemeData(
          color: dark ? _darkSecondaryText : _primaryDark,
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: AppStrings.choose('Close', 'Đóng'),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          widget.schedule == null
              ? AppStrings.choose(
                  'New Recurring Transaction',
                  'Giao dịch định kỳ mới',
                )
              : AppStrings.choose('Edit Schedule', 'Sửa lịch định kỳ'),
          style: _headline(
            context,
            22,
          ).copyWith(color: dark ? _darkText : _primary),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          children: [
            _FormSection(
              key: const Key('recurring-form-transaction'),
              title: null,
              children: [
                _IncomeExpenseSegment(
                  isIncome: _isIncome,
                  onChanged: _setIncomeType,
                ),
                const SizedBox(height: 14),
                _buildCategoryPicker(),
                const SizedBox(height: 13),
                _TextFieldCard(
                  fieldKey: const Key('recurring-name-field'),
                  controller: _nameController,
                  label: AppStrings.choose('Transaction Name', 'Tên giao dịch'),
                  hint: AppStrings.choose('e.g. Netflix', 'Ví dụ: Netflix'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? AppStrings.choose('Enter a name', 'Hãy nhập tên')
                      : null,
                ),
                const SizedBox(height: 13),
                _TextFieldCard(
                  fieldKey: const Key('recurring-amount-field'),
                  controller: _amountController,
                  label: AppStrings.choose('Amount', 'Số tiền'),
                  suffix: 'VND',
                  isAmount: true,
                  accentColor: amountAccent,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ThousandsFormatter(),
                  ],
                  validator: (value) {
                    final amount = int.tryParse(
                      value?.replaceAll(',', '') ?? '',
                    );
                    return amount == null || amount <= 0
                        ? AppStrings.choose(
                            'Enter a valid amount',
                            'Nhập số tiền hợp lệ',
                          )
                        : null;
                  },
                ),
                const SizedBox(height: 13),
                _buildWalletPicker(),
              ],
            ),
            const SizedBox(height: 12),
            _FormSection(
              key: const Key('recurring-form-repeat'),
              title: AppStrings.choose('Repeat Schedule', 'Lịch lặp lại'),
              children: [
                _FrequencySegment(
                  selected: _frequency,
                  onChanged: (value) => setState(() => _frequency = value),
                ),
                const SizedBox(height: 13),
                _PickerCard(
                  icon: Icons.calendar_today_outlined,
                  label: AppStrings.choose(
                    'First occurrence',
                    'Lần phát sinh đầu tiên',
                  ),
                  value: _fullDate(_nextDate),
                  onTap: _pickStartDate,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FormSection(
              key: const Key('recurring-form-automation'),
              title: AppStrings.choose('Automation', 'Tự động hóa'),
              children: [
                _FieldLabel(AppStrings.choose('Posting Mode', 'Chế độ ghi')),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: _PostingModeCard(
                        icon: Icons.fact_check_outlined,
                        title: AppStrings.choose(
                          'Review & Confirm',
                          'Xem và xác nhận',
                        ),
                        selected: _postingMode == RecurringPostingMode.review,
                        onTap: () => setState(
                          () => _postingMode = RecurringPostingMode.review,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PostingModeCard(
                        icon: Icons.autorenew_rounded,
                        title: AppStrings.choose('Auto-post', 'Tự động ghi'),
                        selected:
                            _postingMode == RecurringPostingMode.automatic,
                        onTap: () => setState(
                          () => _postingMode = RecurringPostingMode.automatic,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildReminderPicker(),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.schedule == null
                            ? AppStrings.choose('Create Schedule', 'Tạo lịch')
                            : AppStrings.choose('Save Changes', 'Lưu thay đổi'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    final selected = TransactionCategory.resolve(_category);
    return _AnchoredPickerField<String>(
      fieldKey: const Key('recurring-category-field'),
      label: AppStrings.choose('Category', 'Danh mục'),
      value: AppStrings.categoryName(selected.label),
      leading: selected.buildIcon(size: 18),
      selectedValue: _category,
      options: [
        for (final category in TransactionCategory.forType(isIncome: _isIncome))
          _PickerOption(
            value: category.key,
            label: AppStrings.categoryName(category.label),
            leading: category.buildIcon(size: 20),
          ),
      ],
      onSelected: (value) => setState(() => _category = value),
    );
  }

  void _setIncomeType(bool isIncome) {
    final selected = TransactionCategory.resolve(_category);
    setState(() {
      _isIncome = isIncome;
      final requiredType = isIncome
          ? TransactionCategoryType.income
          : TransactionCategoryType.expense;
      if (selected.type != requiredType) {
        _category = isIncome ? 'Salary' : 'Bills';
      }
    });
  }

  Widget _buildWalletPicker() {
    final wallets = WalletService.instance.currentUserWallets
        .where((wallet) => wallet.isActive)
        .toList(growable: false);
    if (wallets.isEmpty) {
      return _PickerCard(
        key: const Key('recurring-wallet-field'),
        icon: Icons.account_balance_wallet_outlined,
        label: AppStrings.choose('Wallet', 'Ví'),
        value: AppStrings.choose('No active wallet found', 'Không có ví'),
        onTap: () => _message(
          AppStrings.choose(
            'No active wallet found.',
            'Không có ví hoạt động.',
          ),
        ),
      );
    }
    final selectedWallet = WalletService.instance.byId(_walletId);
    Widget walletIcon(WalletType type) => Icon(
      type == WalletType.cash
          ? Icons.payments_outlined
          : Icons.account_balance_outlined,
      size: 19,
      color: _primary,
    );
    return _AnchoredPickerField<String>(
      fieldKey: const Key('recurring-wallet-field'),
      label: AppStrings.choose('Wallet', 'Ví'),
      value: _walletName(_walletId),
      leading: walletIcon(selectedWallet?.type ?? WalletType.cash),
      selectedValue: _walletId,
      options: [
        for (final wallet in wallets)
          _PickerOption(
            value: wallet.id,
            label: wallet.name,
            leading: walletIcon(wallet.type),
          ),
      ],
      onSelected: (value) => setState(() => _walletId = value),
    );
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: _nextDate.isBefore(DateTime.now())
          ? DateTime.now()
          : _nextDate,
    );
    if (date != null) setState(() => _nextDate = date);
  }

  Widget _buildReminderPicker() {
    String reminderLabel(int days) => days == 0
        ? AppStrings.choose('On due date', 'Đúng ngày')
        : AppStrings.choose(
            '$days day${days == 1 ? '' : 's'} before',
            'Trước $days ngày',
          );
    return _AnchoredPickerField<int>(
      fieldKey: const Key('recurring-reminder-field'),
      label: AppStrings.choose('Reminder', 'Nhắc nhở'),
      value: reminderLabel(_reminderDays),
      leading: const Icon(
        Icons.notifications_none_rounded,
        size: 19,
        color: _muted,
      ),
      selectedValue: _reminderDays,
      options: [
        for (final days in const [0, 1, 2, 3, 7])
          _PickerOption(value: days, label: reminderLabel(days)),
      ],
      onSelected: (value) => setState(() => _reminderDays = value),
    );
  }
}

class RecurringScheduleDetailsScreen extends ConsumerStatefulWidget {
  const RecurringScheduleDetailsScreen({super.key, required this.scheduleId});
  final String scheduleId;

  @override
  ConsumerState<RecurringScheduleDetailsScreen> createState() =>
      _RecurringScheduleDetailsScreenState();
}

class _RecurringScheduleDetailsScreenState
    extends ConsumerState<RecurringScheduleDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final service = ref.read(recurringServiceProvider);
      if (service.schedules.isEmpty) await service.fetch();
      await service.fetchOccurrenceHistory(widget.scheduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(recurringServiceRevisionProvider);
    final service = ref.read(recurringServiceProvider);
    final storedSchedule = service.schedules
        .where((item) => item.id == widget.scheduleId)
        .firstOrNull;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (storedSchedule == null) {
      return Scaffold(
        backgroundColor: dark ? _darkPage : _pageMint,
        appBar: _RecurringAppBar(
          context: context,
          dark: dark,
          title: AppStrings.choose('Schedule Details', 'Chi tiết lịch'),
        ),
        body: Center(
          child: Text(
            AppStrings.choose(
              'Schedule not found.',
              'Không tìm thấy lịch định kỳ.',
            ),
          ),
        ),
      );
    }
    final schedule = storedSchedule.copyWith(
      nextOccurrence: storedSchedule.nextOccurrenceOnOrAfter(DateTime.now()),
    );

    final transactionHistory =
        TransactionService.instance.currentUserTransactions
            .where(
              (transaction) =>
                  transaction.id.startsWith('recurring-${schedule.id}-'),
            )
            .toList(growable: false)
          ..sort((a, b) => b.date.compareTo(a.date));
    final storedHistory = service.occurrenceHistoryFor(schedule.id);
    final history = storedHistory.isNotEmpty
        ? storedHistory
        : transactionHistory
              .map(
                (transaction) => RecurringOccurrenceRecord(
                  id: transaction.id,
                  scheduleId: schedule.id,
                  occurrenceAt: transaction.date,
                  status: RecurringOccurrenceStatus.completed,
                  amount: transaction.amount,
                ),
              )
              .toList(growable: false);
    final completed = history
        .where((item) => item.status == RecurringOccurrenceStatus.completed)
        .length;
    final skipped = history
        .where((item) => item.status == RecurringOccurrenceStatus.skipped)
        .length;
    final failed = history
        .where((item) => item.status == RecurringOccurrenceStatus.failed)
        .length;

    return Scaffold(
      backgroundColor: dark ? _darkPage : _pageMint,
      appBar: _RecurringAppBar(
        context: context,
        dark: dark,
        title: AppStrings.choose('Schedule Details', 'Chi tiết lịch'),
        trailing: PopupMenuButton<String>(
          key: const Key('recurring-details-options-menu'),
          tooltip: AppStrings.choose('Schedule options', 'Tùy chọn lịch'),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          elevation: 14,
          color: dark ? _darkCard : Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: const Color(0x33001F17),
          constraints: const BoxConstraints(minWidth: 224, maxWidth: 260),
          padding: EdgeInsets.zero,
          menuPadding: const EdgeInsets.symmetric(vertical: 5),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: dark ? _darkBorder : const Color(0xFFDCE7E2),
            ),
          ),
          onSelected: (value) => _handleMenu(value, schedule),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _RecurringMenuItem(
                icon: FinFlowPencilIcon(
                  size: 18,
                  color: dark ? _darkPositive : _primary,
                ),
                iconColor: dark ? _darkPositive : _primary,
                label: AppStrings.choose('Edit schedule', 'Chỉnh sửa lịch'),
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'toggle',
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _RecurringMenuItem(
                icon: schedule.isActive
                    ? FinFlowPauseIcon(
                        size: 18,
                        color: dark ? _darkWarning : const Color(0xFF9A6A00),
                      )
                    : FinFlowPlayIcon(
                        size: 18,
                        color: dark ? _darkPositive : _primary,
                      ),
                iconColor: schedule.isActive
                    ? (dark ? _darkWarning : const Color(0xFF9A6A00))
                    : (dark ? _darkPositive : _primary),
                label: schedule.isActive
                    ? AppStrings.choose('Pause schedule', 'Tạm dừng lịch')
                    : AppStrings.choose('Resume schedule', 'Tiếp tục lịch'),
              ),
            ),
            if (schedule.isActive) const PopupMenuDivider(height: 1),
            if (schedule.isActive)
              PopupMenuItem(
                value: 'skip',
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _RecurringMenuItem(
                  icon: FinFlowSkipIcon(
                    size: 18,
                    color: dark ? _darkPositive : const Color(0xFF00785D),
                  ),
                  iconColor: dark ? _darkPositive : const Color(0xFF00785D),
                  label: AppStrings.choose(
                    'Skip next occurrence',
                    'Bỏ qua kỳ tiếp theo',
                  ),
                ),
              ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'delete',
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _RecurringMenuItem(
                icon: FinFlowTrashIcon(
                  size: 18,
                  color: dark ? _darkNegative : const Color(0xFFBA1A1A),
                ),
                iconColor: dark ? _darkNegative : const Color(0xFFBA1A1A),
                label: AppStrings.choose('Delete schedule', 'Xóa lịch'),
                destructive: true,
              ),
            ),
          ],
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: dark
                  ? _darkBorder.withValues(alpha: .72)
                  : const Color(0xFFF3F6F5),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.more_horiz_rounded,
              size: 21,
              color: dark ? _darkSecondaryText : _muted,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          _ScheduleOverviewCard(schedule: schedule),
          const SizedBox(height: 14),
          Container(
            key: const Key('recurring-details-reminder-banner'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF0D3028) : _surfaceMint,
              borderRadius: BorderRadius.circular(12),
              border: dark ? Border.all(color: const Color(0xFF245A4C)) : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.event_available_rounded, color: _primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.choose(
                      'Next payment is scheduled for ${_fullDate(schedule.nextOccurrence)}. FinFlow will remind you ${schedule.reminderDays == 0 ? 'on the due date' : '${schedule.reminderDays} day${schedule.reminderDays == 1 ? '' : 's'} before'}.',
                      'Kỳ tiếp theo vào ${_fullDate(schedule.nextOccurrence)}. FinFlow sẽ nhắc ${schedule.reminderDays == 0 ? 'đúng ngày' : 'trước ${schedule.reminderDays} ngày'}.',
                    ),
                    style: _body(context, 15).copyWith(
                      fontWeight: FontWeight.w600,
                      color: _detailSecondaryColor(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: schedule.isActive
                  ? () => ReviewOccurrenceSheet.show(context, schedule)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(
                AppStrings.choose('Review occurrence', 'Xem lại kỳ này'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            AppStrings.choose('Health & History', 'Trạng thái & lịch sử'),
            style: _headline(context, 20),
          ),
          const SizedBox(height: 12),
          _HealthCard(completed: completed, skipped: skipped, failed: failed),
          const SizedBox(height: 18),
          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(context),
              child: Text(
                AppStrings.choose(
                  'No recorded occurrences yet.',
                  'Chưa có kỳ nào được ghi nhận.',
                ),
                textAlign: TextAlign.center,
                style: _body(context, 14.5, muted: true).copyWith(
                  color: _detailSecondaryColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            _HistoryTimeline(history: history.take(3).toList()),
          const SizedBox(height: 28),
          Text(
            AppStrings.choose('Schedule Rules', 'Quy tắc lịch'),
            style: _headline(context, 20),
          ),
          const SizedBox(height: 12),
          _RulesCard(schedule: schedule),
        ],
      ),
    );
  }

  Future<void> _handleMenu(String value, RecurringSchedule schedule) async {
    if (value == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NewRecurringScreen(schedule: schedule),
        ),
      );
    } else if (value == 'toggle') {
      await ref.read(recurringServiceProvider).toggle(schedule);
    } else if (value == 'skip') {
      await _skipOccurrence(schedule);
    } else if (value == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppStrings.choose('Delete schedule?', 'Xóa lịch?')),
          content: Text(
            AppStrings.choose(
              'This recurring schedule will be permanently deleted.',
              'Lịch định kỳ này sẽ bị xóa vĩnh viễn.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppStrings.choose('Cancel', 'Hủy')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: _coral),
              child: Text(AppStrings.choose('Delete', 'Xóa')),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(recurringServiceProvider).delete(schedule.id);
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  Future<void> _skipOccurrence(RecurringSchedule schedule) async {
    final occurrence = schedule.nextOccurrenceOnOrAfter(DateTime.now());
    final confirmed = await _confirmSkipOccurrence(context, schedule);
    if (!confirmed || !mounted) return;
    await ref.read(recurringServiceProvider).skipOccurrence(schedule);
    if (!mounted) return;
    final next = ref
        .read(recurringServiceProvider)
        .findById(schedule.id)
        ?.nextOccurrence;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.choose(
            '${_monthDay(occurrence)} skipped.${next == null ? '' : ' Next occurrence: ${_monthDay(next)}.'}',
            'Đã bỏ qua ${_monthDay(occurrence)}.${next == null ? '' : ' Kỳ tiếp theo: ${_monthDay(next)}.'}',
          ),
        ),
      ),
    );
  }
}

class _RecurringMenuItem extends StatelessWidget {
  const _RecurringMenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.destructive = false,
  });

  final Widget icon;
  final Color iconColor;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = destructive
        ? (dark ? _darkNegative : const Color(0xFFBA1A1A))
        : (dark ? _darkText : _ink);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: dark ? .16 : .11),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: icon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleOverviewCard extends StatelessWidget {
  const _ScheduleOverviewCard({required this.schedule});
  final RecurringSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final category = TransactionCategory.resolve(schedule.category);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final positive = dark ? _darkPositive : _primary;
    return Container(
      key: const Key('recurring-details-overview-card'),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: .11),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: category.buildIcon(size: 21, color: category.color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(schedule.name, style: _headline(context, 19)),
                    Text(
                      schedule.amount < 0
                          ? AppStrings.choose(
                              'Recurring expense',
                              'Chi phí định kỳ',
                            )
                          : AppStrings.choose(
                              'Recurring income',
                              'Thu nhập định kỳ',
                            ),
                      style: _body(context, 14.5, muted: true).copyWith(
                        color: _detailSecondaryColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _Tag(
                label: schedule.isActive
                    ? AppStrings.choose('Active', 'Hoạt động')
                    : AppStrings.choose('Paused', 'Tạm dừng'),
                color: schedule.isActive ? positive : _muted,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            schedule.frequency == RecurringFrequency.monthly
                ? AppStrings.choose(
                    'MONTHLY ${schedule.amount < 0 ? 'EXPENSE' : 'INCOME'}',
                    'KHOẢN ${schedule.amount < 0 ? 'CHI' : 'THU'} HÀNG THÁNG',
                  )
                : AppStrings.choose('RECURRING AMOUNT', 'SỐ TIỀN ĐỊNH KỲ'),
            style: _body(context, 13.5, muted: true).copyWith(
              color: _detailSecondaryColor(context),
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 3),
          Text(_money(schedule.amount.abs()), style: _headline(context, 28)),
          Text(
            AppStrings.choose(
              'Next payment ${_fullDate(schedule.nextOccurrence)}',
              'Kỳ tiếp theo ${_fullDate(schedule.nextOccurrence)}',
            ),
            style: _body(context, 14.5, muted: true).copyWith(
              color: _detailSecondaryColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.repeat_rounded,
            label: AppStrings.choose('Schedule', 'Lịch'),
            value: _scheduleRule(schedule),
          ),
          _DetailRow(
            icon: Icons.calendar_month_outlined,
            label: AppStrings.choose('Next payment', 'Kỳ tiếp theo'),
            value: _fullDate(schedule.nextOccurrence),
            valueColor: positive,
          ),
          _DetailRow(
            icon: Icons.account_balance_wallet_outlined,
            label: AppStrings.choose('Payment wallet', 'Ví thanh toán'),
            value: _walletName(schedule.walletId),
          ),
          _DetailRow(
            icon: Icons.notifications_active_outlined,
            label: AppStrings.choose('Posting', 'Ghi giao dịch'),
            value: schedule.postingMode == RecurringPostingMode.review
                ? AppStrings.choose(
                    'Review before posting',
                    'Xác nhận trước khi ghi',
                  )
                : AppStrings.choose('Automatic', 'Tự động'),
          ),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.completed,
    required this.skipped,
    required this.failed,
  });
  final int completed;
  final int skipped;
  final int failed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: _HealthMetric(
              icon: Icons.check_circle_outline_rounded,
              value: completed,
              label: AppStrings.choose('Completed', 'Hoàn tất'),
              color: dark ? _darkPositive : _primary,
            ),
          ),
          const SizedBox(height: 38, child: VerticalDivider(width: 1)),
          Expanded(
            child: _HealthMetric(
              icon: Icons.skip_next_rounded,
              value: skipped,
              label: AppStrings.choose('Skipped', 'Bỏ qua'),
              color: dark ? _darkWarning : const Color(0xFFB77900),
            ),
          ),
          const SizedBox(height: 38, child: VerticalDivider(width: 1)),
          Expanded(
            child: _HealthMetric(
              icon: Icons.error_outline_rounded,
              value: failed,
              label: AppStrings.choose('Failed', 'Thất bại'),
              color: dark ? _darkNegative : _coral,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthMetric extends StatelessWidget {
  const _HealthMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text('$value', style: _headline(context, 17).copyWith(color: color)),
        ],
      ),
      const SizedBox(height: 3),
      Text(
        label,
        style: _body(context, 13.5, muted: true).copyWith(
          color: _detailSecondaryColor(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _HistoryTimeline extends StatelessWidget {
  const _HistoryTimeline({required this.history});
  final List<RecurringOccurrenceRecord> history;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < history.length; i++)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: _historyStatusColor(context, history[i].status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (i != history.length - 1)
                    Container(
                      width: 2,
                      height: 64,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? _darkBorder
                          : _outline.withValues(alpha: .45),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: _cardDecoration(context, radius: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _monthDay(history[i].occurrenceAt),
                      style: _headline(context, 16),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Tag(
                          label: _historyStatusLabel(history[i].status),
                          color: _historyStatusColor(
                            context,
                            history[i].status,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _money(history[i].amount.abs()),
                          style: _body(context, 14, muted: true).copyWith(
                            color: _detailSecondaryColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    ],
  );
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.schedule});
  final RecurringSchedule schedule;

  @override
  Widget build(BuildContext context) => Container(
    decoration: _cardDecoration(context),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        _RuleRow(
          icon: Icons.repeat_rounded,
          label: AppStrings.choose('Frequency', 'Tần suất'),
          value: _scheduleRule(schedule),
        ),
        _RuleRow(
          icon: Icons.calendar_month_outlined,
          label: AppStrings.choose('Next payment', 'Kỳ tiếp theo'),
          value: _fullDate(schedule.nextOccurrence),
        ),
        _RuleRow(
          icon: Icons.notifications_none_rounded,
          label: AppStrings.choose('Reminder', 'Nhắc nhở'),
          value: schedule.reminderDays == 0
              ? AppStrings.choose('On due date', 'Đúng ngày')
              : AppStrings.choose(
                  '${schedule.reminderDays} day${schedule.reminderDays == 1 ? '' : 's'} before',
                  'Trước ${schedule.reminderDays} ngày',
                ),
        ),
        _RuleRow(
          icon: Icons.visibility_outlined,
          label: AppStrings.choose('Posting mode', 'Chế độ ghi'),
          value: schedule.postingMode == RecurringPostingMode.review
              ? AppStrings.choose('Review before posting', 'Xem trước khi ghi')
              : AppStrings.choose('Automatic', 'Tự động'),
          showDivider: false,
        ),
      ],
    ),
  );
}

String _historyStatusLabel(
  RecurringOccurrenceStatus status,
) => switch (status) {
  RecurringOccurrenceStatus.completed => AppStrings.choose(
    'Completed',
    'Hoàn tất',
  ),
  RecurringOccurrenceStatus.skipped => AppStrings.choose('Skipped', 'Bỏ qua'),
  RecurringOccurrenceStatus.failed => AppStrings.choose('Failed', 'Thất bại'),
  RecurringOccurrenceStatus.pending => AppStrings.choose('Pending', 'Đang chờ'),
};

Color _historyStatusColor(
  BuildContext context,
  RecurringOccurrenceStatus status,
) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    RecurringOccurrenceStatus.completed => dark ? _darkPositive : _primary,
    RecurringOccurrenceStatus.skipped =>
      dark ? _darkWarning : const Color(0xFFB77900),
    RecurringOccurrenceStatus.failed => dark ? _darkNegative : _coral,
    RecurringOccurrenceStatus.pending => dark ? _darkSecondaryText : _muted,
  };
}

Future<bool> _confirmSkipOccurrence(
  BuildContext context,
  RecurringSchedule schedule,
) async {
  final occurrence = schedule.nextOccurrenceOnOrAfter(DateTime.now());
  final next = schedule.occurrenceAfter(occurrence);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: .16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.skip_next_rounded,
              color: Color(0xFF9A6A00),
              size: 27,
            ),
          ),
          title: Text(
            AppStrings.choose(
              'Skip the ${_monthDay(occurrence)} occurrence?',
              'Bỏ qua kỳ ngày ${_monthDay(occurrence)}?',
            ),
            style: _headline(dialogContext, 20),
          ),
          content: Text(
            AppStrings.choose(
              'No transaction will be created. The next occurrence will be ${_monthDay(next)}.',
              'Sẽ không tạo giao dịch. Kỳ tiếp theo sẽ là ${_monthDay(next)}.',
            ),
            style: _body(dialogContext, 15).copyWith(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppStrings.choose('Cancel', 'Hủy')),
            ),
            FilledButton.icon(
              key: const Key('confirm-skip-recurring-occurrence'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.skip_next_rounded),
              label: Text(
                AppStrings.choose('Skip occurrence', 'Bỏ qua kỳ này'),
              ),
            ),
          ],
        ),
      ) ??
      false;
}

class ReviewOccurrenceSheet {
  static Future<void> show(BuildContext context, RecurringSchedule schedule) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: _primaryDark.withValues(alpha: .28),
        builder: (_) => _ReviewOccurrenceSheet(schedule: schedule),
      );
}

class _ReviewOccurrenceSheet extends ConsumerStatefulWidget {
  const _ReviewOccurrenceSheet({required this.schedule});
  final RecurringSchedule schedule;

  @override
  ConsumerState<_ReviewOccurrenceSheet> createState() =>
      _ReviewOccurrenceSheetState();
}

class _ReviewOccurrenceSheetState
    extends ConsumerState<_ReviewOccurrenceSheet> {
  late final TextEditingController _amountController;
  bool _editingAmount = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: _digits(widget.schedule.amount.abs()),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    final unsigned = int.tryParse(_amountController.text.replaceAll(',', ''));
    if (unsigned == null || unsigned <= 0) return;
    setState(() => _saving = true);
    try {
      final effectiveSchedule = widget.schedule.copyWith(
        nextOccurrence: widget.schedule.nextOccurrenceOnOrAfter(DateTime.now()),
      );
      final amount = effectiveSchedule.amount < 0 ? -unsigned : unsigned;
      await ref
          .read(recurringServiceProvider)
          .recordOccurrence(effectiveSchedule, amount: amount);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    if (_saving) return;
    final schedule = widget.schedule.copyWith(
      nextOccurrence: widget.schedule.nextOccurrenceOnOrAfter(DateTime.now()),
    );
    final confirmed = await _confirmSkipOccurrence(context, schedule);
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _saving = true);
    try {
      await ref.read(recurringServiceProvider).skipOccurrence(schedule);
      final next = ref
          .read(recurringServiceProvider)
          .findById(schedule.id)
          ?.nextOccurrence;
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              '${_monthDay(schedule.nextOccurrence)} skipped.${next == null ? '' : ' Next occurrence: ${_monthDay(next)}.'}',
              'Đã bỏ qua ${_monthDay(schedule.nextOccurrence)}.${next == null ? '' : ' Kỳ tiếp theo: ${_monthDay(next)}.'}',
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule.copyWith(
      nextOccurrence: widget.schedule.nextOccurrenceOnOrAfter(DateTime.now()),
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    final category = TransactionCategory.resolve(schedule.category);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .80,
        ),
        decoration: BoxDecoration(
          color: dark ? _darkPage : _pageMint,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: .12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: _outline,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: .11),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: category.buildIcon(
                        size: 23,
                        color: category.color,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _amber.withValues(alpha: .17),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        AppStrings.choose('PAYMENT DUE', 'ĐẾN HẠN'),
                        style: _body(context, 10.5).copyWith(
                          color: const Color(0xFF9A6A00),
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(schedule.name, style: _headline(context, 20)),
                    Text(
                      AppStrings.choose(
                        'Recurring payment for ${_monthName(schedule.nextOccurrence.month)}',
                        'Thanh toán định kỳ tháng ${schedule.nextOccurrence.month}',
                      ),
                      style: _body(context, 13.5, muted: true).copyWith(
                        color: _detailSecondaryColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                      decoration: _cardDecoration(context).copyWith(
                        border: Border.all(
                          color: dark ? _darkBorder : _surfaceMint,
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: -18,
                            top: -14,
                            bottom: -14,
                            child: Container(
                              width: 3,
                              color: schedule.amount < 0 ? _coral : _primary,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      schedule.amount < 0
                                          ? AppStrings.choose(
                                              'Amount to pay',
                                              'Số tiền chi',
                                            )
                                          : AppStrings.choose(
                                              'Amount to receive',
                                              'Số tiền thu',
                                            ),
                                      style: _body(context, 14, muted: true)
                                          .copyWith(
                                            color: _detailSecondaryColor(
                                              context,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  _Tag(
                                    label: schedule.amount < 0
                                        ? AppStrings.choose(
                                            'EXPENSE ↓',
                                            'CHI ↓',
                                          )
                                        : AppStrings.choose(
                                            'INCOME ↑',
                                            'THU ↑',
                                          ),
                                    color: schedule.amount < 0
                                        ? _coral
                                        : _primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              if (_editingAmount)
                                TextField(
                                  controller: _amountController,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    _ThousandsFormatter(),
                                  ],
                                  style: _headline(context, 26),
                                  decoration: const InputDecoration(
                                    suffixText: 'VND',
                                    isDense: true,
                                  ),
                                )
                              else
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _money(
                                          int.tryParse(
                                                _amountController.text
                                                    .replaceAll(',', ''),
                                              ) ??
                                              schedule.amount.abs(),
                                          withCurrency: false,
                                        ),
                                        style: _headline(context, 27),
                                      ),
                                      TextSpan(
                                        text: ' VND',
                                        style: _body(context, 14.5, muted: true)
                                            .copyWith(
                                              color: _detailSecondaryColor(
                                                context,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                AppStrings.choose(
                                  'Default amount from your recurring schedule',
                                  'Số tiền mặc định từ lịch định kỳ',
                                ),
                                style: _body(context, 12.5, muted: true)
                                    .copyWith(
                                      color: _detailSecondaryColor(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: _cardDecoration(context),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _SheetMeta(
                                  icon: Icons.calendar_today_outlined,
                                  label: AppStrings.choose(
                                    'DUE DATE',
                                    'NGÀY ĐẾN HẠN',
                                  ),
                                  value: _fullDate(schedule.nextOccurrence),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SheetMeta(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: AppStrings.choose('WALLET', 'VÍ'),
                                  value: _walletName(schedule.walletId),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _SheetMeta(
                                  leading:
                                      TransactionCategory.resolve(
                                        schedule.category,
                                      ).buildIcon(
                                        size: 19,
                                        color: _detailSecondaryColor(context),
                                      ),
                                  label: AppStrings.choose(
                                    'CATEGORY',
                                    'DANH MỤC',
                                  ),
                                  value: AppStrings.categoryName(
                                    TransactionCategory.resolve(
                                      schedule.category,
                                    ).label,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SheetMeta(
                                  icon: Icons.update_rounded,
                                  label: AppStrings.choose('SCHEDULE', 'LỊCH'),
                                  value: _scheduleRule(schedule),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.security_outlined,
                                size: 18,
                                color: _detailSecondaryColor(context),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                AppStrings.choose(
                                  'Review required',
                                  'Yêu cầu xác nhận',
                                ),
                                style: _body(context, 13.5, muted: true)
                                    .copyWith(
                                      color: _detailSecondaryColor(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: Container(
                key: const Key('recurring-review-safe-actions'),
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
                decoration: BoxDecoration(
                  color: dark ? _darkCard : Colors.white,
                  border: Border(
                    top: BorderSide(color: dark ? _darkBorder : _surfaceMint),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: .06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: _detailSecondaryColor(context),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            AppStrings.choose(
                              'Creates one ${schedule.amount < 0 ? 'expense' : 'income'} transaction',
                              'Tạo một giao dịch ${schedule.amount < 0 ? 'chi' : 'thu'}',
                            ),
                            textAlign: TextAlign.center,
                            style: _body(context, 13, muted: true).copyWith(
                              color: _detailSecondaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _confirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          AppStrings.choose('Confirm & Save', 'Xác nhận & lưu'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(
                              () => _editingAmount = !_editingAmount,
                            ),
                            style: _sheetOutlineStyle(),
                            child: Text(
                              _editingAmount
                                  ? AppStrings.choose('Done', 'Xong')
                                  : AppStrings.choose(
                                      'Edit Amount',
                                      'Sửa số tiền',
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('skip-recurring-occurrence'),
                            onPressed: _saving ? null : _skip,
                            style: _sheetOutlineStyle().copyWith(
                              foregroundColor: WidgetStatePropertyAll(
                                dark ? _darkWarning : const Color(0xFF8A5D00),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FinFlowSkipIcon(
                                  size: 19,
                                  color: dark
                                      ? _darkWarning
                                      : const Color(0xFF8A5D00),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    AppStrings.choose(
                                      'Skip occurrence',
                                      'Bỏ qua kỳ này',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetMeta extends StatelessWidget {
  const _SheetMeta({
    this.icon,
    this.leading,
    required this.label,
    required this.value,
  }) : assert(icon != null || leading != null);
  final IconData? icon;
  final Widget? leading;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      leading ?? Icon(icon, size: 19, color: _detailSecondaryColor(context)),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: _body(context, 11.5, muted: true).copyWith(
                color: _detailSecondaryColor(context),
                fontWeight: FontWeight.w800,
                letterSpacing: .45,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _body(context, 14).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ],
  );
}

class _RecurringAppBar extends AppBar {
  _RecurringAppBar({
    required BuildContext context,
    required bool dark,
    required String title,
    Widget? trailing,
  }) : super(
         backgroundColor: dark ? _darkPage : Colors.transparent,
         surfaceTintColor: Colors.transparent,
         elevation: 0,
         shape: dark
             ? const Border(bottom: BorderSide(color: _darkBorder))
             : null,
         toolbarHeight: 64,
         centerTitle: false,
         title: Text(
           title,
           maxLines: 1,
           overflow: TextOverflow.ellipsis,
           style: TextStyle(
             fontFamily: _headlineFont,
             fontSize: Responsive.sp(context, 22),
             fontWeight: FontWeight.w700,
             color: dark ? _darkText : _primaryDark,
           ),
         ),
         leading: BackButton(color: dark ? _darkSecondaryText : _primaryDark),
         iconTheme: IconThemeData(
           color: dark ? _darkSecondaryText : _primaryDark,
         ),
         actionsIconTheme: IconThemeData(
           color: dark ? _darkSecondaryText : _primaryDark,
         ),
         actions: trailing == null
             ? null
             : [trailing, const SizedBox(width: 4)],
       );
}

class _FormSection extends StatelessWidget {
  const _FormSection({super.key, required this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(context, radius: 17),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(title!, style: _headline(context, 18)),
          const SizedBox(height: 12),
        ],
        ...children,
      ],
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => Text(
    value,
    style: _body(context, 12.5).copyWith(
      color: Theme.of(context).brightness == Brightness.dark
          ? _darkSecondaryText
          : _ink,
      fontWeight: FontWeight.w800,
      letterSpacing: .45,
    ),
  );
}

class _TextFieldCard extends StatelessWidget {
  const _TextFieldCard({
    required this.fieldKey,
    required this.controller,
    required this.label,
    this.hint,
    this.suffix,
    this.isAmount = false,
    this.accentColor,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? suffix;
  final bool isAmount;
  final Color? accentColor;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: isAmount
              ? TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: accentColor ?? _ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )
              : _body(context, 14).copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _body(context, 14, muted: true),
            suffixText: suffix,
            suffixStyle: _body(context, 13).copyWith(
              color: dark ? _darkText : _ink,
              fontWeight: FontWeight.w700,
            ),
            filled: true,
            fillColor: dark ? _darkInput : const Color(0xFFF3F3F5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: dark
                  ? const BorderSide(color: _darkBorder)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: accentColor ?? _primary,
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD84D4D)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFD84D4D),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _FieldLabel(label),
      const SizedBox(height: 7),
      _PickerSurface(
        onTap: onTap,
        leading: Icon(
          icon,
          size: 19,
          color: Theme.of(context).brightness == Brightness.dark
              ? _darkSecondaryText
              : _muted,
        ),
        value: value,
      ),
    ],
  );
}

class _PickerSurface extends StatelessWidget {
  const _PickerSurface({
    required this.leading,
    required this.value,
    this.onTap,
  });
  final Widget leading;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? _darkInput : const Color(0xFFF3F3F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: dark ? const BorderSide(color: _darkBorder) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                SizedBox(width: 22, child: Center(child: leading)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(
                      context,
                      14,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 19,
                  color: dark ? _darkSecondaryText : _muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerOption<T> {
  const _PickerOption({required this.value, required this.label, this.leading});
  final T value;
  final String label;
  final Widget? leading;
}

class _AnchoredPickerField<T> extends StatelessWidget {
  const _AnchoredPickerField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.leading,
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });
  final Key fieldKey;
  final String label;
  final String value;
  final Widget leading;
  final T? selectedValue;
  final List<_PickerOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    key: fieldKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _FieldLabel(label),
      const SizedBox(height: 7),
      LayoutBuilder(
        builder: (context, constraints) => PopupMenuButton<T>(
          tooltip: label,
          initialValue: selectedValue,
          position: PopupMenuPosition.under,
          color: Theme.of(context).brightness == Brightness.dark
              ? _darkCard
              : Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
            maxHeight: 310,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? _darkBorder
                  : const Color(0xFFDCE9E4),
            ),
          ),
          onSelected: onSelected,
          itemBuilder: (context) => [
            for (final option in options)
              PopupMenuItem<T>(
                value: option.value,
                height: 48,
                child: Row(
                  children: [
                    SizedBox(
                      width: 25,
                      child:
                          option.leading ??
                          const Icon(
                            Icons.circle_outlined,
                            size: 17,
                            color: _muted,
                          ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        option.label,
                        style: _body(
                          context,
                          14,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (option.value == selectedValue)
                      const Icon(
                        Icons.check_rounded,
                        size: 19,
                        color: _primary,
                      ),
                  ],
                ),
              ),
          ],
          child: _PickerSurface(leading: leading, value: value),
        ),
      ),
    ],
  );
}

class _IncomeExpenseSegment extends StatelessWidget {
  const _IncomeExpenseSegment({
    required this.isIncome,
    required this.onChanged,
  });
  final bool isIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? _darkInput
          : const Color(0xFFDDF3EC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        _option(context, AppStrings.choose('Expense', 'Chi tiêu'), false),
        _option(context, AppStrings.choose('Income', 'Thu nhập'), true),
      ],
    ),
  );

  Widget _option(BuildContext context, String label, bool value) => Expanded(
    child: InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        key: Key(
          value ? 'recurring-income-segment' : 'recurring-expense-segment',
        ),
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isIncome == value
              ? value
                    ? _primary
                    : const Color(0xFFDA514F)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isIncome == value
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .05),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: _body(context, 14).copyWith(
            color: isIncome == value
                ? Colors.white
                : Theme.of(context).brightness == Brightness.dark
                ? _darkSecondaryText
                : _muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _FrequencySegment extends StatelessWidget {
  const _FrequencySegment({required this.selected, required this.onChanged});
  final RecurringFrequency selected;
  final ValueChanged<RecurringFrequency> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? _darkInput
          : const Color(0xFFEEF1F0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (final frequency in RecurringFrequency.values)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onChanged(frequency),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected == frequency ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  _frequencyLabel(frequency),
                  style: _body(context, 13).copyWith(
                    color: selected == frequency
                        ? Colors.white
                        : Theme.of(context).brightness == Brightness.dark
                        ? _darkSecondaryText
                        : _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _PostingModeCard extends StatelessWidget {
  const _PostingModeCard({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = dark ? _darkPositive : _primary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: dark
              ? selected
                    ? const Color(0xFF0D3028)
                    : _darkInput
              : selected
              ? const Color(0xFFEAF8F3)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? selectedColor
                : dark
                ? _darkBorder
                : const Color(0xFFE0E7E3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: selected
                        ? selectedColor
                        : dark
                        ? _darkSecondaryText
                        : _muted,
                    size: 20,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _body(context, 12).copyWith(
                      color: selected ? selectedColor : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: selectedColor,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: Theme.of(context).brightness == Brightness.dark
              ? _darkSecondaryText
              : _muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: _body(context, 15, muted: true).copyWith(
              color: _detailSecondaryColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: _body(
              context,
              15,
            ).copyWith(color: valueColor, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    decoration: BoxDecoration(
      border: showDivider
          ? Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? _darkBorder
                    : _outline.withValues(alpha: .35),
              ),
            )
          : null,
    ),
    child: Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: Theme.of(context).brightness == Brightness.dark
              ? _darkSecondaryText
              : _muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: _body(context, 15, muted: true).copyWith(
              color: _detailSecondaryColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: _body(context, 15).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 21,
  });
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: color, size: iconSize),
  );
}

BoxDecoration _cardDecoration(BuildContext context, {double radius = 16}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? _darkCard : Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: dark ? _darkBorder : const Color(0xFFE3ECE8)),
    boxShadow: dark
        ? null
        : [
            BoxShadow(
              color: _primary.withValues(alpha: .055),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
  );
}

BoxDecoration _hubElevatedCardDecoration(
  BuildContext context, {
  required double radius,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? _darkCard : Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: dark ? _darkBorder : const Color(0xFFD5E9E1)),
    boxShadow: dark
        ? null
        : [
            BoxShadow(
              color: _primary.withValues(alpha: .13),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
  );
}

TextStyle _headline(BuildContext context, double size) => TextStyle(
  fontFamily: _headlineFont,
  fontSize: size,
  fontWeight: FontWeight.w700,
  color: Theme.of(context).brightness == Brightness.dark ? _darkText : _ink,
);

TextStyle _body(BuildContext context, double size, {bool muted = false}) =>
    TextStyle(
      fontFamily: _bodyFont,
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: muted
          ? (Theme.of(context).brightness == Brightness.dark
                ? _darkMutedText
                : _muted)
          : (Theme.of(context).brightness == Brightness.dark
                ? _darkText
                : _ink),
    );

Color _detailSecondaryColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? _darkSecondaryText
    : const Color(0xFF455B54);

ButtonStyle _sheetOutlineStyle() => OutlinedButton.styleFrom(
  foregroundColor: _primary,
  side: const BorderSide(color: _outline),
  minimumSize: const Size(0, 48),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: const TextStyle(
    fontFamily: _bodyFont,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  ),
);

String _walletName(String? walletId) {
  final wallet = WalletService.instance.byId(walletId);
  if (wallet == null) return AppStrings.choose('Not selected', 'Chưa chọn');
  return wallet.name;
}

String _scheduleRule(RecurringSchedule schedule) {
  switch (schedule.frequency) {
    case RecurringFrequency.daily:
      return AppStrings.choose('Every day', 'Mỗi ngày');
    case RecurringFrequency.weekly:
      return AppStrings.choose(
        'Every ${_weekdayName(schedule.nextOccurrence.weekday)}',
        'Mỗi ${_weekdayNameVi(schedule.nextOccurrence.weekday)}',
      );
    case RecurringFrequency.monthly:
      return schedule.useLastDay
          ? AppStrings.choose('Last day monthly', 'Ngày cuối mỗi tháng')
          : AppStrings.choose(
              'Monthly · Day ${schedule.nextOccurrence.day}',
              'Hàng tháng · Ngày ${schedule.nextOccurrence.day}',
            );
  }
}

String _frequencyLabel(RecurringFrequency frequency) => switch (frequency) {
  RecurringFrequency.daily => AppStrings.choose('Daily', 'Hàng ngày'),
  RecurringFrequency.weekly => AppStrings.choose('Weekly', 'Hàng tuần'),
  RecurringFrequency.monthly => AppStrings.choose('Monthly', 'Hàng tháng'),
};

bool _sameCalendarDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _hubDueLabel(DateTime date) {
  final days = _daysUntil(date);
  if (days == 0) return AppStrings.choose('Today', 'Hôm nay');
  if (days == -1) return AppStrings.choose('Yesterday', 'Hôm qua');
  if (days < -1) return _monthDay(date);
  if (days == 1) return AppStrings.choose('Tomorrow', 'Ngày mai');
  if (days < 7) return AppStrings.choose('In $days days', 'Sau $days ngày');
  return _monthDay(date);
}

String _hubDateGroupLabel(DateTime date) {
  final days = _daysUntil(date);
  if (days == 0) return AppStrings.choose('TODAY', 'HÔM NAY');
  if (days == -1) return AppStrings.choose('YESTERDAY', 'HÔM QUA');
  if (days < -1) return _monthDay(date).toUpperCase();
  if (days == 1) return AppStrings.choose('TOMORROW', 'NGÀY MAI');
  return _monthDay(date).toUpperCase();
}

String _signedMoney(int value) =>
    '${value > 0
        ? '+'
        : value < 0
        ? '-'
        : ''}${_money(value.abs())}';

String _money(int value, {bool withCurrency = true}) {
  final formatted = _digits(value);
  return withCurrency ? '$formatted VND' : formatted;
}

String _digits(int value) {
  final raw = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(',');
    buffer.write(raw[index]);
  }
  return buffer.toString();
}

String _fullDate(DateTime date) =>
    '${_monthName(date.month)} ${date.day}, ${date.year}';
String _monthDay(DateTime date) => '${_monthName(date.month)} ${date.day}';
String _monthName(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
String _weekdayName(int weekday) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][weekday - 1];
String _weekdayNameVi(int weekday) => const [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
][weekday - 1];

int _daysUntil(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(today).inDays;
}

class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final value = int.tryParse(digits);
    if (value == null) return oldValue;
    final formatted = _digits(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
