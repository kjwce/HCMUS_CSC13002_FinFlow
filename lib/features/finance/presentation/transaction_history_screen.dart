import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../app/shell/bottom_nav_bar.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/services/auth_service.dart';
import '../models/transaction_category.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/transaction_service.dart';
import '../services/wallet_service.dart';
import 'add_transaction_sheet.dart';
import 'edit_transaction_screen.dart';

enum _HistoryFilter { all, income, expense }

enum _HistoryPeriod { daily, weekly, monthly, custom }

enum _HistorySort { newest, oldest, highestAmount, lowestAmount }

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  static const _headlineFont = 'Manrope';
  static const _bodyFont = 'Hanken Grotesk';
  static const _incomeColor = Color(0xFF00513E);
  static const _expenseColor = Color(0xFFBA1A1A);
  static const _darkBackground = Color(0xFF081C18);
  static const _darkBorder = Color(0xFF29483F);
  static const _darkTextPrimary = Color(0xFFF4FBF8);
  static const _darkTextSecondary = Color(0xFFA9C1B9);
  static const _darkAccent = Color(0xFF38D6AC);
  static const _darkExpense = Color(0xFFFF6B74);
  static const _darkSurface = Color(0xFF112622);
  static const _darkCard = Color(0xFF16352E);
  static const _darkSurfaceDeep = Color(0xFF0A241F);
  static const _darkBrand = Color(0xFF006C53);

  _HistoryFilter _filter = _HistoryFilter.all;
  _HistoryPeriod _period = _HistoryPeriod.monthly;
  DateTime _periodAnchor = DateTime.now();
  DateTimeRange? _dateRange;
  final Set<String> _categoryFilters = {};
  final Set<WalletType> _walletTypeFilters = {};
  int? _minimumAmount;
  int? _maximumAmount;
  _HistorySort _sort = _HistorySort.newest;
  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;
  bool _isSavingWeeklyBudget = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _primaryText =>
      _isDark ? _darkTextPrimary : context.finFlowColors.primaryText;
  Color get _secondaryText =>
      _isDark ? _darkTextSecondary : context.finFlowColors.secondaryText;
  Color get _surface => _isDark ? _darkSurface : context.finFlowColors.surface;
  Color get _cardSurface => _isDark ? _darkCard : context.finFlowColors.surface;
  Color get _controlSurface =>
      _isDark ? _darkSurfaceDeep : context.finFlowColors.elevatedSurface;
  Color get _border =>
      _isDark ? _darkBorder : context.finFlowColors.inputBorder;
  Color get _brand => _isDark ? _darkBrand : AppColors.deepEmerald;
  Color get _accent => _isDark ? _darkAccent : AppColors.deepEmerald;

  @override
  void initState() {
    super.initState();
    TransactionService.instance.addListener(_onDataChanged);
    WalletService.instance.addListener(_onDataChanged);
    Future.microtask(() {
      ref
          .read(transactionServiceProvider)
          .fetchTransactions()
          .catchError((e) => debugPrint('fetchTransactions error: $e'));
      ref
          .read(walletServiceProvider)
          .fetchWallets()
          .catchError((e) => debugPrint('fetchWallets error: $e'));
    });
  }

  @override
  void dispose() {
    TransactionService.instance.removeListener(_onDataChanged);
    WalletService.instance.removeListener(_onDataChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(transactionServiceProvider);
    final visibleTransactions = _filteredTransactions(ts);
    final grouped = _groupByDay(visibleTransactions);

    return Scaffold(
      backgroundColor: _isDark
          ? _darkBackground
          : context.finFlowColors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            if (_searchOpen) _buildSearchField(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.w(context, 20),
                Responsive.h(context, 8),
                Responsive.w(context, 20),
                Responsive.h(context, 8),
              ),
              child: _buildCompactFilterToolbar(),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(context, 20),
                  Responsive.h(context, 6),
                  Responsive.w(context, 20),
                  Responsive.h(context, 24),
                ),
                children: [
                  _buildSectionTitle(visibleTransactions.length),
                  SizedBox(height: Responsive.h(context, 10)),
                  if (grouped.isEmpty)
                    _buildEmptyState()
                  else
                    ...grouped.entries.map(_buildDayGroup),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: 0,
        onTabChanged: (index) => Navigator.of(context).pop(index),
        onAddTap: () => AddTransactionSheet.show(context),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Responsive.w(context, 12),
        Responsive.h(context, 8),
        Responsive.w(context, 20),
        Responsive.h(context, 6),
      ),
      decoration: _isDark
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: _darkBorder)),
            )
          : null,
      child: Row(
        children: [
          IconButton(
            tooltip: AppStrings.choose('Back', 'Quay lại'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: _isDark ? _darkTextPrimary : AppColors.deepEmerald,
          ),
          Expanded(
            child: Text(
              AppStrings.choose('Transaction History', 'Lịch sử giao dịch'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _headlineFont,
                fontSize: Responsive.sp(context, 22),
                fontWeight: FontWeight.w700,
                color: _isDark ? _darkTextPrimary : AppColors.deepEmerald,
              ),
            ),
          ),
          IconButton(
            tooltip: _searchOpen
                ? AppStrings.choose('Close search', 'Đóng tìm kiếm')
                : AppStrings.choose('Search transactions', 'Tìm giao dịch'),
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) _searchController.clear();
              });
            },
            icon: Icon(
              _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            ),
            color: _isDark ? _darkTextPrimary : AppColors.darkText,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 20)),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: AppStrings.choose('Search transactions', 'Tìm giao dịch'),
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: _surface,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFilterToolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.choose('Period', 'Thời gian'),
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 14),
            fontWeight: FontWeight.w600,
            color: _secondaryText,
          ),
        ),
        SizedBox(height: Responsive.h(context, 10)),
        Row(
          children: [
            Expanded(
              child: Container(
                height: Responsive.h(context, 40),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _controlSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: _isDark ? Border.all(color: _darkBorder) : null,
                ),
                child: Row(
                  children: [
                    _periodSegment(AppStrings.daily, _HistoryPeriod.daily),
                    _periodSegment(AppStrings.weekly, _HistoryPeriod.weekly),
                    _periodSegment(AppStrings.monthly, _HistoryPeriod.monthly),
                  ],
                ),
              ),
            ),
            SizedBox(width: Responsive.w(context, 10)),
            _calendarButton(),
          ],
        ),
        SizedBox(height: Responsive.h(context, 10)),
        Container(
          height: Responsive.h(context, 46),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDark
                  ? _darkBorder
                  : Colors.black.withValues(alpha: .05),
            ),
            boxShadow: _isDark
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: AppStrings.choose('Previous period', 'Kỳ trước'),
                onPressed: _period == _HistoryPeriod.custom
                    ? null
                    : () => _movePeriod(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                color: _accent,
              ),
              Expanded(
                child: Text(
                  _periodLabel(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 14),
                    fontWeight: FontWeight.w700,
                    color: _primaryText,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppStrings.choose('Next period', 'Kỳ sau'),
                onPressed: _period == _HistoryPeriod.custom || !_canMoveNext
                    ? null
                    : () => _movePeriod(1),
                icon: const Icon(Icons.chevron_right_rounded),
                color: _accent,
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.h(context, 18)),
        Text(
          AppStrings.choose('Transaction Type', 'Loại giao dịch'),
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 14),
            fontWeight: FontWeight.w600,
            color: _secondaryText,
          ),
        ),
        SizedBox(height: Responsive.h(context, 8)),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _typeTab(
                    AppStrings.choose('All', 'Tất cả'),
                    _HistoryFilter.all,
                  ),
                  SizedBox(width: Responsive.w(context, 8)),
                  _typeTab(AppStrings.income, _HistoryFilter.income),
                  SizedBox(width: Responsive.w(context, 8)),
                  _typeTab(AppStrings.expense, _HistoryFilter.expense),
                ],
              ),
            ),
            SizedBox(width: Responsive.w(context, 8)),
            _advancedFilterButton(),
          ],
        ),
        if (_advancedFilterCount > 0) ...[
          SizedBox(height: Responsive.h(context, 9)),
          _buildActiveFilterChips(),
        ],
      ],
    );
  }

  Widget _periodSegment(String label, _HistoryPeriod period) {
    final selected = _period == period;
    return Expanded(
      child: Material(
        color: selected ? _brand : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: () => setState(() {
            _period = period;
            _periodAnchor = DateTime.now();
          }),
          borderRadius: BorderRadius.circular(9),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 10),
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendarButton() {
    final selected = _period == _HistoryPeriod.custom;
    return Semantics(
      button: true,
      selected: selected,
      label: AppStrings.choose('Custom date range', 'Khoảng ngày tùy chọn'),
      child: Material(
        color: selected ? _brand : _surface,
        shape: CircleBorder(
          side: BorderSide(color: selected ? _brand : _border),
        ),
        child: InkWell(
          onTap: _pickDateRange,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: Responsive.w(context, 44),
            child: Icon(
              Icons.calendar_month_outlined,
              size: Responsive.w(context, 19),
              color: selected ? Colors.white : _accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeTab(String label, _HistoryFilter filter) {
    final selected = _filter == filter;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = filter),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: Responsive.h(context, 38),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _brand : _surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? _brand : _border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: Responsive.sp(context, 12),
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? Colors.white : _secondaryText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _advancedFilterButton() {
    return Semantics(
      button: true,
      label: AppStrings.choose('Advanced filters', 'Bộ lọc nâng cao'),
      child: SizedBox.square(
        dimension: Responsive.w(context, 44),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: _surface,
                shape: CircleBorder(side: BorderSide(color: _border)),
                child: InkWell(
                  onTap: _showAdvancedFilterDialog,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: _isDark ? _darkTextPrimary : AppColors.deepEmerald,
                  ),
                ),
              ),
            ),
            if (_advancedFilterCount > 0)
              Positioned(
                top: -5,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: const BoxDecoration(
                    color: AppColors.deepEmerald,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_advancedFilterCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int get _advancedFilterCount {
    var count = 0;
    if (_categoryFilters.isNotEmpty) count++;
    if (_walletTypeFilters.isNotEmpty) count++;
    if (_minimumAmount != null || _maximumAmount != null) count++;
    if (_sort != _HistorySort.newest) count++;
    return count;
  }

  bool get _canMoveNext {
    final now = DateTime.now();
    final next = switch (_period) {
      _HistoryPeriod.daily => _periodAnchor.add(const Duration(days: 1)),
      _HistoryPeriod.weekly => _periodAnchor.add(const Duration(days: 7)),
      _HistoryPeriod.monthly => DateTime(
        _periodAnchor.year,
        _periodAnchor.month + 1,
        1,
      ),
      _HistoryPeriod.custom => _periodAnchor,
    };
    final nextDay = DateTime(next.year, next.month, next.day);
    final today = DateTime(now.year, now.month, now.day);
    return !nextDay.isAfter(today);
  }

  void _movePeriod(int direction) {
    setState(() {
      _periodAnchor = switch (_period) {
        _HistoryPeriod.daily => _periodAnchor.add(Duration(days: direction)),
        _HistoryPeriod.weekly => _periodAnchor.add(
          Duration(days: 7 * direction),
        ),
        _HistoryPeriod.monthly => DateTime(
          _periodAnchor.year,
          _periodAnchor.month + direction,
          1,
        ),
        _HistoryPeriod.custom => _periodAnchor,
      };
    });
  }

  DateTimeRange _activePeriodRange() {
    final anchor = DateTime(
      _periodAnchor.year,
      _periodAnchor.month,
      _periodAnchor.day,
    );
    return switch (_period) {
      _HistoryPeriod.daily => DateTimeRange(start: anchor, end: anchor),
      _HistoryPeriod.weekly => () {
        final monday = anchor.subtract(
          Duration(days: anchor.weekday - DateTime.monday),
        );
        return DateTimeRange(
          start: monday,
          end: monday.add(const Duration(days: 6)),
        );
      }(),
      _HistoryPeriod.monthly => DateTimeRange(
        start: DateTime(anchor.year, anchor.month, 1),
        end: DateTime(anchor.year, anchor.month + 1, 0),
      ),
      _HistoryPeriod.custom =>
        _dateRange ?? DateTimeRange(start: anchor, end: anchor),
    };
  }

  String _periodLabel() {
    final range = _activePeriodRange();
    return switch (_period) {
      _HistoryPeriod.daily =>
        _isToday(range.start)
            ? AppStrings.isVietnamese
                  ? 'Hôm nay, ${range.start.day} ${_monthName(range.start.month)}'
                  : 'Today, ${_monthName(range.start.month)} ${range.start.day}'
            : AppStrings.isVietnamese
            ? '${range.start.day} ${_monthName(range.start.month)}, ${range.start.year}'
            : '${_monthName(range.start.month)} ${range.start.day}, ${range.start.year}',
      _HistoryPeriod.weekly =>
        AppStrings.isVietnamese
            ? '${range.start.day} ${_monthName(range.start.month)} – ${range.end.day} ${_monthName(range.end.month)}'
            : '${_monthName(range.start.month)} ${range.start.day} – ${_monthName(range.end.month)} ${range.end.day}',
      _HistoryPeriod.monthly =>
        '${_fullMonthName(range.start.month)} ${range.start.year}',
      _HistoryPeriod.custom =>
        AppStrings.isVietnamese
            ? '${range.start.day} ${_monthName(range.start.month)} – ${range.end.day} ${_monthName(range.end.month)}, ${range.end.year}'
            : '${_monthName(range.start.month)} ${range.start.day} – ${_monthName(range.end.month)} ${range.end.day}, ${range.end.year}',
    };
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];
    for (final category in _categoryFilters) {
      chips.add(
        _activeFilterChip(
          AppStrings.categoryName(TransactionCategory.resolve(category).label),
          () => setState(() => _categoryFilters.remove(category)),
        ),
      );
    }
    for (final walletType in _walletTypeFilters) {
      chips.add(
        _activeFilterChip(
          walletType == WalletType.cash
              ? AppStrings.choose('Cash', 'Tiền mặt')
              : AppStrings.choose('Bank Transfer', 'Chuyển khoản ngân hàng'),
          () => setState(() => _walletTypeFilters.remove(walletType)),
        ),
      );
    }
    if (_minimumAmount != null || _maximumAmount != null) {
      final minimum = _minimumAmount;
      final maximum = _maximumAmount;
      final label = minimum != null && maximum != null
          ? '${_formatPlainMoney(minimum)}–${_formatPlainMoney(maximum)}'
          : minimum != null
          ? AppStrings.choose(
              'From ${_formatPlainMoney(minimum)}',
              'Từ ${_formatPlainMoney(minimum)}',
            )
          : AppStrings.choose(
              'Under ${_formatPlainMoney(maximum!)}',
              'Dưới ${_formatPlainMoney(maximum)}',
            );
      chips.add(
        _activeFilterChip(
          label,
          () => setState(() {
            _minimumAmount = null;
            _maximumAmount = null;
          }),
        ),
      );
    }
    if (_sort != _HistorySort.newest) {
      chips.add(
        _activeFilterChip(
          _sort.label,
          () => setState(() => _sort = _HistorySort.newest),
        ),
      );
    }

    return SizedBox(
      height: Responsive.h(context, 32),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length + 1,
        separatorBuilder: (_, _) => SizedBox(width: Responsive.w(context, 6)),
        itemBuilder: (context, index) {
          if (index == chips.length) {
            return TextButton(
              onPressed: _clearAdvancedFilters,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(context, 8),
                ),
              ),
              child: Text(AppStrings.choose('Clear all', 'Xóa tất cả')),
            );
          }
          return chips[index];
        },
      ),
    );
  }

  Widget _activeFilterChip(String label, VoidCallback onDeleted) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close_rounded, size: 15),
      backgroundColor: _isDark ? _darkSurface : const Color(0xFFE3F5ED),
      side: BorderSide(
        color: _isDark
            ? _darkBorder
            : AppColors.deepEmerald.withValues(alpha: .18),
      ),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontFamily: _bodyFont,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: _isDark ? _darkAccent : AppColors.deepEmerald,
      ),
    );
  }

  void _clearAdvancedFilters() {
    setState(() {
      _categoryFilters.clear();
      _walletTypeFilters.clear();
      _minimumAmount = null;
      _maximumAmount = null;
      _sort = _HistorySort.newest;
    });
  }

  Future<void> _showAdvancedFilterDialog() async {
    final result = await showDialog<_AdvancedFilters>(
      context: context,
      barrierColor: _isDark
          ? Colors.black.withValues(alpha: .7)
          : const Color(0xFF002D22).withValues(alpha: .48),
      builder: (context) => _TransactionAdvancedFilterDialog(
        initial: _AdvancedFilters(
          categories: _categoryFilters,
          walletTypes: _walletTypeFilters,
          minimumAmount: _minimumAmount,
          maximumAmount: _maximumAmount,
          sort: _sort,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _categoryFilters
        ..clear()
        ..addAll(result.categories);
      _walletTypeFilters
        ..clear()
        ..addAll(result.walletTypes);
      _minimumAmount = result.minimumAmount;
      _maximumAmount = result.maximumAmount;
      _sort = result.sort;
    });
  }

  // Kept temporarily for visual rollback while the compact toolbar is tested.
  // ignore: unused_element
  Widget _buildFilterRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _filterChip(
                AppStrings.choose('All', 'Tất cả'),
                _HistoryFilter.all,
              ),
            ),
            SizedBox(width: Responsive.w(context, 8)),
            Expanded(
              child: _filterChip(AppStrings.income, _HistoryFilter.income),
            ),
            SizedBox(width: Responsive.w(context, 8)),
            Expanded(
              child: _filterChip(AppStrings.expense, _HistoryFilter.expense),
            ),
          ],
        ),
        SizedBox(height: Responsive.h(context, 10)),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDateRange,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkText,
                  side: BorderSide(
                    color: _dateRange == null
                        ? AppColors.borderGray
                        : AppColors.primaryGreen,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 12),
                    vertical: Responsive.h(context, 12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  Icons.date_range_rounded,
                  size: Responsive.w(context, 18),
                ),
                label: Text(
                  _dateRangeLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (_dateRange != null) ...[
              SizedBox(width: Responsive.w(context, 8)),
              IconButton.filledTonal(
                tooltip: AppStrings.choose(
                  'Clear date range',
                  'Xóa khoảng ngày',
                ),
                onPressed: () => setState(() => _dateRange = null),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, _HistoryFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: Responsive.h(context, 42),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : AppColors.borderGray,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 13),
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.darkText,
          ),
        ),
      ),
    );
  }

  // Kept temporarily for visual rollback; these insights now live on Home.
  // ignore: unused_element
  Widget _buildQuickInsights(TransactionService ts) {
    return Row(
      children: [
        Expanded(child: _buildWeeklySpendingCard(ts)),
        SizedBox(width: Responsive.w(context, 12)),
        Expanded(child: _buildTopCategoryCard(ts)),
      ],
    );
  }

  Widget _buildWeeklySpendingCard(TransactionService ts) {
    final values = _weeklyExpenseValues(ts);
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final weeklyBudget = AuthService.instance.weeklyBudget;
    final hasBudget = weeklyBudget > 0;
    final budgetUsage = hasBudget ? total / weeklyBudget : 0.0;
    final progress = budgetUsage.clamp(0.0, 1.0).toDouble();

    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 14)),
      decoration: BoxDecoration(
        color: AppColors.deepEmerald,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepEmerald.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.choose('Weekly Spending', 'Chi tiêu hàng tuần'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: Responsive.sp(context, 12),
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          SizedBox(height: Responsive.h(context, 6)),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                _formatMoneyCompact(total),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 20),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: Responsive.h(context, 14)),
          if (hasBudget) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: Responsive.h(context, 5),
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(height: Responsive.h(context, 8)),
            Text(
              AppStrings.choose(
                '${(budgetUsage * 100).clamp(0, 999).toStringAsFixed(0)}% of ${_formatMoneyCompact(weeklyBudget)}',
                '${(budgetUsage * 100).clamp(0, 999).toStringAsFixed(0)}% của ${_formatMoneyCompact(weeklyBudget)}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 10),
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: Responsive.h(context, 32),
              child: OutlinedButton.icon(
                onPressed: _isSavingWeeklyBudget
                    ? null
                    : _showWeeklyBudgetDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.w(context, 8),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: Icon(Icons.add_rounded, size: Responsive.w(context, 15)),
                label: Text(
                  AppStrings.choose('Set budget', 'Đặt ngân sách'),
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopCategoryCard(TransactionService ts) {
    final category = _topMonthlyExpenseCategory(ts);
    final cat = TransactionCategory.resolve(category?.key ?? 'Other');
    return _insightCard(
      title: AppStrings.choose('Top Category', 'Danh mục cao nhất'),
      value: category == null
          ? AppStrings.choose('No expense', 'Không có chi tiêu')
          : AppStrings.categoryName(cat.label),
      leading: Container(
        width: Responsive.w(context, 38),
        height: Responsive.w(context, 38),
        decoration: BoxDecoration(
          color: cat.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: cat.buildIcon(size: Responsive.w(context, 20)),
      ),
      child: Text(
        category == null
            ? AppStrings.choose(
                'This month is clear',
                'Tháng này chưa có chi tiêu',
              )
            : _formatMoneyCompact(category.value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: _bodyFont,
          fontSize: Responsive.sp(context, 12),
          color: AppColors.mutedGray,
        ),
      ),
    );
  }

  Widget _insightCard({
    required String title,
    required String value,
    required Widget child,
    Widget? leading,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(context, 14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading,
                SizedBox(width: Responsive.w(context, 8)),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _bodyFont,
                    fontSize: Responsive.sp(context, 12),
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedGray,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(context, 6)),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: _headlineFont,
                  fontSize: Responsive.sp(context, 17),
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),
            ),
          ),
          SizedBox(height: Responsive.h(context, 8)),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionTitle(int count) {
    return Container(
      padding: EdgeInsets.only(bottom: Responsive.h(context, 8)),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _isDark ? _darkBorder : context.finFlowColors.divider,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.choose('Transactions', 'Giao dịch'),
              style: TextStyle(
                fontFamily: _headlineFont,
                fontSize: Responsive.sp(context, 18),
                fontWeight: FontWeight.w700,
                color: _primaryText,
              ),
            ),
          ),
          Text(
            AppStrings.choose('$count items', '$count mục'),
            style: TextStyle(
              fontFamily: _bodyFont,
              fontSize: Responsive.sp(context, 12),
              fontWeight: FontWeight.w600,
              color: _secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(context, 34)),
      decoration: BoxDecoration(
        color: _cardSurface,
        border: _isDark ? Border.all(color: _darkBorder) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          AppStrings.choose(
            'No transactions match this filter.',
            'Không có giao dịch nào phù hợp với bộ lọc.',
          ),
          style: TextStyle(
            fontFamily: _bodyFont,
            fontSize: Responsive.sp(context, 14),
            color: _secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildDayGroup(MapEntry<DateTime, List<TransactionModel>> group) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.h(context, 18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: Responsive.h(context, 8)),
            child: Text(
              _dayHeader(group.key).toUpperCase(),
              style: TextStyle(
                fontFamily: _bodyFont,
                fontSize: Responsive.sp(context, 11),
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
                color: _secondaryText,
              ),
            ),
          ),
          Column(
            children: group.value.asMap().entries.map((entry) {
              return Column(
                children: [
                  _buildTransactionRow(entry.value),
                  if (entry.key != group.value.length - 1)
                    SizedBox(height: Responsive.h(context, 10)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(TransactionModel tx) {
    final cat = TransactionCategory.resolve(tx.category);
    final isIncome = tx.amount > 0;
    final wallet = WalletService.instance.byId(tx.walletId);
    final method = _walletLabel(wallet);

    return Container(
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: _isDark ? Border.all(color: _darkBorder) : null,
        boxShadow: _isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1400523C),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditTransactionScreen(transaction: tx),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(context, 12),
              vertical: Responsive.h(context, 12),
            ),
            child: Row(
              children: [
                Container(
                  width: Responsive.w(context, 40),
                  height: Responsive.w(context, 40),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: .13),
                    shape: BoxShape.circle,
                  ),
                  child: cat.buildIcon(size: Responsive.w(context, 20)),
                ),
                SizedBox(width: Responsive.w(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: Responsive.sp(context, 13),
                          fontWeight: FontWeight.w700,
                          color: _primaryText,
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 3)),
                      Text(
                        '${_timeLabel(tx.date)} - $method',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: Responsive.sp(context, 10),
                          fontWeight: FontWeight.w600,
                          color: _secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: Responsive.w(context, 10)),
                SizedBox(
                  width: Responsive.w(context, 112),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatSignedMoney(tx.amount),
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: _headlineFont,
                            fontSize: Responsive.sp(context, 14),
                            fontWeight: FontWeight.w800,
                            color: isIncome
                                ? (_isDark ? _darkAccent : _incomeColor)
                                : (_isDark ? _darkExpense : _expenseColor),
                          ),
                        ),
                      ),
                      SizedBox(height: Responsive.h(context, 4)),
                      Text(
                        AppStrings.categoryName(cat.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: _bodyFont,
                          fontSize: Responsive.sp(context, 11),
                          fontWeight: FontWeight.w400,
                          color: _secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial =
        _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: context.finFlowColors.dialogBackground,
              onSurface: context.finFlowColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _period = _HistoryPeriod.custom;
        _periodAnchor = picked.end;
      });
    }
  }

  Future<void> _showWeeklyBudgetDialog() async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          const SafeArea(top: false, child: _WeeklyBudgetSheet()),
    );

    if (amount == null || !mounted) return;
    setState(() => _isSavingWeeklyBudget = true);
    try {
      final user = AuthService.instance.currentUser;
      await AuthService.instance.updateProfile(
        fullName:
            user?.fullName ??
            AppStrings.choose('New FinFlow User', 'Người dùng FinFlow mới'),
        weeklyBudget: amount,
      );
      if (!mounted) return;
      setState(() => _isSavingWeeklyBudget = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingWeeklyBudget = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.choose(
              'Failed to save weekly budget: $e',
              'Không thể lưu ngân sách tuần: $e',
            ),
          ),
        ),
      );
    }
  }

  List<TransactionModel> _filteredTransactions(TransactionService ts) {
    final activeRange = _activePeriodRange();
    final start = DateTime(
      activeRange.start.year,
      activeRange.start.month,
      activeRange.start.day,
    );
    final end = DateTime(
      activeRange.end.year,
      activeRange.end.month,
      activeRange.end.day,
      23,
      59,
      59,
      999,
    );
    final query = _searchController.text.trim().toLowerCase();
    final txs = ts.currentUserTransactions.where((tx) {
      final typeMatch = switch (_filter) {
        _HistoryFilter.all => true,
        _HistoryFilter.income => tx.amount > 0,
        _HistoryFilter.expense => tx.amount < 0,
      };
      if (!typeMatch) return false;
      if (tx.date.isBefore(start) || tx.date.isAfter(end)) return false;
      if (query.isNotEmpty &&
          !tx.name.toLowerCase().contains(query) &&
          !tx.category.toLowerCase().contains(query)) {
        return false;
      }
      if (_categoryFilters.isNotEmpty &&
          !_categoryFilters.contains(tx.category)) {
        return false;
      }
      if (_walletTypeFilters.isNotEmpty) {
        final wallet = WalletService.instance.byId(tx.walletId);
        if (wallet == null || !_walletTypeFilters.contains(wallet.type)) {
          return false;
        }
      }
      final absoluteAmount = tx.amount.abs();
      final minimum = _minimumAmount;
      if (minimum != null && absoluteAmount < minimum) {
        return false;
      }
      final maximum = _maximumAmount;
      if (maximum != null && absoluteAmount > maximum) {
        return false;
      }
      return true;
    }).toList();
    txs.sort(switch (_sort) {
      _HistorySort.newest => (a, b) => b.date.compareTo(a.date),
      _HistorySort.oldest => (a, b) => a.date.compareTo(b.date),
      _HistorySort.highestAmount => (a, b) => b.amount.abs().compareTo(
        a.amount.abs(),
      ),
      _HistorySort.lowestAmount => (a, b) => a.amount.abs().compareTo(
        b.amount.abs(),
      ),
    });
    return txs;
  }

  Map<DateTime, List<TransactionModel>> _groupByDay(
    List<TransactionModel> txs,
  ) {
    final grouped = <DateTime, List<TransactionModel>>{};
    for (final tx in txs) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(day, () => []).add(tx);
    }
    final entries = grouped.entries.toList();
    if (_sort == _HistorySort.oldest) {
      entries.sort((a, b) => a.key.compareTo(b.key));
    } else {
      entries.sort((a, b) => b.key.compareTo(a.key));
    }
    if (_sort == _HistorySort.highestAmount ||
        _sort == _HistorySort.lowestAmount) {
      for (final entry in entries) {
        entry.value.sort((a, b) {
          final result = a.amount.abs().compareTo(b.amount.abs());
          return _sort == _HistorySort.highestAmount ? -result : result;
        });
      }
    }
    return {for (final entry in entries) entry.key: entry.value};
  }

  List<int> _weeklyExpenseValues(TransactionService ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final values = List<int>.filled(7, 0);
    for (final tx in ts.currentUserTransactions) {
      if (tx.amount >= 0) continue;
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final diff = day.difference(monday).inDays;
      if (diff >= 0 && diff < 7) {
        values[diff] += tx.amount.abs();
      }
    }
    return values;
  }

  MapEntry<String, int>? _topMonthlyExpenseCategory(TransactionService ts) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    final map = ts.expenseByCategoryBetween(start, end);
    if (map.isEmpty) return null;
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  String _dateRangeLabel() {
    final range = _dateRange;
    if (range == null) {
      return AppStrings.choose('Date range', 'Khoảng ngày');
    }
    return '${_shortDate(range.start)} - ${_shortDate(range.end)}';
  }

  String _dayHeader(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return AppStrings.choose('Today', 'Hôm nay');
    if (day == yesterday) return AppStrings.choose('Yesterday', 'Hôm qua');
    return AppStrings.isVietnamese
        ? '${day.day} ${_monthName(day.month)}, ${day.year}'
        : '${_monthName(day.month)} ${day.day}, ${day.year}';
  }

  String _walletLabel(WalletModel? wallet) {
    final name = wallet?.name ?? 'Transfer';
    return switch (name) {
      'Cash' => AppStrings.choose('Cash', 'Tiền mặt'),
      'Transfer' => AppStrings.choose('Transfer', 'Chuyển khoản'),
      _ => name,
    };
  }

  static String _formatSignedMoney(int amount) {
    final sign = amount < 0 ? '-' : '+';
    return '$sign ${_formatMoney(amount.abs())}';
  }

  static String _formatMoney(int amount) {
    final text = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '$text VND';
  }

  static String _addCommas(String digits) {
    final buffer = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  static String _formatMoneyCompact(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B VND';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M VND';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K VND';
    }
    return '$amount VND';
  }

  static String _timeLabel(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _shortDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  static String _formatPlainMoney(int amount) =>
      '${_addCommas(amount.toString())} VND';

  static String _monthName(int month) {
    final months = AppStrings.isVietnamese
        ? const [
            'Thg 1',
            'Thg 2',
            'Thg 3',
            'Thg 4',
            'Thg 5',
            'Thg 6',
            'Thg 7',
            'Thg 8',
            'Thg 9',
            'Thg 10',
            'Thg 11',
            'Thg 12',
          ]
        : const [
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
          ];
    return months[month - 1];
  }

  static String _fullMonthName(int month) {
    final months = AppStrings.isVietnamese
        ? const [
            'Tháng 1',
            'Tháng 2',
            'Tháng 3',
            'Tháng 4',
            'Tháng 5',
            'Tháng 6',
            'Tháng 7',
            'Tháng 8',
            'Tháng 9',
            'Tháng 10',
            'Tháng 11',
            'Tháng 12',
          ]
        : const [
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
    return months[month - 1];
  }
}

extension on _HistorySort {
  String get label => switch (this) {
    _HistorySort.newest => AppStrings.choose('Newest First', 'Mới nhất trước'),
    _HistorySort.oldest => AppStrings.choose('Oldest First', 'Cũ nhất trước'),
    _HistorySort.highestAmount => AppStrings.choose(
      'Highest Amount',
      'Số tiền cao nhất',
    ),
    _HistorySort.lowestAmount => AppStrings.choose(
      'Lowest Amount',
      'Số tiền thấp nhất',
    ),
  };
}

class _AdvancedFilters {
  const _AdvancedFilters({
    required this.categories,
    required this.walletTypes,
    required this.minimumAmount,
    required this.maximumAmount,
    required this.sort,
  });

  final Set<String> categories;
  final Set<WalletType> walletTypes;
  final int? minimumAmount;
  final int? maximumAmount;
  final _HistorySort sort;
}

class _TransactionAdvancedFilterDialog extends StatefulWidget {
  const _TransactionAdvancedFilterDialog({required this.initial});

  final _AdvancedFilters initial;

  @override
  State<_TransactionAdvancedFilterDialog> createState() =>
      _TransactionAdvancedFilterDialogState();
}

class _TransactionAdvancedFilterDialogState
    extends State<_TransactionAdvancedFilterDialog> {
  late final Set<String> _categories;
  late final Set<WalletType> _walletTypes;
  late final TextEditingController _minimumController;
  late final TextEditingController _maximumController;
  late _HistorySort _sort;

  @override
  void initState() {
    super.initState();
    _categories = {...widget.initial.categories};
    _walletTypes = {...widget.initial.walletTypes};
    _minimumController = TextEditingController(
      text: _formatInitial(widget.initial.minimumAmount),
    );
    _maximumController = TextEditingController(
      text: _formatInitial(widget.initial.maximumAmount),
    );
    _sort = widget.initial.sort;
  }

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  int? get _minimum => _parseAmount(_minimumController.text);
  int? get _maximum => _parseAmount(_maximumController.text);
  bool get _invalidRange =>
      _minimum != null && _maximum != null && _minimum! > _maximum!;

  @override
  Widget build(BuildContext context) {
    final colors = context.finFlowColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: Responsive.w(context, 16)),
      backgroundColor: colors.dialogBackground,
      elevation: isDark ? 0 : 18,
      shadowColor: const Color(0x66002D22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: isDark
            ? const BorderSide(
                color: _TransactionHistoryScreenState._darkBorder,
              )
            : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: screen.height * .74,
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.w(context, 20),
                Responsive.h(context, 17),
                Responsive.w(context, 10),
                Responsive.h(context, 12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.choose(
                            'Filter Transactions',
                            'Lọc giao dịch',
                          ),
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: Responsive.sp(context, 19),
                            fontWeight: FontWeight.w800,
                            color: colors.primaryText,
                          ),
                        ),
                        SizedBox(height: Responsive.h(context, 3)),
                        Text(
                          AppStrings.choose(
                            'Narrow down your transaction history',
                            'Thu hẹp lịch sử giao dịch của bạn',
                          ),
                          style: TextStyle(
                            fontFamily: 'Hanken Grotesk',
                            fontSize: Responsive.sp(context, 11),
                            color: colors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.choose('Close', 'Đóng'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.w(context, 20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(context, AppStrings.category),
                    SizedBox(height: Responsive.h(context, 8)),
                    Wrap(
                      spacing: Responsive.w(context, 7),
                      runSpacing: Responsive.h(context, 6),
                      children: TransactionCategory.all.map((category) {
                        final selected = _categories.contains(category.key);
                        return FilterChip(
                          selected: selected,
                          onSelected: (value) => setState(() {
                            value
                                ? _categories.add(category.key)
                                : _categories.remove(category.key);
                          }),
                          avatar: category.buildIcon(
                            size: 16,
                            color: selected
                                ? (isDark
                                      ? _TransactionHistoryScreenState
                                            ._darkAccent
                                      : AppColors.deepEmerald)
                                : category.color,
                          ),
                          label: Text(AppStrings.categoryName(category.label)),
                          selectedColor: isDark
                              ? _TransactionHistoryScreenState._darkSurfaceDeep
                              : const Color(0xFFE3F5ED),
                          side: BorderSide(
                            color: selected
                                ? (isDark
                                      ? _TransactionHistoryScreenState
                                            ._darkAccent
                                      : AppColors.deepEmerald)
                                : colors.inputBorder,
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                    SizedBox(height: Responsive.h(context, 18)),
                    _sectionHeader(context, AppStrings.choose('Wallet', 'Ví')),
                    SizedBox(height: Responsive.h(context, 8)),
                    Wrap(
                      spacing: Responsive.w(context, 8),
                      children: [
                        _walletChip(
                          context,
                          type: WalletType.cash,
                          label: AppStrings.choose('Cash', 'Tiền mặt'),
                          icon: Icons.payments_outlined,
                        ),
                        _walletChip(
                          context,
                          type: WalletType.transfer,
                          label: AppStrings.choose(
                            'Bank Transfer',
                            'Chuyển khoản ngân hàng',
                          ),
                          icon: Icons.account_balance_outlined,
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(context, 18)),
                    _sectionHeader(
                      context,
                      AppStrings.choose('Amount Range', 'Khoảng số tiền'),
                    ),
                    SizedBox(height: Responsive.h(context, 8)),
                    Row(
                      children: [
                        Expanded(
                          child: _amountField(
                            context,
                            controller: _minimumController,
                            label: AppStrings.choose('Minimum', 'Tối thiểu'),
                          ),
                        ),
                        SizedBox(width: Responsive.w(context, 9)),
                        Expanded(
                          child: _amountField(
                            context,
                            controller: _maximumController,
                            label: AppStrings.choose('Maximum', 'Tối đa'),
                          ),
                        ),
                      ],
                    ),
                    if (_invalidRange) ...[
                      SizedBox(height: Responsive.h(context, 5)),
                      Text(
                        AppStrings.choose(
                          'Minimum amount cannot exceed maximum amount.',
                          'Số tiền tối thiểu không thể lớn hơn số tiền tối đa.',
                        ),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFBA1A1A),
                        ),
                      ),
                    ],
                    SizedBox(height: Responsive.h(context, 8)),
                    Wrap(
                      spacing: Responsive.w(context, 6),
                      children: [
                        _amountPresetChip(
                          AppStrings.choose('Under 500K', 'Dưới 500K'),
                          null,
                          500000,
                        ),
                        _amountPresetChip('500K–2M', 500000, 2000000),
                        _amountPresetChip(
                          AppStrings.choose('Over 2M', 'Trên 2M'),
                          2000000,
                          null,
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(context, 18)),
                    _sectionHeader(
                      context,
                      AppStrings.choose('Sort By', 'Sắp xếp theo'),
                    ),
                    RadioGroup<_HistorySort>(
                      groupValue: _sort,
                      onChanged: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                      child: Column(
                        children: _HistorySort.values
                            .map(
                              (sort) => RadioListTile<_HistorySort>(
                                value: sort,
                                title: Text(
                                  sort.label,
                                  style: TextStyle(
                                    fontFamily: 'Hanken Grotesk',
                                    fontSize: Responsive.sp(context, 12),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                activeColor: isDark
                                    ? _TransactionHistoryScreenState._darkAccent
                                    : AppColors.deepEmerald,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: colors.divider),
            Padding(
              padding: EdgeInsets.all(Responsive.w(context, 14)),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _reset,
                    child: Text(AppStrings.choose('Reset', 'Đặt lại')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _invalidRange ? null : _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? _TransactionHistoryScreenState._darkBrand
                          : AppColors.deepEmerald,
                      foregroundColor: Colors.white,
                      minimumSize: Size(
                        Responsive.w(context, 132),
                        Responsive.h(context, 44),
                      ),
                    ),
                    child: Text(
                      AppStrings.choose('Apply Filters', 'Áp dụng bộ lọc'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: Responsive.sp(context, 13),
        fontWeight: FontWeight.w800,
        color: context.finFlowColors.primaryText,
      ),
    );
  }

  Widget _walletChip(
    BuildContext context, {
    required WalletType type,
    required String label,
    required IconData icon,
  }) {
    final selected = _walletTypes.contains(type);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FilterChip(
      selected: selected,
      onSelected: (value) => setState(() {
        value ? _walletTypes.add(type) : _walletTypes.remove(type);
      }),
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selectedColor: isDark
          ? _TransactionHistoryScreenState._darkSurfaceDeep
          : const Color(0xFFE3F5ED),
      side: BorderSide(
        color: selected
            ? (isDark
                  ? _TransactionHistoryScreenState._darkAccent
                  : AppColors.deepEmerald)
            : context.finFlowColors.inputBorder,
      ),
    );
  }

  Widget _amountField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: const [_ThousandsSeparatorFormatter()],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'VND',
        isDense: true,
        errorText: null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _amountPresetChip(String label, int? minimum, int? maximum) {
    final selected = _minimum == minimum && _maximum == maximum;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() {
        _minimumController.text = _formatInitial(minimum);
        _maximumController.text = _formatInitial(maximum);
      }),
      label: Text(label),
      selectedColor: isDark
          ? _TransactionHistoryScreenState._darkSurfaceDeep
          : const Color(0xFFE3F5ED),
      visualDensity: VisualDensity.compact,
    );
  }

  void _reset() {
    setState(() {
      _categories.clear();
      _walletTypes.clear();
      _minimumController.clear();
      _maximumController.clear();
      _sort = _HistorySort.newest;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      _AdvancedFilters(
        categories: {..._categories},
        walletTypes: {..._walletTypes},
        minimumAmount: _minimum,
        maximumAmount: _maximum,
        sort: _sort,
      ),
    );
  }

  static String _formatInitial(int? amount) {
    if (amount == null) return '';
    return _TransactionHistoryScreenState._addCommas(amount.toString());
  }

  static int? _parseAmount(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  const _ThousandsSeparatorFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = _TransactionHistoryScreenState._addCommas(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _WeeklyBudgetSheet extends StatefulWidget {
  const _WeeklyBudgetSheet();

  @override
  State<_WeeklyBudgetSheet> createState() => _WeeklyBudgetSheetState();
}

class _WeeklyBudgetSheetState extends State<_WeeklyBudgetSheet> {
  final _controller = TextEditingController();
  bool _isFormatting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_formatAmount);
  }

  @override
  void dispose() {
    _controller.removeListener(_formatAmount);
    _controller.dispose();
    super.dispose();
  }

  void _formatAmount() {
    if (_isFormatting) return;
    _isFormatting = true;
    final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      _controller.text = '';
    } else {
      final formatted = _TransactionHistoryScreenState._addCommas(digits);
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    _isFormatting = false;
  }

  void _save() {
    final raw = _controller.text.replaceAll(',', '');
    final value = int.tryParse(raw);
    if (value == null || value <= 0) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Responsive.w(context, 20),
          right: Responsive.w(context, 20),
          top: Responsive.h(context, 20),
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              Responsive.h(context, 20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.choose('Set weekly budget', 'Đặt ngân sách tuần'),
                style: TextStyle(
                  fontFamily: _TransactionHistoryScreenState._headlineFont,
                  fontSize: Responsive.sp(context, 18),
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              SizedBox(height: Responsive.h(context, 16)),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppStrings.choose(
                    'Weekly budget',
                    'Ngân sách tuần',
                  ),
                  suffixText: 'VND',
                ),
                onSubmitted: (_) => _save(),
              ),
              SizedBox(height: Responsive.h(context, 18)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(AppStrings.cancel),
                    ),
                  ),
                  SizedBox(width: Responsive.w(context, 10)),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(AppStrings.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
