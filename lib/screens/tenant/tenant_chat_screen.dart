import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/tenant_chat_view_model.dart';
import '../../widgets/chat_conversation_view.dart';

class TenantChatScreen extends StatelessWidget {
  /// [embedded] = true เมื่อถูกวางเป็นแท็บใน TenantShell ซึ่งมี Scaffold และ
  /// MobileHeader ให้อยู่แล้ว — ซ้อน Scaffold/AppBar อีกชั้นจะได้ header สองอัน
  const TenantChatScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;
    final roomId = profile?.roomId;

    if (roomId == null) {
      final emptyState = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 48, color: AppColors.mutedForeground),
              const SizedBox(height: 12),
              Text(
                'คุณยังไม่ได้เข้าพักในห้องใด กรุณารอการยืนยันจากเจ้าของหอก่อนเริ่มแชท',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );

      if (embedded) return emptyState;
      return Scaffold(
        appBar: AppBar(title: const Text('แชทกับเจ้าของหอ')),
        body: emptyState,
      );
    }

    final tenantName =
        profile?.fullName.isNotEmpty == true ? profile!.fullName : 'ผู้พักอาศัย';

    return ChangeNotifierProvider(
      create: (_) => TenantChatViewModel(
        roomId: roomId,
        tenantId: profile!.id,
        tenantName: tenantName,
      )..start(),
      child: _TenantChatView(embedded: embedded),
    );
  }
}

class _TenantChatView extends StatelessWidget {
  const _TenantChatView({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TenantChatViewModel>();
    final profile = AuthScope.of(context).profile;

    final body = viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : viewModel.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.destructive, size: 32),
                        const SizedBox(height: 12),
                        Text(
                          viewModel.errorMessage!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              : ChatConversationView(
                  messages: viewModel.conversation,
                  isSending: viewModel.isSending,
                  onSend: viewModel.sendMessage,
                  isCurrentUserOwner: false,
                  hasMoreMessages: viewModel.hasMoreMessages,
                  isLoadingMore: viewModel.isLoadingMore,
                  onLoadMore: viewModel.loadMoreMessages,
                  onPickImage: viewModel.pickAndSendImage,
                  isUploadingImage: viewModel.isUploadingImage,
                  onRequestMaintenance: viewModel.requestMaintenance,
                  isRequestingMaintenance: viewModel.isRequestingMaintenance,
                );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile?.dormitoryName ?? 'แชทกับเจ้าของหอ'),
      ),
      body: body,
    );
  }
}
