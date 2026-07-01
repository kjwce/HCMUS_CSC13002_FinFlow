import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/i18n/app_language.dart';
import '../../core/widgets/notification_bell.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/finance/models/transaction_category.dart';
import '../../features/finance/presentation/dashboard.dart';
import '../../features/finance/presentation/edit_transaction_screen.dart';
import '../../features/finance/presentation/goal_setup_sheet.dart';
import '../../features/finance/providers/goal_provider.dart';
import '../../features/finance/providers/transaction_provider.dart';
import '../../features/finance/services/goal_service.dart';
import '../../features/finance/services/transaction_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onAddTap});

  final VoidCallback? onAddTap;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTab = 2; // Monthly

  @override
  void initState() {
    super.initState();
    // TransactionService is a ChangeNotifier but uses a plain Provider,
    // so we subscribe manually to rebuild the UI after data loads.
    TransactionService.instance.addListener(_onTransactionsChanged);
    GoalService.instance.addListener(_onTransactionsChanged);
    Future.microtask(() => ref.read(transactionServiceProvider).fetchTransactions());
    Future.microtask(() => ref.read(goalServiceProvider).fetchGoals());
  }

  @override
  void dispose() {
    TransactionService.instance.removeListener(_onTransactionsChanged);
    GoalService.instance.removeListener(_onTransactionsChanged);
    super.dispose();
  }

  void _onTransactionsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final ts = ref.watch(transactionServiceProvider);
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeaderAndBalance(ts),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildGoalSummaryCard(),
                const SizedBox(height: 25),
                _buildPeriodTabs(),
                const SizedBox(height: 25),
                _buildTransactionList(ts),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Header + Balance Card đè lên ảnh ---
  Widget _buildHeaderAndBalance(TransactionService ts) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Image
        Container(
          height: 280,
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/home_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.welcomeBack,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF052224),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _greeting(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF052224),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Chart icon — pushes to DashboardPage
                      GestureDetector(
                        onTap: _navigateToDashboard,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDFF7E2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 19,
                              height: 16,
                              child: SvgPicture.asset(
                                'assets/icons/chart.svg',
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF093030),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const NotificationBell(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Balance Card
        Positioned(
          top: 100,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildBalanceItem(
                      AppStrings.totalBalance,
                      _formatCompact(ts.totalBalance),
                      Icons.north_east,
                      Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                    Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 1.2)),
                    _buildBalanceItem(
                      AppStrings.totalExpenseLabel,
                      '-${_formatCompact(ts.monthlyExpense)}',
                      Icons.south_west,
                      const Color(0xFF0068FF),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Progress Bar
                _buildProgressBar(ts),
              ],
            ),
          ),
        ),
        // Expense message nằm riêng, chìm trong background
        Positioned(
          bottom: 5,
          left: 60,
          right: 0,
          child: Center(child: _buildExpenseMessage(ts)),
        ),
      ],
    );
  }

  Widget _buildProgressBar(TransactionService ts) {
    final authService = ref.watch(authServiceProvider);
    final budgetLimit = authService.currentUser?.budgetLimit ?? 0;
    final budgetRatio = budgetLimit > 0
        ? (ts.monthlyExpense / budgetLimit).clamp(0.0, 1.0)
        : 0.0;
    final rawPercent = budgetLimit > 0
        ? (ts.monthlyExpense / budgetLimit) * 100
        : 0.0;
    final displayPercent = (rawPercent.clamp(0.0, 100.0) * 10).round() / 10;

    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: const Color(0xFFF1FFF3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: budgetRatio > 0 ? budgetRatio : 0.05,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF011D1E),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                '${displayPercent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (budgetLimit > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 15),
                child: Text(
                  _formatCompact(budgetLimit),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Color(0xFF052224),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpenseMessage(TransactionService ts) {
    final authService = ref.watch(authServiceProvider);
    final budgetLimit = authService.currentUser?.budgetLimit ?? 0;
    final rawPercent = budgetLimit > 0
        ? (ts.monthlyExpense / budgetLimit) * 100
        : 0.0;
    final displayPercent = (rawPercent.clamp(0.0, 100.0) * 10).round() / 10;

    return Row(
      children: [
        Icon(
          budgetLimit <= 0
              ? Icons.info_outline
              : (rawPercent > 100 ? Icons.warning_amber : Icons.check_box_outlined),
          size: 18,
          color: budgetLimit <= 0
              ? Colors.grey
              : (rawPercent > 100 ? Colors.red : Colors.black54),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            budgetLimit <= 0
                ? 'Set a budget limit in Settings to track your spending.'
                : (rawPercent > 100
                    ? 'Over budget — consider adjusting your spending!'
                    : '$displayPercent% Of Your Expenses, Looks Good.'),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF052224)),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceItem(
      String title, String amount, IconData icon, Color amountColor,
      {FontWeight fontWeight = FontWeight.w600}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.black54),
              const SizedBox(width: 4),
              Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF093030))),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(amount,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: fontWeight,
                    color: amountColor)),
          ),
        ],
      ),
    );
  }

  // --- 2. Goal Summary Card ---
  Widget _buildGoalSummaryCard() {
    final gs = ref.watch(goalServiceProvider);
    final goal = gs.activeGoal;
    final ts = ref.watch(transactionServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final selectedCategory = authService.selectedCategory;
    final progress = goal != null ? gs.progressRatio(ts.totalBalance) : 0.0;

    // Computed values
    final revenue = ts.revenueLast7Days;
    final categoryExpense = selectedCategory != null
        ? ts.categoryExpenseLast7Days(selectedCategory)
        : 0;

    return GestureDetector(
      onTap: () => GoalSetupSheet.show(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF00D293),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        color: const Color(0xFF007AFF),
                        backgroundColor: Colors.white30,
                      ),
                    ),
                    const _FigmaCarIcon(color: Color(0xFF093030), size: 28),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  goal != null
                      ? '${(progress * 100).toStringAsFixed(0)}%'
                      : 'Savings\nOn Goals',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF093030),
                  ),
                ),
              ],
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: SizedBox(
                height: 80, child: VerticalDivider(color: Colors.white54)),
          ),
          Expanded(
            child: Column(
              children: [
                _buildSummaryRow(const _FigmaWalletIcon(color: Color(0xFF052224), size: 22),
                    'Revenue Last Week', '+${_formatMoney(revenue)}', const Color(0xFF052224)),
                const Divider(color: Colors.white54),
                _buildCategoryRow(selectedCategory, categoryExpense),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Build the dynamic category row (formerly hardcoded "Food Last Week").
  Widget _buildCategoryRow(String? selectedCategory, int expense) {
    final label = selectedCategory ?? 'Select category';
    final amount = selectedCategory != null ? '${expense > 0 ? '-' : ''}${_formatMoney(expense)}' : '—';
    final color = selectedCategory != null
        ? const Color(0xFF0068FF)
        : Colors.black38;

    return GestureDetector(
      onTap: () => _showCategoryPicker(selectedCategory),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: selectedCategory != null
                ? Icon(_iconForCategory(selectedCategory), size: 22, color: const Color(0xFF0068FF))
                : const Icon(Icons.category_outlined, size: 22, color: Colors.black38),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(selectedCategory != null ? '$selectedCategory Last Week' : label,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF052224))),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more, size: 16, color: color),
                  ],
                ),
                Text(amount,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show a bottom sheet with all categories for the user to pick from.
  void _showCategoryPicker(String? currentSelected) {
    // Build full category list: 14 built-in + custom
    final builtIn = TransactionCategory.all;
    final custom = CustomCategoryStore.instance.items.map((c) =>
      TransactionCategory(key: c.name, label: c.name, icon: c.iconData, color: c.color),
    );
    final allCategories = [...builtIn, ...custom];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  'Select category to track',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003829),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: allCategories.map((cat) {
                      final isSelected = currentSelected == cat.key;
                      return GestureDetector(
                        onTap: () {
                          AuthService.instance.saveSelectedCategory(cat.key);
                          Navigator.of(ctx).pop();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? cat.color : cat.color.withValues(alpha: 0.5),
                                  width: isSelected ? 3 : 2,
                                ),
                                color: isSelected ? cat.color.withValues(alpha: 0.1) : const Color(0xFFF5F5F5),
                              ),
                              child: Icon(cat.icon, color: isSelected ? cat.color : cat.color.withValues(alpha: 0.7), size: 22),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 56,
                              child: Text(cat.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: const Color(0xFF052224),
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
      Widget icon, String title, String amount, Color color) {
    return Row(
      children: [
        SizedBox(width: 24, height: 24, child: icon),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF052224))),
            Text(amount,
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ],
    );
  }

  // --- 3. Tabs Daily/Weekly/Monthly ---
  Widget _buildPeriodTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFE2F3E5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: ['Daily', 'Weekly', 'Monthly'].asMap().entries.map((entry) {
          bool isSelected = _selectedTab == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00D293) : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF052224)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // --- 4. Transaction List ---
  Widget _buildTransactionList(TransactionService ts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: Recent transactions + Add button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent transactions',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF052224)),
            ),
            TextButton.icon(
              onPressed: widget.onAddTap,
              icon: const Icon(Icons.add_circle, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (ts.currentUserTransactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No transactions yet.\nTap "Add" to record your first one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ...(ts.currentUserTransactions.map((t) => GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditTransactionScreen(transaction: t),
                  ),
                ),
                child: _buildTransactionItem(
                  _iconForCategory(t.category),
                  t.title,
                  _formatTransactionTime(t.date),
                  t.category,
                  _formatSignedMoney(t.amount),
                  _iconColorForCategory(t.category),
                  t.amount > 0,
                ),
              ))),
      ],
    );
  }

  Widget _buildTransactionItem(IconData icon, String title, String date,
      String category, String amount, Color iconBg, bool isIncome) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration:
                BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 15, color: Color(0xFF052224))),
                Text(date,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF0068FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (category.isNotEmpty) ...[
            SizedBox(
                width: 60,
                child: Text(category,
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w300, fontSize: 13, color: Color(0xFF052224)))),
          ],
          Text(
            amount,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: isIncome ? const Color(0xFF052224) : const Color(0xFF0068FF),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForCategory(String category) {
    final custom = CustomCategoryStore.instance.findByKey(category);
    if (custom != null) return custom.iconData;
    return TransactionCategory.fromKey(category).icon;
  }

  static Color _iconColorForCategory(String category) =>
      TransactionCategory.fromKey(category).color;

  static String _formatSignedMoney(int amount) {
    final sign = amount < 0 ? '-' : '+';
    return '$sign ${_formatMoney(amount.abs())}';
  }

  static String _formatCompact(int amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    }
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$amount';
  }

  static String _formatMoney(int amount) {
    final text = amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '$text VND';
  }

  static String _formatTransactionTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final month = _months[dt.month - 1];
    return '$h:$m - $month ${dt.day}';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.greetingMorning;
    if (hour < 18) return AppStrings.greetingAfternoon;
    return AppStrings.greetingEvening;
  }

  /// Navigate to DashboardPage with a right-to-left slide transition.
  void _navigateToDashboard() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

