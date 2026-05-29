import 'package:dio/dio.dart';
import '../network/exceptions.dart';

/// Extract a clean, user-friendly error message from any exception.
/// Strips DioException wrapper text and returns only the meaningful message.
String getErrorMessage(dynamic error) {
  if (error is ApiException) {
    return error.message;
  }

  if (error is NetworkException) {
    return 'خطأ في الاتصال بالسيرفر';
  }

  if (error is DioException) {
    // Extract the real error from DioException
    final innerError = error.error;
    if (innerError is ApiException) {
      return innerError.message;
    }
    if (innerError is NetworkException) {
      return 'خطأ في الاتصال بالسيرفر';
    }

    // Try to get detail from response data
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }

    // Fallback based on error type
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'انتهت مهلة الاتصال. حاول مرة أخرى';
      case DioExceptionType.connectionError:
        return 'خطأ في الاتصال بالسيرفر';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        if (statusCode == 401) return 'انتهت الجلسة. سجل دخول مرة أخرى';
        if (statusCode == 403) return 'ليس لديك صلاحية لهذا الإجراء';
        if (statusCode == 404) return 'غير موجود';
        if (statusCode == 409) return data is Map ? data['detail']?.toString() ?? 'تعارض في البيانات' : 'تعارض في البيانات';
        if (statusCode == 422) return 'بيانات غير صحيحة';
        if (statusCode == 429) return 'طلبات كثيرة. انتظر قليلاً';
        if (statusCode >= 500) return 'خطأ في السيرفر. حاول لاحقاً';
        return 'خطأ غير متوقع';
      default:
        return 'خطأ غير متوقع';
    }
  }

  // For any other exception type
  final msg = error.toString();
  // Strip common technical prefixes
  if (msg.contains('DioException')) {
    final detail = RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(msg);
    if (detail != null) return detail.group(1)!;
  }
  if (msg.startsWith('Exception: ')) return msg.substring(11);
  if (msg.length > 100) return 'خطأ غير متوقع';
  return msg;
}
