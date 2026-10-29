import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/network/network_interceptor.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_compressor_util.dart';
import '../../../../domain/repositories/user_repository.dart';
import '../../../../injection_container.dart';
import '../../../../l10n/app_localizations.dart';
import '../cached_image.dart';
import '../image_upload_bottom_sheet.dart';
import '../custom_snackbar.dart';
import 'app_chat_mention_text_editing_controller.dart';
import 'app_chat_send_icon_widget.dart';
import '../../../../domain/entities/attachment_entity.dart';
import 'app_document_badge_chip.dart';
import 'app_document_launcher.dart';

class AppChatInputBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final Function(
    String message,
    List<XFile> files,
    List<String> mentionNames,
    String bodyPartsJson,
  )?
  onSendWithFiles;
  final VoidCallback? onAddAttachment;
  final Function(List<XFile>)? onImagesSelected;
  final List<XFile>? attachments;
  final Function(int)? onRemoveAttachment;
  final String? hintText;
  final List<({int id, String name, String avatarUrl})>? mentionableMembers;
  final double? maxAvailableHeight;
  final bool enabled;
  final bool forceAllowSend;
  final List<AttachmentEntity>? existingAttachments;
  final Function(AttachmentEntity)? onRemoveExistingAttachment;
  final List<String>? editingMentionNames;

  const AppChatInputBarWidget({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSend,
    this.onSendWithFiles,
    this.onAddAttachment,
    this.onImagesSelected,
    this.attachments,
    this.onRemoveAttachment,
    this.hintText,
    this.mentionableMembers,
    this.maxAvailableHeight,
    this.enabled = true,
    this.forceAllowSend = false,
    this.existingAttachments,
    this.onRemoveExistingAttachment,
    this.editingMentionNames,
  });

  @override
  State<AppChatInputBarWidget> createState() => _AppChatInputBarWidgetState();
}

class _AppChatInputBarWidgetState extends State<AppChatInputBarWidget> {
  int _lineCount = 1;
  String? _mentionQuery;
  final List<XFile> _localAttachments = [];
  FocusNode? _internalFocusNode;
  late AppChatMentionTextEditingController _mentionController;

  List<({int id, String name, String avatarUrl})> _remoteMembers = [];
  Timer? _mentionDebounce;
  int _mentionSearchRequestId = 0;
  bool _isFetchingMentions = false;
  bool _isInitialAtFetch = false;
  String? _lastFetchedQuery;
  final Map<String, int> _knownMemberIds = {};
  bool _isSending = false;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  List<XFile> get _effectiveAttachments =>
      widget.attachments ?? _localAttachments;

  @override
  void initState() {
    super.initState();
    _initMentionController();
    if (widget.mentionableMembers != null) {
      for (final m in widget.mentionableMembers!) {
        _knownMemberIds[m.name.toLowerCase()] = m.id;
      }
    }
    widget.controller.addListener(_onWidgetControllerChanged);
    _effectiveFocusNode.onKeyEvent = _handleKeyEvent;
  }

  void _initMentionController() {
    _mentionController = AppChatMentionTextEditingController(
      text: widget.controller.text,
    );
    _mentionController.addListener(_onMentionControllerChanged);
  }

  void _onWidgetControllerChanged() {
    _updateLineCount();
    
    final oldText = _mentionController.text;
    final newText = widget.controller.text;
    
    final bool isExternalReplacement = (oldText.isEmpty && newText.isNotEmpty) || 
                                       (newText.length - oldText.length).abs() > 3;

    if (_mentionController.text != widget.controller.text ||
        _mentionController.selection != widget.controller.selection) {
      _mentionController.value = widget.controller.value;
      
      if (isExternalReplacement) {
        final List<String> validNames = [
          ...?(widget.mentionableMembers?.map((m) => m.name)),
          ...?(widget.editingMentionNames),
        ];
        _mentionController.parseMentions(validNames);
      }
    }
  }

