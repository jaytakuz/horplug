import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import 'action_result.dart';

class TenantHomeViewModel extends ChangeNotifier {
  TenantHomeViewModel({SupabaseService? service})
      : _service = service ?? SupabaseService();

  final SupabaseService _service;

  bool isLoadingRequests = true;
  bool isResponding = false;
  List<TenantJoinRequest> pendingRequests = [];
  String? requestErrorMessage;

  bool get shouldShowJoinRequestSection =>
      isLoadingRequests ||
      requestErrorMessage != null ||
      pendingRequests.isNotEmpty;

  String _formatErrorMessage(Object error) {
    final message = error.toString().trim();
    final normalized = message.startsWith('Exception: ')
        ? message.substring('Exception: '.length).trim()
        : message;
    final lowerCaseMessage = normalized.toLowerCase();

    if (lowerCaseMessage.contains('failed host lookup') ||
        lowerCaseMessage.contains('socketexception') ||
        lowerCaseMessage.contains('clientexception') ||
        lowerCaseMessage.contains('connection refused') ||
        lowerCaseMessage.contains('network is unreachable') ||
        lowerCaseMessage.contains('connection timed out') ||
        lowerCaseMessage.contains('timed out')) {
      return 'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
    }

    return normalized;
  }

  Future<void> loadPendingRequests() async {
    isLoadingRequests = true;
    requestErrorMessage = null;
    notifyListeners();

    try {
      pendingRequests = await _service.fetchPendingJoinRequestsForTenant();
      isLoadingRequests = false;
      notifyListeners();
    } catch (error) {
      requestErrorMessage = _formatErrorMessage(error);
      isLoadingRequests = false;
      notifyListeners();
    }
  }

  Future<ActionResult> respondToRequest({
    required TenantJoinRequest request,
    required bool accept,
  }) async {
    isResponding = true;
    notifyListeners();

    try {
      await _service.respondToTenantJoinRequest(
        requestId: request.id,
        accept: accept,
      );

      await loadPendingRequests();

      return ActionResult(
        success: true,
        message: accept
            ? 'เข้าหอ ${request.dormitoryName} แล้ว'
            : 'ปฏิเสธเข้าหอ ${request.dormitoryName} แล้ว',
      );
    } catch (error) {
      return ActionResult(
        success: false,
        message: 'ตอบคำขอไม่สำเร็จ: ${_formatErrorMessage(error)}',
      );
    } finally {
      isResponding = false;
      notifyListeners();
    }
  }
}
