import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'accounting_provider.dart';

class AccountingPage extends ConsumerStatefulWidget {
  const AccountingPage({super.key});

  @override
  ConsumerState<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends ConsumerState<AccountingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
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
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.info, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('accounting.title'.tr(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  Text('General ledger, trial balance & chart of accounts', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(trialBalanceProvider);
                  ref.invalidate(ledgerEntriesProvider);
                  ref.invalidate(accountsProvider);
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('common.refresh'.tr()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'accounting.trial_balance'.tr(), icon: Icon(Icons.balance_rounded, size: 18)),
                Tab(text: 'accounting.ledger'.tr(), icon: Icon(Icons.list_alt_rounded, size: 18)),
                Tab(text: 'accounting.accounts'.tr(), icon: Icon(Icons.account_tree_rounded, size: 18)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TrialBalanceTab(),
                _LedgerTab(),
                _AccountsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trial Balance Tab ───────────────────────────────────────────────────────
class _TrialBalanceTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trialBalanceAsync = ref.watch(trialBalanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return trialBalanceAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load trial balance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('$e', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(trialBalanceProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
      data: (data) {
        final accounts = (data['accounts'] as List?) ?? [];
        final totalDebit = data['total_debit'] ?? '0.00';
        final totalCredit = data['total_credit'] ?? '0.00';

        if (accounts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.balance, size: 56, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary.withOpacity(0.4)),
                const SizedBox(height: 14),
                Text('No accounts found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                ),
                child: Row(
                  children: [
                    _headerCell('accounting.account_code'.tr(), flex: 1),
                    _headerCell('accounting.account_name'.tr(), flex: 3),
                    _headerCell('accounting.account_type'.tr(), flex: 2),
                    _headerCell('accounting.debit'.tr(), flex: 2, align: TextAlign.right),
                    _headerCell('accounting.credit'.tr(), flex: 2, align: TextAlign.right),
                    _headerCell('accounting.balance'.tr(), flex: 2, align: TextAlign.right),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: ListView.separated(
                  itemCount: accounts.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                  itemBuilder: (context, index) {
                    final acc = accounts[index] as Map<String, dynamic>;
                    final balance = double.tryParse(acc['balance']?.toString() ?? '0') ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: Text(acc['account_code']?.toString() ?? '', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary))),
                          Expanded(flex: 3, child: Text(acc['account_name']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _typeColor(acc['account_type']?.toString() ?? '').withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                acc['account_type']?.toString() ?? '',
                                style: TextStyle(fontSize: 11, color: _typeColor(acc['account_type']?.toString() ?? ''), fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Expanded(flex: 2, child: Text(acc['total_debit']?.toString() ?? '0.00', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 2, child: Text(acc['total_credit']?.toString() ?? '0.00', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                          Expanded(
                            flex: 2,
                            child: Text(
                              acc['balance']?.toString() ?? '0.00',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: balance >= 0 ? AppColors.success : AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Footer totals
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.background,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                ),
                child: Row(
                  children: [
                    const Expanded(flex: 1, child: SizedBox.shrink()),
                    const Expanded(flex: 3, child: Text('TOTALS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    const Expanded(flex: 2, child: SizedBox.shrink()),
                    Expanded(flex: 2, child: Text(totalDebit.toString(), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text(totalCredit.toString(), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    const Expanded(flex: 2, child: SizedBox.shrink()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'asset':
        return AppColors.info;
      case 'liability':
        return AppColors.warning;
      case 'equity':
        return AppColors.primary;
      case 'revenue':
        return AppColors.success;
      case 'expense':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ─── Ledger Tab ──────────────────────────────────────────────────────────────
class _LedgerTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(ledgerEntriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ledgerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load ledger entries', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(ledgerEntriesProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt, size: 56, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary.withOpacity(0.4)),
                const SizedBox(height: 14),
                Text('No ledger entries found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                ),
                child: Row(
                  children: [
                    _headerCell('accounting.entry_date'.tr(), flex: 2),
                    _headerCell('accounting.description'.tr(), flex: 4),
                    _headerCell('accounting.entity'.tr(), flex: 2),
                    _headerCell('accounting.debit'.tr(), flex: 2, align: TextAlign.right),
                    _headerCell('accounting.credit'.tr(), flex: 2, align: TextAlign.right),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(entry['entry_date']?.toString() ?? '', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(entry['description']?.toString() ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                entry['entity_type']?.toString() ?? '-',
                                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              entry['debit']?.toString() ?? '0',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: double.tryParse(entry['debit']?.toString() ?? '0') != 0 ? null : AppColors.textSecondary.withOpacity(0.4)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              entry['credit']?.toString() ?? '0',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: double.tryParse(entry['credit']?.toString() ?? '0') != 0 ? null : AppColors.textSecondary.withOpacity(0.4)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.background,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                ),
                child: Row(
                  children: [
                    Text('${entries.length} entries', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Accounts Tab ────────────────────────────────────────────────────────────
class _AccountsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return accountsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Failed to load accounts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(accountsProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
      data: (accounts) {
        if (accounts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_tree, size: 56, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary.withOpacity(0.4)),
                const SizedBox(height: 14),
                Text('No accounts in chart of accounts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                ),
                child: Row(
                  children: [
                    _headerCell('accounting.account_code'.tr(), flex: 1),
                    _headerCell('accounting.account_name'.tr(), flex: 4),
                    _headerCell('accounting.account_type'.tr(), flex: 2),
                    _headerCell('accounting.system_account'.tr(), flex: 1, align: TextAlign.center),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: ListView.separated(
                  itemCount: accounts.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.border),
                  itemBuilder: (context, index) {
                    final acc = accounts[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: Text(acc['account_code']?.toString() ?? '', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary))),
                          Expanded(flex: 4, child: Text(acc['account_name']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _TrialBalanceTab._typeColor(acc['account_type']?.toString() ?? '').withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                acc['account_type']?.toString() ?? '',
                                style: TextStyle(fontSize: 11, color: _TrialBalanceTab._typeColor(acc['account_type']?.toString() ?? ''), fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Icon(
                              acc['is_system'] == true ? Icons.lock_outline : Icons.edit_outlined,
                              size: 16,
                              color: acc['is_system'] == true ? AppColors.warning : AppColors.textSecondary.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : AppColors.background,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
                ),
                child: Row(
                  children: [
                    Text('${accounts.length} account${accounts.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Shared helper ───────────────────────────────────────────────────────────
Widget _headerCell(String label, {int flex = 1, TextAlign align = TextAlign.left}) {
  return Expanded(
    flex: flex,
    child: Text(
      label,
      textAlign: align,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3),
    ),
  );
}
