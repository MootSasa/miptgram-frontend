import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' as iconoir;
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/chat_service.dart';
import '../../services/liquid_glass_provider.dart';
import 'liquid_glass_input_field.dart';
import 'reply_preview_bar.dart';

/// Unified chat input bar component managing text entry, attachments preview,
/// editing banner, reply/quote preview, and uploading progress.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final bool isEditing;
  final String? editingTitle;
  final VoidCallback? onCancelEditing;
  final Message? replyToMessage;
  final bool isQuote;
  final String? quoteText;
  final VoidCallback? onCancelReply;
  final VoidCallback? onTapReply;
  final List<File> attachedFiles;
  final List<String> attachedFileNames;
  final ValueChanged<int>? onRemoveAttachment;
  final bool isUploading;
  final double uploadProgress;
  final bool isSending;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onEmoji;
  final VoidCallback? onVoice;
  final Widget? trailing;

  const ChatInputBar({
    Key? key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.isEditing = false,
    this.editingTitle,
    this.onCancelEditing,
    this.replyToMessage,
    this.isQuote = false,
    this.quoteText,
    this.onCancelReply,
    this.onTapReply,
    this.attachedFiles = const [],
    this.attachedFileNames = const [],
    this.onRemoveAttachment,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.isSending = false,
    this.onChanged,
    this.onSend,
    this.onAttach,
    this.onEmoji,
    this.onVoice,
    this.trailing,
  }) : super(key: key);

  bool _isImageFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final glassProvider = context.watch<LiquidGlassProvider?>();
    final glassEnabled = glassProvider?.enabled ?? false;
    final isLite = glassProvider?.isLite ?? false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Editing message banner
        if (isEditing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            child: Row(
              children: [
                iconoir.EditPencil(
                  color: Theme.of(context).colorScheme.primary,
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    editingTitle ??
                        context.l10n.translate('chat_editing_title'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (onCancelEditing != null)
                  IconButton(
                    icon: const iconoir.Xmark(
                      width: 18,
                      height: 18,
                    ),
                    onPressed: onCancelEditing,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

        // 2. Reply/Quote preview bar
        if (replyToMessage != null)
          ReplyPreviewBar(
            replyToMessage: replyToMessage!,
            isQuote: isQuote,
            quoteText: quoteText,
            onClose: onCancelReply ?? () {},
            onTap: onTapReply,
            enabled: glassEnabled,
            isLite: isLite,
          ),

        // 3. Attached files preview list
        if (attachedFiles.isNotEmpty)
          Container(
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: attachedFiles.length,
              itemBuilder: (context, index) {
                final fileName = index < attachedFileNames.length
                    ? attachedFileNames[index]
                    : '';
                return Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _isImageFile(fileName)
                              ? Image.file(
                                  attachedFiles[index],
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const iconoir.Page(
                                        width: 28,
                                        height: 28,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        fileName,
                                        style: const TextStyle(fontSize: 10),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      if (onRemoveAttachment != null)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => onRemoveAttachment!(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const iconoir.Xmark(
                                color: Colors.white,
                                width: 14,
                                height: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

        // 4. Upload progress
        if (isUploading)
          LinearProgressIndicator(
            value: uploadProgress > 0 ? uploadProgress : null,
            backgroundColor: Colors.grey[300],
          ),

        // 5. Input field row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: LiquidGlassInputField(
                enabled: glassEnabled,
                isLite: isLite,
                controller: controller,
                focusNode: focusNode,
                hintText: hintText ??
                    (attachedFiles.isNotEmpty
                        ? 'Add a caption...'
                        : 'Type a message...'),
                onChanged: onChanged,
                onSend: isSending ? null : onSend,
                onAttach: onAttach,
                onEmoji: onEmoji,
                onVoice: onVoice,
                isSending: isSending,
                hasAttachments: attachedFiles.isNotEmpty,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}
