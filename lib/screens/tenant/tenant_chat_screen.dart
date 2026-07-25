import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/tenant_chat_view_model.dart';
import '../../widgets/chat_conversation_view.dart';

class TenantChatScreen extends StatelessWidget {
  const TenantChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AuthScope.of(context).profile;
    final roomId = profile?.roomId;

    if (roomId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('แชทกับเจ้าของหอ')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'คุณยังไม่ได้เข้าพักในห้องใด กรุณารอการยืนยันจากเจ้าของหอก่อนเริ่มแชท',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
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
      child: const _TenantChatView(),
    );
  }
}

class _TenantChatView extends StatelessWidget {
  const _TenantChatView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TenantChatViewModel>();
    final profile = AuthScope.of(context).profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile?.dormitoryName ?? 'แชทกับเจ้าของหอ'),
      ),
      body: viewModel.isLoading
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
                  showQuickChips: false,
                  hasMoreMessages: viewModel.hasMoreMessages,
                  isLoadingMore: viewModel.isLoadingMore,
                  onLoadMore: viewModel.loadMoreMessages,
                  onPickImage: viewModel.pickAndSendImage,
                  isUploadingImage: viewModel.isUploadingImage,
                ),
    );
  }
}
