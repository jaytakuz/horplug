import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/reusable_widgets.dart';

class TenantHomeScreen extends StatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  final SupabaseService _service = SupabaseService();

  bool _isLoadingRequests = true;
  bool _isResponding = false;
  List<TenantJoinRequest> _pendingRequests = [];
  String? _requestErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

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

  Future<void> _loadPendingRequests() async {
    setState(() {
      _isLoadingRequests = true;
      _requestErrorMessage = null;
    });

    try {
      final requests = await _service.fetchPendingJoinRequestsForTenant();
      if (!mounted) return;

      setState(() {
        _pendingRequests = requests;
        _isLoadingRequests = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _requestErrorMessage = _formatErrorMessage(error);
        _isLoadingRequests = false;
      });
    }
  }

  Future<void> _respondToRequest({
    required TenantJoinRequest request,
    required bool accept,
  }) async {
    setState(() {
      _isResponding = true;
    });

    try {
      await _service.respondToTenantJoinRequest(
        requestId: request.id,
        accept: accept,
      );

      if (!mounted) return;

      await AuthScope.of(context).refreshProfile();
      await _loadPendingRequests();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'เข้าหอ ${request.dormitoryName} แล้ว'
                : 'ปฏิเสธเข้าหอ ${request.dormitoryName} แล้ว',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ตอบคำขอไม่สำเร็จ: ${_formatErrorMessage(error)}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResponding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ผู้พักอาศัย'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await AuthScope.of(context).refreshProfile();
          await _loadPendingRequests();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สวัสดี ${profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Tenant'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'จัดการคำขอเข้าหอและตรวจสอบข้อมูลบัญชีของคุณ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (_shouldShowJoinRequestSection) ...[
              const SizedBox(height: 16),
              _buildJoinRequestSection(context),
            ],
            const SizedBox(height: 16),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ข้อมูลบัญชี',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'ชื่อ', value: profile?.fullName ?? '-'),
                  _InfoRow(label: 'อีเมล', value: profile?.email ?? '-'),
                  _InfoRow(label: 'เบอร์โทร', value: profile?.phone ?? '-'),
                  _InfoRow(
                    label: 'Dormitory',
                    value: profile?.dormitoryName ?? '-',
                  ),
                  _InfoRow(
                    label: 'Room',
                    value: profile?.roomNumber ?? '-',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'บิล, คำขอซ่อม, ประวัติการชำระเงิน',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _shouldShowJoinRequestSection {
    return _isLoadingRequests ||
        _requestErrorMessage != null ||
        _pendingRequests.isNotEmpty;
  }

  Widget _buildJoinRequestSection(BuildContext context) {
    if (_isLoadingRequests) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_requestErrorMessage != null) {
      return PaperCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'คำขอเข้าหอ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'โหลดคำขอไม่สำเร็จ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.destructive,
                  ),
            ),
          ],
        ),
      );
    }

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คำขอเข้าหอ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _pendingRequests.isEmpty
                ? 'ยังไม่มีคำขอเข้าหอที่รอการตอบรับ'
                : 'ตรวจสอบและตอบรับคำขอจากเจ้าของหอพัก',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_pendingRequests.isNotEmpty) ...[
            const SizedBox(height: 16),
            ..._pendingRequests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.dormitoryName,
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'เจ้าของหอ',
                        value: request.landlordName,
                      ),
                      _InfoRow(
                        label: 'ห้อง',
                        value: request.roomNumber ?? '-',
                      ),
                      _InfoRow(
                        label: 'ส่งเมื่อ',
                        value:
                            '${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isResponding
                                  ? null
                                  : () => _respondToRequest(
                                        request: request,
                                        accept: false,
                                      ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.destructive,
                                side: const BorderSide(
                                  color: AppColors.destructive,
                                ),
                              ),
                              child: const Text('ปฏิเสธ'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isResponding
                                  ? null
                                  : () => _respondToRequest(
                                        request: request,
                                        accept: true,
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: _isResponding
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('ตอบรับ'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}


