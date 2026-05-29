import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/users_repository.dart';

final usersProvider = FutureProvider<List<UserModel>>((ref) async {
  final repo = ref.read(usersRepositoryProvider);
  return repo.getAll();
});