  void _onMentionControllerChanged() {
    if (widget.controller.text != _mentionController.text ||
        widget.controller.selection != _mentionController.selection) {
      widget.controller.value = _mentionController.value;
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_handleBackspace()) {
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  bool _handleBackspace() {
    final text = _mentionController.text;
    final selection = _mentionController.selection;
    if (!selection.isCollapsed || selection.baseOffset <= 0) {
      return false;
    }

    final cursor = selection.baseOffset;
    final ranges = _mentionController.getMentionRanges();

    for (final range in ranges) {
      // 1. Cursor is right after trailing space of `@Person Name `
      if (range.hasTrailingSpace && cursor == range.end + 1) {
        final newText =
            text.substring(0, range.end) + text.substring(range.end + 1);
        final newVal = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: range.end),
        );
        _mentionController.value = newVal;
        widget.controller.value = newVal;
        return true;
      }

      // 2. Cursor is at `range.end` (right after mention name)
      if (cursor == range.end) {
        final endDel = range.hasTrailingSpace ? range.end + 1 : range.end;
        final newText = text.substring(0, range.start) + text.substring(endDel);
        final newVal = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: range.start),
        );
        _mentionController.value = newVal;
        widget.controller.value = newVal;
        return true;
      }
    }

    return false;
  }

  @override
  void didUpdateWidget(covariant AppChatInputBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onWidgetControllerChanged);
      widget.controller.addListener(_onWidgetControllerChanged);
      _mentionController.value = widget.controller.value;
    }
    
    final oldNames = oldWidget.editingMentionNames?.join(',') ?? '';
    final newNames = widget.editingMentionNames?.join(',') ?? '';
    if (oldNames != newNames) {
      final List<String> validNames = [
        ...?(widget.mentionableMembers?.map((m) => m.name)),
        ...?(widget.editingMentionNames),
      ];
      _mentionController.parseMentions(validNames);
    }
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    widget.controller.removeListener(_onWidgetControllerChanged);
    _mentionController.removeListener(_onMentionControllerChanged);
    _mentionController.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _updateLineCount() {
    final text = widget.controller.text;
    if (text.isEmpty) {
      if (_lineCount != 1) {
        setState(() => _lineCount = 1);
      }
      _setMentionQuery(null);
      return;
    }

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      maxLines: 3,
      textDirection: TextDirection.ltr,
    );

    final maxTextWidth = 270.w - 32.w;
    textPainter.layout(maxWidth: maxTextWidth > 0 ? maxTextWidth : 200);
    final count = textPainter.computeLineMetrics().length.clamp(1, 3);

    if (_lineCount != count) {
      setState(() {
        _lineCount = count;
      });
    }
    _updateMentionQuery();
  }

  void _fetchMentionSuggestions(String query) {
    if (_lastFetchedQuery == query && _isFetchingMentions) {
      return;
    }
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 300), () async {
      _lastFetchedQuery = query;
      final requestId = ++_mentionSearchRequestId;
      try {
        if (!sl.isRegistered<UserRepository>()) {
          if (mounted) {
            setState(() {
              _isFetchingMentions = false;
              _isInitialAtFetch = false;
            });
          }
          return;
        }
        final suggestions = await sl<UserRepository>().getMentionSuggestions(
          search: query,
          limit: 20,
        );

        if (requestId == _mentionSearchRequestId && mounted) {
          setState(() {
            _isFetchingMentions = false;
            _isInitialAtFetch = false;
            _remoteMembers = suggestions.map((m) {
              final id = int.tryParse(m.id) ?? 0;
              _knownMemberIds[m.name.toLowerCase()] = id;
              return (id: id, name: m.name, avatarUrl: m.avatarUrl);
            }).toList();
          });
        }
      } catch (_) {
        if (requestId == _mentionSearchRequestId && mounted) {
          setState(() {
            _isFetchingMentions = false;
            _isInitialAtFetch = false;
          });
        }
      }
    });
  }

  void _updateMentionQuery() {
    final text = widget.controller.text;
    final rawOffset = widget.controller.selection.baseOffset;
    final offset = (rawOffset < 0 || rawOffset > text.length)
        ? text.length
        : rawOffset;
    final textBeforeCursor = text.substring(0, offset);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1) {
      _setMentionQuery(null);
      return;
    }

    // Ensure @ is standalone (at start of text, or preceded by space/newline)
    if (atIndex > 0 &&
        textBeforeCursor[atIndex - 1] != ' ' &&
        textBeforeCursor[atIndex - 1] != '\n') {
      _setMentionQuery(null);
      return;
    }

    final existingRanges = _mentionController.getMentionRanges();

    // Check if offset falls within an already completed mention entity
    final isInsideExistingMention = existingRanges.any(
      (m) => offset > m.start && offset <= m.end,
    );
    if (isInsideExistingMention) {
      _setMentionQuery(null);
      return;
    }

    // Skip an @ that starts an existing mention, so the popup doesn't reopen after insertMention.
    final isAtOfExistingMention = existingRanges.any((m) => m.start == atIndex);
    if (isAtOfExistingMention) {
      _setMentionQuery(null);
      return;
    }

    final afterAt = textBeforeCursor.substring(atIndex + 1);

    // Hide popup on newline, space immediately after @, or 2+ consecutive spaces
    if (afterAt.contains('\n') ||
        afterAt.startsWith(' ') ||
        afterAt.contains('  ')) {
      _setMentionQuery(null);
      return;
    }

    _setMentionQuery(afterAt);
  }

  void _setMentionQuery(String? query) {
    if (_mentionQuery != query) {
      final isNewMentionStarting = _mentionQuery == null && query != null;
      setState(() {
        _mentionQuery = query;
        if (query == null) {
          _mentionDebounce?.cancel();
          _mentionSearchRequestId++;
          _remoteMembers = [];
          _isFetchingMentions = false;
          _isInitialAtFetch = false;
          _lastFetchedQuery = null;
        } else {
          _isFetchingMentions = true;
          if (isNewMentionStarting) {
            _isInitialAtFetch = true;
          }
        }
      });

      if (query != null) {
        _fetchMentionSuggestions(query);
      }
    }
  }

  List<({int id, String name, String avatarUrl})> get _filteredMembers {
    if (_mentionQuery == null) return [];

    if (_remoteMembers.isNotEmpty) {
      return _remoteMembers;
    }

    if (widget.mentionableMembers != null &&
        widget.mentionableMembers!.isNotEmpty) {
      final q = _mentionQuery!.toLowerCase();
      if (q.isEmpty) return widget.mentionableMembers!;
      return widget.mentionableMembers!
          .where((m) => m.name.toLowerCase().contains(q))
          .toList();
    }

    return [];
  }

  void _onMemberTap(String name, {int id = 0}) {
    final text = _mentionController.text;
    final offset = _mentionController.selection.baseOffset;
    final safeOffset = offset.clamp(0, text.length);
    final textBeforeCursor = text.substring(0, safeOffset);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1) return;

    _setMentionQuery(null);
    _mentionController.insertMention(
      name: name,
      id: id != 0 ? id : (_knownMemberIds[name.toLowerCase()] ?? 0),
      atIndex: atIndex,
      replaceLength: safeOffset - atIndex,
    );
    widget.controller.value = _mentionController.value;
    // Re-focus after insertion so cursor position is restored correctly
    // without resetting the selection before atIndex is read.
    _effectiveFocusNode.requestFocus();
  }

  Widget _buildMentionShimmer({int itemCount = 3}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase(isDark),
      highlightColor: AppColors.shimmerHighlight(isDark),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            itemCount,
            (index) => Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Row(
                children: [
                  Container(
                    width: 30.r,
                    height: 30.r,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Container(
                    width: 140.w,
                    height: 16.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMentionPopup() {
    final members = _filteredMembers;
    final mediaQuery = MediaQuery.of(context);
    final count = members.length;
    final double itemHeight = 66.h;

    // Step 1: Calculate max safe space ceiling (38% of available height from LayoutBuilder)
    final double maxSafeSpace =
        widget.maxAvailableHeight != null && widget.maxAvailableHeight! > 0
        ? (widget.maxAvailableHeight! * 0.38)
        : (mediaQuery.size.height * 0.30);

    final int shimmerItemCount = maxSafeSpace >= 190.h ? 3 : 2;

    // Step 2: Calculate maxHeight for shimmer or content
    // 2.5 items (~165.h) is the MINIMUM scrollable ceiling floor, while 3.5 (~231.h) or 4.5 (~297.h) are used when space permits
    final double target4Half = 4.5 * itemHeight; // ~297.h
    final double target3Half = 3.5 * itemHeight; // ~231.h
    final double target2Half = 2.5 * itemHeight; // ~165.h

    double maxHeight;
    if (_isInitialAtFetch && _isFetchingMentions && members.isEmpty) {
      maxHeight = shimmerItemCount * 46.h + 16.h;
    } else if (count <= 2) {
      // 1 or 2 items: fit completely without scroll peek affordance
      maxHeight = count * itemHeight;
    } else {
      // 3+ items: snap to largest half-item boundary (4.5, 3.5, or 2.5 items) that fits safely inside maxSafeSpace
      if (maxSafeSpace >= target4Half && count >= 5) {
        maxHeight = target4Half;
      } else if (maxSafeSpace >= target3Half && count >= 4) {
        maxHeight = target3Half;
      } else {
        maxHeight = target2Half; // 2.5 items is the SMALLEST ceiling floor
      }
    }

    maxHeight = math
        .min(maxHeight, maxSafeSpace)
        .clamp(50.h, maxSafeSpace > 50.h ? maxSafeSpace : target2Half);

    Widget content;
    if (_isInitialAtFetch && _isFetchingMentions && members.isEmpty) {
      content = KeyedSubtree(
        key: const ValueKey('mention_shimmer'),
        child: _buildMentionShimmer(itemCount: shimmerItemCount),
      );
    } else {
      content = KeyedSubtree(
        key: const ValueKey('mention_list'),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          itemCount: members.length,
          separatorBuilder: (_, index) => Divider(
            height: 0,
            thickness: 0.5,
            color: AppColors.shade,
            indent: 56.w,
            endIndent: 16.w,
          ),
          itemBuilder: (_, i) {
            final member = members[i];
            return GestureDetector(
              onTap: () => _onMemberTap(member.name, id: member.id),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30.r,
                      height: 30.r,
                      child: CachedImage(
                        imageUrl: member.avatarUrl,
                        width: 30.r,
                        height: 30.r,
                        radius: 15.r,
                        fit: BoxFit.cover,
                        userName: member.name,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w400,
                          height: 29 / 18,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F0),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10.r),
          topRight: Radius.circular(10.r),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10.r),
          topRight: Radius.circular(10.r),
        ),
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: content,
            ),
            if (_isFetchingMentions && members.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 2.h,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.main),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _removeAttachment(int index) {
    if (widget.onRemoveAttachment != null) {
      widget.onRemoveAttachment!(index);
    } else {
      setState(() {
        if (index >= 0 && index < _localAttachments.length) {
          _localAttachments.removeAt(index);
        }
      });
    }
  }

  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    final currentFiles = List<XFile>.from(_effectiveAttachments);

    if (text.isEmpty && currentFiles.isEmpty && !widget.forceAllowSend) return;

    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      final selectedEntities = _mentionController.selectedMentionEntities;
      final List<Map<String, dynamic>> bodyParts = [];
      final Set<String> actualMentionNames = {};
      int lastIndex = 0;

      for (final entity in selectedEntities) {
        if (entity.start > lastIndex && entity.start <= text.length) {
          bodyParts.add({
            "type": "text",
            "text": text.substring(lastIndex, entity.start),
          });
        }
        final id = entity.id != 0
            ? entity.id
            : (_knownMemberIds[entity.name.toLowerCase()] ?? 0);
        if (id != 0) {
          bodyParts.add({"type": "mention", "partner_id": id});
          actualMentionNames.add(entity.name);
        } else {
          final safeEnd = entity.end.clamp(entity.start, text.length);
          bodyParts.add({
            "type": "text",
            "text": text.substring(entity.start, safeEnd),
          });
        }
        lastIndex = entity.end.clamp(0, text.length);
      }
      if (lastIndex < text.length) {
        bodyParts.add({"type": "text", "text": text.substring(lastIndex)});
      }

      if (bodyParts.isEmpty && text.isNotEmpty) {
        bodyParts.add({"type": "text", "text": text});
      }

      final bodyPartsJson = jsonEncode(bodyParts);

      void silentClear() {
        _mentionController.clear();
        widget.controller.clear();
        if (widget.attachments == null) {
          _localAttachments.clear();
        }
      }

      NetworkInterceptor.instance.registerPreDismissCallback(silentClear);

      try {
        if (widget.onSendWithFiles != null) {
          final result = widget.onSendWithFiles!(
            text,
            currentFiles,
            actualMentionNames.toList(),
            bodyPartsJson,
          );
          if (result is Future) {
            await result;
          }
        } else {
          widget.onSend();
        }

        silentClear();
        _effectiveFocusNode.unfocus();
      } catch (e) {
        // If sending failed due to network disconnect/cancellation,
        // clear silently while still behind the error overlay.
        silentClear();
        rethrow;
      } finally {
        NetworkInterceptor.instance.unregisterPreDismissCallback(silentClear);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _mentionController.isDark = isDark;
    
    final bool hasExisting = widget.existingAttachments != null && widget.existingAttachments!.isNotEmpty;
    final hasAttachments = _effectiveAttachments.isNotEmpty || hasExisting;

    double radius = hasAttachments ? 12.r : 62.r;
    EdgeInsets padding = hasAttachments
        ? EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h)
        : EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h);

    double minHeight = 46.h;
    if (hasAttachments) {
      if (_lineCount == 1) {
        minHeight = 78.h;
      } else if (_lineCount == 2) {
        minHeight = 98.h;
      } else {
        minHeight = 124.h;
      }
    } else {
      if (_lineCount == 2) {
        radius = 24.r;
        padding = EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h);
      } else if (_lineCount >= 3) {
        radius = 12.r;
        padding = EdgeInsets.symmetric(horizontal: 27.w, vertical: 10.h);
      }
    }

    final bar = Container(
      key: const ValueKey('chat_input_bar_container'),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.midLight,
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 12.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment Plus Button (Rectangle 1295 left)
              GestureDetector(
                onTap: widget.enabled
                    ? () {
                        _effectiveFocusNode.unfocus();
                        if (widget.onAddAttachment != null) {
                          widget.onAddAttachment!();
                        } else {
                          ImageUploadBottomSheet.show(
                            context,
                            onImagesSelected: (files) async {
                              final currentCount = _effectiveAttachments.length;
                              if (currentCount >= 5) {
                                CustomSnackbar.show(
                                  context,
                                  message:
                                      AppLocalizations.of(
                                        context,
                                      )?.maximumUpload5Files ??
                                      'Maximum upload 5 files',
                                );
                                return;
                              }
                              final availableSlots = 5 - currentCount;
                              final cappedFiles = files
                                  .take(availableSlots)
                                  .toList();

                              if (files.length > availableSlots) {
                                CustomSnackbar.show(
                                  context,
                                  message:
                                      AppLocalizations.of(
                                        context,
                                      )?.maximumUpload5FilesExtraIgnored ??
                                      'Maximum upload 5 files. Extra files ignored.',
                                );
                              }

                              final validFiles = <XFile>[];
                              bool hasOverSized = false;
                              for (final f in cappedFiles) {
                                final len = await f.length();
                                if (len > 10 * 1024 * 1024) {
                                  hasOverSized = true;
                                } else {
                                  validFiles.add(f);
                                }
                              }

                              if (hasOverSized && mounted) {
                                CustomSnackbar.show(
                                  this.context,
                                  message:
                                      AppLocalizations.of(
                                        this.context,
                                      )?.fileSizeExceeds10MbLimit ??
                                      'File size exceeds 10MB limit',
                                );
                              }

                              if (validFiles.isEmpty) return;

                              // Show files in UI immediately!
                              if (widget.onImagesSelected != null) {
                                widget.onImagesSelected!(validFiles);
                              } else {
                                setState(() {
                                  _localAttachments.addAll(validFiles);
                                });
                              }

                              // Compress in background and swap with compressed instances
                              try {
                                final compressedFiles =
                                    await ImageCompressorUtil.compressImageList(
                                      validFiles,
                                    );

                                if (!mounted) return;

                                if (widget.onImagesSelected == null) {
                                  setState(() {
                                    for (
                                      int i = 0;
                                      i < validFiles.length;
                                      i++
                                    ) {
                                      final idx = _localAttachments.indexOf(
                                        validFiles[i],
                                      );
                                      if (idx != -1 &&
                                          i < compressedFiles.length) {
                                        _localAttachments[idx] =
                                            compressedFiles[i];
                                      }
                                    }
                                  });
                                }
                              } catch (e) {
                                debugPrint('Background compression error: $e');
                              }
                            },
                          );
                        }
                      }
                    : null,
                child: Container(
                  width: 46.w,
                  height: 46.h,
                  decoration: BoxDecoration(
                    color: widget.enabled
                        ? AppColors.navColor
                        : AppColors.navColor.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.add, color: AppColors.white, size: 24.r),
                ),
              ),
              SizedBox(width: 10.w),
              // Dynamic Message Input Field (Rectangle 1294: 270.w x 124.h with attachments)
              Expanded(
                child: GestureDetector(
                  onTap: widget.enabled
                      ? () {
                          _effectiveFocusNode.requestFocus();
                        }
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    constraints: BoxConstraints(minHeight: minHeight),
                    alignment: hasAttachments
                        ? Alignment.topLeft
                        : Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.white,
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: isDark ? AppColors.darkNav : AppColors.shade,
                        width: 1.0,
                      ),
                    ),
                    padding: padding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: hasAttachments ? 60.h : 90.h,
                          ),
                          child: TextField(
                            key: const ValueKey('chat_input_textfield'),
                            controller: _mentionController,
                            focusNode: _effectiveFocusNode,
                            enabled: widget.enabled,
                            minLines: 1,
                            maxLines: 3,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              hintText:
                                  widget.hintText ??
                                  AppLocalizations.of(context)?.typeAMessage ??
                                  'Type a message...',
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                height: 20 / 14,
                                color: AppColors.navColor,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              height: 20 / 14,
                              color: isDark
                                  ? AppColors.white
                                  : const Color(0xFF252525),
                            ),
                          ),
                        ),
                        if (hasAttachments) ...[
                          SizedBox(height: 6.h),
                          // Attachment Badges Row (Figma Frame 2609829, 12.h bottom padding)
                          Padding(
                            padding: EdgeInsets.only(bottom: 2.h),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (hasExisting)
                                    ...widget.existingAttachments!.map((attachment) {
                                      return Padding(
                                        padding: EdgeInsets.only(right: 8.w),
                                        child: _ExistingAttachmentPreviewChip(
                                          attachment: attachment,
                                          allAttachments: widget.existingAttachments ?? [],
                                          onRemove: () {
                                            if (widget.onRemoveExistingAttachment != null) {
                                              widget.onRemoveExistingAttachment!(attachment);
                                            }
                                          },
                                        ),
                                      );
                                    }),
                                  ...List.generate(
                                    _effectiveAttachments.length,
                                    (index) {
                                      final file = _effectiveAttachments[index];
                                      return Padding(
                                        padding: EdgeInsets.only(right: 8.w),
                                        child: _AttachmentPreviewChip(
                                          file: file,
                                          allFiles: _effectiveAttachments,
                                          onRemove: () =>
                                              _removeAttachment(index),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              // Action / Send Button (Rectangle 1295 right)
              GestureDetector(
                onTap: widget.enabled ? _handleSend : null,
                child: Container(
                  width: 46.w,
                  height: 46.h,
                  decoration: BoxDecoration(
                    color: widget.enabled
                        ? AppColors.main
                        : AppColors.main.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: _isSending
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: const CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : AppChatSendIconWidget(size: 20.r),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_mentionQuery != null &&
            ((_isInitialAtFetch && _isFetchingMentions) ||
                _filteredMembers.isNotEmpty))
          Flexible(fit: FlexFit.loose, child: _buildMentionPopup()),
        bar,
      ],
    );
  }
}

// Figma Frame 2609829 Attachment Chip Component (Group 13 PDF & Group 14 IMG)
class _AttachmentPreviewChip extends StatelessWidget {
  final XFile file;
  final List<XFile> allFiles;
  final VoidCallback onRemove;

  const _AttachmentPreviewChip({
    required this.file,
    this.allFiles = const [],
    required this.onRemove,
  });

  bool get _isImg {
    final ext = file.name.toLowerCase();
    return ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.heic');
  }

  bool get _isPdf {
    return file.name.toLowerCase().endsWith('.pdf');
  }

  String get _badgeText {
    if (_isImg) return 'IMG';
    if (_isPdf) return 'PDF';
    return 'DOC';
  }

  Color get _badgeColor {
    if (_isImg) return const Color(0xFF00C8B3);
    if (_isPdf) return AppColors.red;
    return AppColors.secondary;
  }

  void _onPreview(BuildContext context) {
    final attachments = allFiles
        .map((f) => AttachmentEntity(url: f.path, name: f.name))
        .toList();
    AppDocumentLauncher.open(
      context,
      path: file.path,
      name: file.name,
      allAttachments: attachments,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDocumentBadgeChip(
      label: _badgeText,
      badgeColor: _badgeColor,
      imagePath: file.path,
      onTap: () => _onPreview(context),
      onRemove: onRemove,
    );
  }
}

class _ExistingAttachmentPreviewChip extends StatelessWidget {
  final AttachmentEntity attachment;
  final List<AttachmentEntity> allAttachments;
  final VoidCallback onRemove;

  const _ExistingAttachmentPreviewChip({
    required this.attachment,
    this.allAttachments = const [],
    required this.onRemove,
  });

  bool get _isImg {
    final ext = attachment.name?.toLowerCase() ?? attachment.url.toLowerCase();
    return ext.endsWith('.png') ||
        ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.heic');
  }

  bool get _isPdf {
    return (attachment.name?.toLowerCase() ?? attachment.url.toLowerCase()).endsWith('.pdf');
  }

  String get _badgeText {
    if (_isImg) return 'IMG';
    if (_isPdf) return 'PDF';
    return 'DOC';
  }

  Color get _badgeColor {
    if (_isImg) return const Color(0xFF00C8B3);
    if (_isPdf) return AppColors.red;
    return AppColors.secondary;
  }

  void _onPreview(BuildContext context) {
    AppDocumentLauncher.open(
      context,
      path: attachment.url,
      name: attachment.name ?? '',
      allAttachments: allAttachments,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDocumentBadgeChip(
      label: _badgeText,
      badgeColor: _badgeColor,
      imageUrl: attachment.url,
      onTap: () => _onPreview(context),
      onRemove: onRemove,
    );
  }
}