// =============================================================================
// Figma home icons (car, wallet, food) as CustomPaint
// =============================================================================

class _FigmaWalletIcon extends StatelessWidget {
  const _FigmaWalletIcon({this.color = const Color(0xFF093030), this.size = 22});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.93),
      painter: _HomeIconPainter(color: color, path: (Canvas canvas, Size size, Paint paint) {
        final sc = size.shortestSide / 28;
        canvas.save(); canvas.scale(sc);
        final p = Path()
          ..moveTo(21.6682, 14.3281)..lineTo(12.8841, 19.9656)..cubicTo(12.7171, 20.0728, 12.5042, 20.0774, 12.3328, 19.9775)..lineTo(1.31931, 13.5628)..cubicTo(0.978071, 13.3641, 0.967569, 12.8749, 1.29997, 12.6617)..lineTo(19.2617, 1.14022)..cubicTo(19.4286, 1.03318, 19.6414, 1.02858, 19.8127, 1.1283)..lineTo(30.826, 7.53796)..cubicTo(31.1674, 7.73662, 31.178, 8.22591, 30.8456, 8.4392)..lineTo(25.6599, 11.7665)..moveTo(21.6735, 18.8056)..lineTo(12.8839, 24.4432)..cubicTo(12.717, 24.5503, 12.5043, 24.5549, 12.333, 24.4551)..lineTo(1.31917, 18.0452)..cubicTo(0.977933, 17.8466, 0.967187, 17.3575, 1.29938, 17.1441)..lineTo(4.2337, 15.2591)..moveTo(27.912, 10.3243)..lineTo(30.8258, 12.0205)..cubicTo(31.1672, 12.2192, 31.1777, 12.7087, 30.8451, 12.9219)..lineTo(25.6119, 16.2763)..moveTo(28.1254, 14.6618)..lineTo(30.8608, 16.357)..cubicTo(31.1911, 16.5617, 31.1948, 17.0408, 30.8678, 17.2507)..lineTo(12.8841, 28.7913)..cubicTo(12.7171, 28.8985, 12.5042, 28.903, 12.3328, 28.8032)..lineTo(1.31931, 22.3885)..cubicTo(0.978067, 22.1898, 0.967564, 21.7005, 1.29996, 21.4873)..lineTo(4.12163, 19.6774)..moveTo(13.8573, 4.94937)..lineTo(25.3494, 11.6406)..cubicTo(25.5119, 11.7352, 25.6119, 11.9091, 25.6119, 12.0972)..lineTo(25.6119, 20.3306)..cubicTo(25.6119, 20.5104, 25.5204, 20.6779, 25.3691, 20.7751)..lineTo(22.4873, 22.6258)..cubicTo(22.1357, 22.8516, 21.6735, 22.5992, 21.6735, 22.1813)..lineTo(21.6735, 14.6318)..cubicTo(21.6735, 14.4438, 21.5736, 14.2699, 21.4112, 14.1753)..lineTo(10.3854, 7.7506)..cubicTo(10.0443, 7.55186, 10.0338, 7.06291, 10.3659, 6.84961)..lineTo(13.306, 4.96139)..cubicTo(13.473, 4.85419, 13.6859, 4.84954, 13.8573, 4.94937)..close();
        canvas.drawPath(p, paint);
        canvas.restore();
      }),
    );
  }
}

