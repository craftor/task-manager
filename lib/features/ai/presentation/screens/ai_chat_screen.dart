import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/ai_provider.dart';
import '../widgets/chat_message_bubble.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(aiChatProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final messages = ref.watch(aiMessagesListProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('AI 助手', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('开始对话吧！', style: TextStyle(color: AppColors.textMuted)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => ChatMessageBubble(message: messages[i]),
                  ),
          ),
          if (chatState.isLoading)
            Container(
              padding: const EdgeInsets.all(12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  SizedBox(width: 8),
                  Text('AI 正在思考...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          if (chatState.pendingAction != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.surface,
              child: Row(children: [
                Expanded(child: Text('确认执行 ${chatState.pendingAction!.action}？', style: const TextStyle(color: AppColors.textPrimary))),
                TextButton(onPressed: () => ref.read(aiChatProvider.notifier).cancelAction(), child: const Text('取消')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => ref.read(aiChatProvider.notifier).confirmAction(),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('确认'),
                ),
              ]),
            ),
          if (chatState.error != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Text(chatState.error!, style: const TextStyle(color: AppColors.error, fontSize: 12), maxLines: 5, overflow: TextOverflow.ellipsis),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    border: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(24)), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: chatState.isLoading ? null : _send,
                icon: chatState.isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.send, color: AppColors.primary),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}