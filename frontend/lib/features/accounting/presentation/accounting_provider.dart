import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/accounting_repository.dart';

final ledgerEntriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(accountingRepositoryProvider);
  return repo.getLedgerEntries();
});

final trialBalanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(accountingRepositoryProvider);
  return repo.getTrialBalance();
});

final accountsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(accountingRepositoryProvider);
  return repo.getAccounts();
});
