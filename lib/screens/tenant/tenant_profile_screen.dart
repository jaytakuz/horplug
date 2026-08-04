import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/tenant_profile_view_model.dart';
import '../../widgets/reusable_widgets.dart';
import '../../utils/formatters.dart';

class TenantProfileScreen extends StatelessWidget {
  const TenantProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;

    return ChangeNotifierProvider(
      key: ValueKey(profile?.roomId),
      create: (_) => TenantProfileViewModel(
        roomId: profile?.roomId,
        dormitoryId: profile?.dormitoryId,
      )..load(),
      child: const _TenantProfileView(),
    );
  }
}

class _TenantProfileView extends StatelessWidget {
  const _TenantProfileView();

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final profile = auth.profile;
    final viewModel = context.watch<TenantProfileViewModel>();

    final fullName =
        profile?.fullName.isNotEmpty == true ? profile!.fullName : 'ผู้พักอาศัย';
    // กรอง part ที่ว่างออกก่อนหยิบตัวแรก — ชื่อที่มีอักขระช่องว่างแบบพิเศษ
    // (zero-width ฯลฯ) ที่ trim() ไม่กิน จะทำให้ part[0] โยน RangeError
    final initials = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join();

    return RefreshIndicator(
      onRefresh: () async {
        await auth.refreshProfile();
        await viewModel.load();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.muted,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials.isEmpty ? '?' : initials.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(profile?.email ?? '—',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (profile?.roomId == null)
            PaperCard(
              child: Row(
                children: [
                  const Icon(Icons.meeting_room_outlined,
                      size: 20, color: AppColors.mutedForeground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('ยังไม่ได้เข้าพักในห้องใด',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            )
          else ...[
            _buildRoomCard(context, viewModel),
            const SizedBox(height: 16),
            _buildContactCard(context, viewModel),
          ],
          const SizedBox(height: 16),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ข้อมูลบัญชี',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                InfoRow(label: 'ชื่อ', value: profile?.fullName ?? '—'),
                InfoRow(label: 'อีเมล', value: profile?.email ?? '—'),
                InfoRow(label: 'เบอร์โทร', value: profile?.phone ?? '—'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async => auth.signOut(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('ออกจากระบบ'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.destructive,
              side: const BorderSide(color: AppColors.destructive),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(
    BuildContext context,
    TenantProfileViewModel viewModel,
  ) {
    final profile = AuthScope.of(context).profile;
    final room = viewModel.room;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ห้องและสัญญา',
                  style: Theme.of(context).textTheme.titleMedium),
              if (room != null)
                StatusBadge(
                  label: roomStatusLabel(room.status),
                  variant: room.status == RoomStatus.maintenance
                      ? BadgeVariant.warning
                      : BadgeVariant.success,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (viewModel.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (viewModel.errorMessage != null)
            SectionErrorNote(
              message: viewModel.errorMessage!,
              onRetry: viewModel.load,
            )
          else ...[
            InfoRow(label: 'ห้อง', value: profile?.roomNumber ?? '—'),
            InfoRow(label: 'ชั้น', value: room?.floor ?? '—'),
            InfoRow(
              label: 'ค่าเช่ารายเดือน',
              value: room != null ? formatBaht(room.price) : '—',
            ),
            InfoRow(label: 'หอพัก', value: profile?.dormitoryName ?? '—'),
          ],
        ],
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    TenantProfileViewModel viewModel,
  ) {
    final dormitory = viewModel.dormitory;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ติดต่อเจ้าของหอ',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          // ต้องเช็ค isLoading ก่อน ไม่งั้นจะเห็น "ไม่พบข้อมูลผู้ติดต่อ" แว็บ
          // ทุกครั้งที่เปิดหน้า ผู้ใช้เน็ตช้าจะเชื่อว่าไม่มีข้อมูลจริงๆ
          if (viewModel.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (dormitory == null || !dormitory.hasContact)
            Text('ไม่พบข้อมูลผู้ติดต่อ',
                style: Theme.of(context).textTheme.bodySmall)
          else ...[
            InfoRow(label: 'ชื่อ', value: dormitory.landlordName ?? '—'),
            if (dormitory.landlordPhone != null)
              _CopyableRow(
                icon: Icons.phone,
                value: dormitory.landlordPhone!,
                copiedMessage: 'คัดลอกเบอร์โทรแล้ว',
              ),
            if (dormitory.landlordEmail != null)
              _CopyableRow(
                icon: Icons.mail_outline,
                value: dormitory.landlordEmail!,
                copiedMessage: 'คัดลอกอีเมลแล้ว',
              ),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => context.go('/tenant/chat'),
            icon: const Icon(Icons.chat_bubble_outline, size: 16),
            label: const Text('แชทกับเจ้าของหอ'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ring,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({
    required this.icon,
    required this.value,
    required this.copiedMessage,
  });

  final IconData icon;
  final String value;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    )),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            color: AppColors.mutedForeground,
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(copiedMessage)));
            },
          ),
        ],
      ),
    );
  }
}
