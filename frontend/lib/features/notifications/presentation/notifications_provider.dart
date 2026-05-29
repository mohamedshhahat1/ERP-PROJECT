import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notifications_repository.dart';

// Not autoDispose — data persists during navigation (invalidated explicitly on changes)
final notificationsProvider = FutureProvider<List<NotificationModel>>((ref) async {
  final repo = ref.read(notificationsRepositoryProvider);
  return repo.getAll();
});

// autoDispose — always shows fresh count when badge is visible
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.read(notificationsRepositoryProvider);
  return repo.getUnreadCount();
});

final notificationFilterProvider = StateProvider<NotificationFilter>((ref) => NotificationFilter.all);
final severityFilterProvider = StateProvider<String?>((ref) => null);

enum NotificationFilter { all, unread, read }

final filteredNotificationsProvider = Provider<AsyncValue<List<NotificationModel>>>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  final filter = ref.watch(notificationFilterProvider);
  final severity = ref.watch(severityFilterProvider);

  return notificationsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (notifications) {
      var filtered = notifications.where((n) {
        if (filter == NotificationFilter.unread && n.isRead) return false;
        if (filter == NotificationFilter.read && !n.isRead) return false;
        if (severity != null && n.severity != severity) return false;
        return true;
      }).toList();
      return AsyncValue.data(filtered);
    },
  );
});
