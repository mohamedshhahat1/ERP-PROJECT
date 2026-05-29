import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  return AccountingRepository(ref.read(dioProvider));
});

class AccountingRepository {
  final Dio _dio;
  AccountingRepository(this._dio);

  Future<List<Map<String, dynamic>>> getLedgerEntries({int skip = 0, int limit = 50, String? entityType}) async {
    final params = <String, dynamic>{'skip': skip, 'limit': limit};
    if (entityType != null) params['entity_type'] = entityType;
    final response = await _dio.get('/accounting/ledger', queryParameters: params);
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getTrialBalance() async {
    final response = await _dio.get('/accounting/trial-balance');
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final response = await _dio.get('/accounting/accounts');
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
