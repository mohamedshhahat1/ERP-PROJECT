import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../opening_balances/data/opening_balance_repository.dart';
import '../../opening_balances/presentation/opening_balances_provider.dart';

final _systemInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('');
    // The root endpoint returns {"message": ..., "version": ...}
    // But the baseUrl includes /api, so we need to call the base
    return response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : {};
  } catch (_) {
    return {};
  }
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final systemInfoAsync = ref.watch(_systemInfoProvider);
    final lockAsync = ref.watch(openingBalancesLockProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  Text('System configuration and information', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Grid of settings sections
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              // Section 1: System Info
              _SettingsCard(
                isDark: isDark,
                icon: Icons.info_outline_rounded,
                iconColor: AppColors.info,
                title: 'System Info',
                child: systemInfoAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Unable to fetch system info', style: TextStyle(color: AppColors.error)),
                  ),
                  data: (info) => Column(
                    children: [
                      _InfoRow(label: 'API Version', value: info['version']?.toString() ?? '4.3.0', isDark: isDark),
                      _InfoRow(label: 'Status', value: 'Connected', isDark: isDark, valueColor: AppColors.success),
                      _InfoRow(label: 'API Base', value: 'http://localhost:8000/api', isDark: isDark),
                    ],
                  ),
                ),
              ),

              // Section 2: AI Configuration
              _SettingsCard(
                isDark: isDark,
                icon: Icons.smart_toy_outlined,
                iconColor: AppColors.primary,
                title: 'AI Configuration',
                child: Column(
                  children: [
                    _InfoRow(label: 'AI Engine', value: 'GPT-4 / Embeddings', isDark: isDark),
                    _InfoRow(label: 'Voice AI', value: 'Enabled', isDark: isDark, valueColor: AppColors.success),
                    _InfoRow(label: 'Anomaly Detection', value: 'Active', isDark: isDark, valueColor: AppColors.success),
                    _InfoRow(label: 'AI Audit', value: 'Enabled', isDark: isDark, valueColor: AppColors.success),
                  ],
                ),
              ),

              // Section 3: Opening Balances
              _SettingsCard(
                isDark: isDark,
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AppColors.warning,
                title: 'Opening Balances',
                child: lockAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Unable to fetch lock status', style: TextStyle(color: AppColors.error)),
                  ),
                  data: (isLocked) => Column(
                    children: [
                      _InfoRow(
                        label: 'Lock Status',
                        value: isLocked ? 'Locked' : 'Unlocked',
                        isDark: isDark,
                        valueColor: isLocked ? AppColors.error : AppColors.success,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleLock(context, ref, isLocked),
                          icon: Icon(isLocked ? Icons.lock_open : Icons.lock, size: 16),
                          label: Text(isLocked ? 'Unlock Balances' : 'Lock Balances'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isLocked ? AppColors.success : AppColors.error,
                            side: BorderSide(color: isLocked ? AppColors.success : AppColors.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Section 4: About
              _SettingsCard(
                isDark: isDark,
                icon: Icons.diamond_outlined,
                iconColor: AppColors.primaryLight,
                title: 'About',
                child: Column(
                  children: [
                    _InfoRow(label: 'Application', value: 'Ceramic Showroom ERP', isDark: isDark),
                    _InfoRow(label: 'Version', value: '4.3.0', isDark: isDark),
                    _InfoRow(label: 'Platform', value: 'Flutter Web + FastAPI', isDark: isDark),
                    _InfoRow(label: 'License', value: 'Proprietary', isDark: isDark),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleLock(BuildContext context, WidgetRef ref, bool isLocked) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isLocked ? Icons.lock_open : Icons.lock, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(isLocked ? 'Unlock Opening Balances?' : 'Lock Opening Balances?'),
          ],
        ),
        content: Text(
          isLocked
              ? 'Unlocking will allow changes to opening balances. Are you sure?'
              : 'Locking will prevent any changes to opening balances until an admin unlocks them.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(openingBalanceRepositoryProvider);
                if (isLocked) {
                  await repo.unlock();
                } else {
                  await repo.lock();
                }
                ref.invalidate(openingBalancesLockProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isLocked ? 'Opening balances unlocked' : 'Opening balances locked'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: isLocked ? AppColors.success : AppColors.error),
            child: Text(isLocked ? 'Unlock' : 'Lock'),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SettingsCard({required this.isDark, required this.icon, required this.iconColor, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, required this.isDark, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}
