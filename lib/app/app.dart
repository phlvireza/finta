import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/account_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/template_provider.dart';
import '../core/services/recurring_service.dart';
import '../core/services/budget_expiry_service.dart';
import '../core/services/notification_service.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/transactions/transaction_history_screen.dart';
import '../screens/budgets/manage_budgets_screen.dart';
import '../screens/more/more_screen.dart';
import '../screens/transactions/widgets/quick_add_sheet.dart';
import '../core/constants/app_colors.dart';
import '../l10n/app_localizations.dart';

/// Root app widget — handles initialization, onboarding routing,
/// and the main bottom navigation shell.
class FintaApp extends StatefulWidget {
  const FintaApp({super.key});

  @override
  State<FintaApp> createState() => _FintaAppState();
}

class _FintaAppState extends State<FintaApp> {
  bool _isInitialized = false;
  int _currentIndex = 0;

  /// Budgets sits in the bar because it is what the app is *for*; Analytics
  /// moved into [MoreScreen] to make room. The shell already owns a FAB, so
  /// the budgets screen is embedded — it puts its own add action in the app
  /// bar rather than raising a second, colliding FAB.
  final _screens = const [
    DashboardScreen(),
    TransactionHistoryScreen(),
    ManageBudgetsScreen(embedded: true),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final settings = context.read<SettingsProvider>();
    final categories = context.read<CategoryProvider>();
    final recurring = context.read<RecurringProvider>();
    final transactions = context.read<TransactionProvider>();
    final budgets = context.read<BudgetProvider>();
    final accounts = context.read<AccountProvider>();
    final goals = context.read<GoalProvider>();
    final debts = context.read<DebtProvider>();
    final templates = context.read<TemplateProvider>();

    await settings.init();
    if (!mounted) return;

    // No-op outside Android/iOS/macOS; requests notification permission
    // up front rather than waiting for the first subscription reminder.
    // Reminder text is built without a BuildContext, so the service needs the
    // language handed to it — settings.init() has already resolved it, from
    // the device locale on a first launch.
    NotificationService.instance.setLanguage(settings.languageCode);
    await NotificationService.instance.init();
    if (!mounted) return;

    await categories.loadCategories();
    if (!mounted) return;

    await accounts.loadAccounts();
    if (!mounted) return;

    await Future.wait([goals.loadGoals(), debts.loadDebts(), templates.loadTemplates()]);
    if (!mounted) return;

    await recurring.loadRecurringTransactions();
    if (!mounted) return;

    // Process any due recurring transactions
    final recurringService = context.read<RecurringService>();
    await recurringService.processRecurringTransactions();
    if (!mounted) return;

    await transactions.loadTransactions(payday: settings.payday);
    if (!mounted) return;

    // Retire one-off budgets whose period ended while the app was closed.
    // Must run before loadBudgets, or the statuses built below would
    // include budgets that are about to be deactivated — the same reason
    // the recurring catch-up runs before loadTransactions.
    final budgetExpiryService = context.read<BudgetExpiryService>();
    await budgetExpiryService.expireFinishedBudgets(payday: settings.payday);
    if (!mounted) return;

    await budgets.loadBudgets(payday: settings.payday);
    if (!mounted) return;

    // Balances depend on transactions just posted by the recurring
    // catch-up above, so reload after it — not before.
    await accounts.loadAccounts();

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _openAddTransaction() {
    QuickAddSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final settings = context.watch<SettingsProvider>();
    if (!settings.hasCompletedOnboarding) {
      return const OnboardingScreen();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: _openAddTransaction,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // A real notched BottomAppBar rather than a BottomNavigationBar:
      // BottomNavigationBar can't leave a gap, so the docked FAB used to
      // sit on top of the middle tabs and swallow their taps.
      bottomNavigationBar: BottomAppBar(
        height: _navBarHeight,
        elevation: 0,
        padding: EdgeInsets.zero,
        color: theme.colorScheme.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: _notchMargin,
        child: CustomPaint(
          // The hairline top border has to follow the notch. A plain
          // Border(top:) would run straight across the cut-out.
          painter: _NotchedTopBorderPainter(color: borderColor),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: loc.home,
                  selected: _currentIndex == 0,
                  onTap: () => _onTabTapped(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: loc.transactions,
                  selected: _currentIndex == 1,
                  onTap: () => _onTabTapped(1),
                ),
              ),
              // Keeps the two halves clear of the FAB's notch.
              const SizedBox(width: _notchDiameter),
              Expanded(
                child: _NavItem(
                  icon: Icons.track_changes_outlined,
                  activeIcon: Icons.track_changes,
                  label: loc.budgets,
                  selected: _currentIndex == 2,
                  onTap: () => _onTabTapped(2),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.more_horiz_outlined,
                  activeIcon: Icons.more_horiz,
                  label: loc.more,
                  selected: _currentIndex == 3,
                  onTap: () => _onTabTapped(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Geometry shared by the bar, its notch, and the border that traces it.
/// [_fabRadius] is the default [FloatingActionButton] radius; the notch is
/// that plus [_notchMargin], which is what [BottomAppBar] cuts out.
const double _fabRadius = 28.0;
const double _notchMargin = 8.0;
const double _notchDiameter = (_fabRadius + _notchMargin) * 2;
const double _navBarHeight = 64.0;

/// Strokes the bar's outer edge, clipped to the top strip so only the top
/// border — and the curve it makes around the FAB — is drawn.
class _NotchedTopBorderPainter extends CustomPainter {
  final Color color;

  const _NotchedTopBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final guestRadius = _fabRadius + _notchMargin;
    final hostRect = Offset.zero & size;
    // The FAB is centred on the bar's top edge when docked, so the notch
    // is a circle sitting half-in, half-out at y = 0.
    final guestRect = Rect.fromCircle(
      center: Offset(size.width / 2, 0),
      radius: guestRadius,
    );

    final path = const CircularNotchedRectangle().getOuterPath(hostRect, guestRect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.save();
    // Without this the stroke would also outline the bar's sides and
    // bottom, which sit on the screen edge and shouldn't be drawn.
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, guestRadius + 2));
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NotchedTopBorderPainter oldDelegate) => oldDelegate.color != color;
}

/// One destination in the notched bar. [BottomNavigationBarItem] can't be
/// reused here because the bar is no longer a [BottomNavigationBar], so
/// selected/unselected styling is applied explicitly.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: _navBarHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, size: 24, color: color),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
