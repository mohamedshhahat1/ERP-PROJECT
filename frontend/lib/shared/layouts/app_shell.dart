import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/notifications/presentation/notifications_provider.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

/// Tracks navigation history without consecutive duplicates.
/// e.g., Sales→Products→Sales→Products becomes [Sales, Products]
final _navHistoryProvider = StateNotifierProvider<_NavHistoryNotifier, List<String>>((ref) => _NavHistoryNotifier());

class _NavHistoryNotifier extends StateNotifier<List<String>> {
  _NavHistoryNotifier() : super(['/']);

  void navigate(String path) {
    // Don't add if same as current (last) page
    if (state.isNotEmpty && state.last == path) return;
    // Don't add if it would create a duplicate pattern (A→B→A→B → keep A→B)
    if (state.length >= 2 && state[state.length - 2] == path) {
      // Going back to the previous page — just pop the last entry
      state = [...state.sublist(0, state.length - 1)];
    } else {
      state = [...state, path];
    }
    // Keep max 20 entries
    if (state.length > 20) {
      state = state.sublist(state.length - 20);
    }
  }

  String? goBack() {
    if (state.length <= 1) return null; // Can't go back further
    state = [...state.sublist(0, state.length - 1)];
    return state.last;
  }
}

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userRole = ref.watch(authProvider).token?.role ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final previousPath = ref.read(_navHistoryProvider.notifier).goBack();
        if (previousPath != null) {
          Router.neglect(context, () => GoRouter.of(context).go(previousPath));
        }
      },
      child: Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: collapsed ? 72 : 260,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              border: Border(right: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.diamond, color: Colors.white, size: 20),
                      ),
                      if (!collapsed) ...[const SizedBox(width: 12), const Text('Ceramic ERP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _navItem(context, ref, '/', Icons.dashboard_rounded, 'Dashboard', collapsed),
                      _navItem(context, ref, '/products', Icons.inventory_2_rounded, 'Products', collapsed),
                      _navItem(context, ref, '/inventory', Icons.warehouse_rounded, 'Inventory', collapsed),
                      _navItem(context, ref, '/sales', Icons.receipt_long_rounded, 'Sales', collapsed),
                      _navItem(context, ref, '/purchases', Icons.shopping_cart_rounded, 'Purchases', collapsed),
                      _navItem(context, ref, '/expenses', Icons.money_off_rounded, 'Expenses', collapsed),
                      _navItem(context, ref, '/customers', Icons.people_rounded, 'Customers', collapsed),
                      _navItem(context, ref, '/suppliers', Icons.local_shipping_rounded, 'Suppliers', collapsed),
                      _navItem(context, ref, '/opening-balances', Icons.account_balance_wallet_rounded, 'Opening Balances', collapsed),
                      _navItem(context, ref, '/reports', Icons.bar_chart_rounded, 'Reports', collapsed),
                      _navItem(context, ref, '/notifications', Icons.notifications_rounded, 'Notifications', collapsed),
                      _navItem(context, ref, '/whatsapp', Icons.chat, 'WhatsApp', collapsed, highlight: true),
                      const Divider(height: 24),
                      _navItem(context, ref, '/ai', Icons.smart_toy_rounded, 'AI Assistant', collapsed, highlight: true),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    onPressed: () => ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
                    icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 300,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: isDark ? AppColors.darkBackground : AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(onPressed: () => context.go('/ai'), icon: const Icon(Icons.smart_toy_rounded), tooltip: 'AI Assistant',
                        style: IconButton.styleFrom(foregroundColor: AppColors.primary)),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => context.go('/notifications'),
                        icon: ref.watch(unreadCountProvider).when(
                          data: (count) => count > 0
                              ? Badge(label: Text('$count', style: const TextStyle(fontSize: 10)), child: const Icon(Icons.notifications_outlined))
                              : const Icon(Icons.notifications_outlined),
                          loading: () => const Icon(Icons.notifications_outlined),
                          error: (_, __) => const Icon(Icons.notifications_outlined),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final current = ref.read(themeModeProvider);
                          ref.read(themeModeProvider.notifier).state = current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                        },
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                      ),
                      const SizedBox(width: 16),
                      _PremiumProfileMenu(
                        collapsed: collapsed,
                        isDark: isDark,
                        userRole: userRole,
                        ref: ref,
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _navItem(BuildContext context, WidgetRef ref, String path, IconData icon, String label, bool collapsed, {bool highlight = false}) {
    final currentPath = GoRouterState.of(context).uri.path;
    final isActive = currentPath == path;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isActive ? null : () {
            // Track in deduplication history + navigate
            ref.read(_navHistoryProvider.notifier).navigate(path);
            Router.neglect(context, () => GoRouter.of(context).go(path));
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 16 : 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isActive ? AppColors.primary : highlight ? AppColors.primary.withOpacity(0.7) : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                if (!collapsed) ...[const SizedBox(width: 12), Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppColors.primary : highlight ? AppColors.primary.withOpacity(0.8) : null)))],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _PremiumProfileMenu extends StatelessWidget {
  final bool collapsed;
  final bool isDark;
  final String userRole;
  final WidgetRef ref;

  const _PremiumProfileMenu({
    required this.collapsed,
    required this.isDark,
    required this.userRole,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authProvider).token;
    final name = token?.fullName ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return PopupMenuButton<String>(
      offset: const Offset(0, 56),
      elevation: 12,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark ? Colors.white.withOpacity(0.05) : AppColors.primary.withOpacity(0.05),
          border: Border.all(color: isDark ? Colors.white12 : AppColors.primary.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                ),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
            ),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary)),
                  Text(userRole, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : AppColors.textSecondary)),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: isDark ? Colors.white54 : AppColors.textSecondary),
            ],
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        // Profile header
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.6)],
                    ),
                  ),
                  child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.05)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(userRole.toUpperCase(), style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(height: 1),
        _premiumMenuItem(Icons.settings_rounded, 'Settings', '/settings', null),
        if (userRole == 'admin') ...[
          _premiumMenuItem(Icons.menu_book_rounded, 'Accounting', '/accounting', AppColors.info),
          _premiumMenuItem(Icons.manage_accounts_rounded, 'Users', '/users', AppColors.warning),
          _premiumMenuItem(Icons.admin_panel_settings_rounded, 'AI Audit', '/ai-audit', AppColors.primary),
          _premiumMenuItem(Icons.insights_rounded, 'AI Analytics', '/ai-analytics', AppColors.success),
        ],
        const PopupMenuDivider(height: 1),
        _premiumMenuItem(Icons.logout_rounded, 'Logout', 'logout', AppColors.error),
      ],
      onSelected: (value) {
        if (value == 'logout') {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
              ]),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () { Navigator.pop(ctx); ref.read(authProvider.notifier).logout(); },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                  child: const Text('Logout'),
                ),
              ],
            ),
          );
        } else {
          Router.neglect(context, () => GoRouter.of(context).go(value));
          ref.read(_navHistoryProvider.notifier).navigate(value);
        }
      },
    );
  }

  PopupMenuItem<String> _premiumMenuItem(IconData icon, String label, String value, Color? iconColor) {
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.textSecondary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor ?? (isDark ? Colors.white70 : AppColors.textSecondary)),
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: value == 'logout' ? AppColors.error : null)),
          ],
        ),
      ),
    );
  }
}