class _FigmaCarIcon extends StatelessWidget {
  const _FigmaCarIcon({this.color = const Color(0xFF093030), this.size = 28});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HomeIconPainter(color: color, path: (Canvas canvas, Size size, Paint paint) {
        final sc = size.shortestSide / 36;
        canvas.save(); canvas.scale(sc);
        final p = Path()
          ..moveTo(32.7046, 8.20484)..lineTo(31.0252, 5.92445)..cubicTo(28.5032, 2.55495, 26.0856, 0.98877, 19.9801, 0.98877)..lineTo(19.5137, 0.98877)..cubicTo(13.4205, 0.98877, 11.0029, 2.55495, 8.46867, 5.92445)..lineTo(6.95099, 8.09424)..moveTo(6.98377, 19.6521)..lineTo(6.98377, 21.1371)..cubicTo(6.98377, 21.3477, 6.94287, 21.5563, 6.86362, 21.7508)..cubicTo(6.78437, 21.9454, 6.66819, 22.1222, 6.52176, 22.2711)..cubicTo(6.37532, 22.42, 6.20149, 22.5381, 6.01016, 22.6187)..cubicTo(5.81883, 22.6993, 5.61383, 22.7408, 5.40673, 22.7408)..lineTo(3.70701, 22.7408)..cubicTo(3.49991, 22.7408, 3.29491, 22.6993, 3.10358, 22.6187)..cubicTo(2.91225, 22.5381, 2.73827, 22.42, 2.59183, 22.2711)..cubicTo(2.44539, 22.1222, 2.32937, 21.9454, 2.25012, 21.7508)..cubicTo(2.17087, 21.5563, 2.12997, 21.3477, 2.12997, 21.1371)..lineTo(2.12997, 16.7256)..moveTo(32.3751, 19.6521)..lineTo(32.3751, 21.1371)..cubicTo(32.3751, 21.5614, 32.5404, 21.9683, 32.8349, 22.2689)..cubicTo(33.1293, 22.5694, 33.5288, 22.7391, 33.946, 22.7408)..lineTo(35.615, 22.7408)..cubicTo(36.0322, 22.7391, 36.4317, 22.5694, 36.7261, 22.2689)..cubicTo(37.0206, 21.9683, 37.1859, 21.5614, 37.1859, 21.1371)..lineTo(37.1859, 16.7256)..moveTo(7.7569, 10.96)..cubicTo(7.7569, 10.96, 6.60326, 14.1298, 10.1684, 14.6602)..moveTo(31.7246, 10.96)..cubicTo(31.7246, 10.96, 32.8844, 14.1298, 29.3132, 14.6602)..moveTo(15.9855, 14.6602)..lineTo(23.0175, 14.6602)..moveTo(16.6175, 17.4556)..lineTo(22.3855, 17.4556)..moveTo(7.309, 7.40329)..cubicTo(7.309, 8.85717, 0.988731, 8.85717, 0.988731, 7.40329)..cubicTo(0.988731, 5.94941, 2.39999, 4.75761, 4.14879, 4.75761)..cubicTo(5.8976, 4.75761, 7.309, 5.92445, 7.309, 7.40329)..close()..moveTo(32.2401, 7.40329)..cubicTo(32.2401, 8.85717, 38.5604, 8.85717, 38.5604, 7.40329)..cubicTo(38.5604, 5.94941, 37.149, 4.75761, 35.4002, 4.75761)..cubicTo(33.6514, 4.75761, 32.2401, 5.92445, 32.2401, 7.40329)..close()..moveTo(34.8848, 9.71203)..cubicTo(33.8185, 8.55066, 32.3468, 7.86067, 30.7858, 7.79015)..lineTo(8.56679, 7.79015)..cubicTo(7.00612, 7.86199, 5.53503, 8.55176, 4.46788, 9.71203)..cubicTo(2.73748, 11.5216, 2.20363, 14.0362, 2.15454, 16.4822)..cubicTo(2.11938, 17.0763, 2.23566, 17.6695, 2.49206, 18.2044)..cubicTo(2.85409, 18.8908, 11.6963, 20.7815, 19.6733, 20.7815)..cubicTo(27.6503, 20.7815, 36.5354, 18.8097, 36.8545, 18.2044)..cubicTo(37.1091, 17.669, 37.2232, 17.0757, 37.1859, 16.4822)..cubicTo(37.1491, 14.0362, 36.6152, 11.5403, 34.8848, 9.71203)..close();
        canvas.drawPath(p, paint);
        canvas.restore();
      }),
    );
  }
}

class _HomeIconPainter extends CustomPainter {
  const _HomeIconPainter({required this.color, required this.path});
  final Color color;
  final void Function(Canvas canvas, Size size, Paint paint) path;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    path(canvas, size, paint);
  }

  @override
  bool shouldRepaint(covariant _HomeIconPainter oldDelegate) => false;
}
