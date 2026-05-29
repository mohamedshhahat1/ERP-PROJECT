import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/notifications/presentation/notifications_provider.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userRole = ref.watch(authProvider).token?.role ?? '';

    return Scaffold(
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
                      PopupMenuButton<String>(
                        offset: const Offset(0, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                (ref.watch(authProvider).token?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (!collapsed) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ],
                        ),
                        itemBuilder: (ctx) {
                          final token = ref.read(authProvider).token;
                          final name = token?.fullName ?? 'User';
                          final role = token?.role ?? '';
                          return [
                            // User info header
                            PopupMenuItem<String>(
                              enabled: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(role, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            // Menu items
                            const PopupMenuItem(value: '/settings', child: ListTile(dense: true, leading: Icon(Icons.settings_rounded, size: 20), title: Text('Settings', style: TextStyle(fontSize: 13)))),
                            if (role == 'admin') ...[
                              const PopupMenuItem(value: '/accounting', child: ListTile(dense: true, leading: Icon(Icons.menu_book_rounded, size: 20), title: Text('Accounting', style: TextStyle(fontSize: 13)))),
                              const PopupMenuItem(value: '/users', child: ListTile(dense: true, leading: Icon(Icons.manage_accounts_rounded, size: 20), title: Text('Users', style: TextStyle(fontSize: 13)))),
                              const PopupMenuItem(value: '/ai-audit', child: ListTile(dense: true, leading: Icon(Icons.admin_panel_settings_rounded, size: 20), title: Text('AI Audit', style: TextStyle(fontSize: 13)))),
                              const PopupMenuItem(value: '/ai-analytics', child: ListTile(dense: true, leading: Icon(Icons.insights_rounded, size: 20), title: Text('AI Analytics', style: TextStyle(fontSize: 13)))),
                            ],
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'logout', child: ListTile(dense: true, leading: Icon(Icons.logout, size: 20, color: AppColors.error), title: Text('Logout', style: TextStyle(fontSize: 13, color: AppColors.error)))),
                          ];
                        },
                        onSelected: (value) {
                          if (value == 'logout') {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Row(children: [Icon(Icons.logout, color: AppColors.error), SizedBox(width: 8), Text('Logout')]),
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
                            context.go(value);
                          }
                        },
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
            // Use Router.neglect to prevent browser history buildup on sidebar navigation
            Router.neglect(context, () {
              GoRouter.of(context).go(path);
            });
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
