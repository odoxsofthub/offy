import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class MentionRange {
  final int start;
  final int end;
  final String name;
  final bool hasTrailingSpace;

  const MentionRange({
    required this.start,
    required this.end,
    required this.name,
    required this.hasTrailingSpace,
  });
}

/// Represents an explicitly selected mention entity with start/end positions in the text.
class MentionEntity {
  final String name;
  final int id;
  int start;
  int end;
  bool hasTrailingSpace;

  MentionEntity({
    required this.name,
    required this.id,
    required this.start,
    required this.end,
    this.hasTrailingSpace = true,
  });

  MentionRange toMentionRange() {
    return MentionRange(
      start: start,
      end: end,
      name: name,
      hasTrailingSpace: hasTrailingSpace,
    );
  }
}

/// Custom [TextEditingController] that highlights explicitly selected mentions in [AppColors.secondary]
/// and guards caret selection so it cannot stop inside the middle of a mention entity.
class AppChatMentionTextEditingController extends TextEditingController {
  final List<String> memberNames;
  final List<MentionEntity> _entities = [];
  bool isDark;
  bool _isInternalUpdating = false;

  AppChatMentionTextEditingController({
    super.text,
    this.memberNames = const [],
    this.isDark = false,
  });

  /// Inserts an explicitly selected mention replacing the `@query` text at [atIndex].
  void insertMention({
    required String name,
    int id = 0,
    required int atIndex,
    required int replaceLength,
  }) {
    final currentText = text;
    final safeAtIndex = atIndex.clamp(0, currentText.length);
    final safeEndIndex =
        (atIndex + replaceLength).clamp(safeAtIndex, currentText.length);
    final before = currentText.substring(0, safeAtIndex);
    final after = currentText.substring(safeEndIndex);
    final mentionInsert = '@$name ';
    final newText = '$before$mentionInsert$after';
    final mentionEnd = safeAtIndex + name.length + 1; // index after `@name`

    final delta = newText.length - currentText.length;
    for (final entity in _entities) {
      if (entity.start >= safeEndIndex) {
        entity.start += delta;
        entity.end += delta;
      }
    }

    _entities.add(
      MentionEntity(
        name: name,
        id: id,
        start: safeAtIndex,
        end: mentionEnd,
        hasTrailingSpace: true,
      ),
    );
    _entities.sort((a, b) => a.start.compareTo(b.start));

    _isInternalUpdating = true;
    try {
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: safeAtIndex + mentionInsert.length,
        ),
      );
    } finally {
      _isInternalUpdating = false;
    }
  }

  /// Compatibility helper if needed by external callers.
  void addMentionName(String name) {
    // No-op for global caching to prevent automatic mention conversion on typing.
  }

  /// Returns the active explicitly selected mention entities.
  List<MentionEntity> get selectedMentionEntities =>
      List.unmodifiable(_entities);

  /// Returns the list of names explicitly tapped from the mention popup.
  List<String> get selectedMentionNames => _entities.map((e) => e.name).toList();

  List<MentionRange> getMentionRanges() {
    return _entities.map((e) => e.toMentionRange()).toList();
  }

  @override
  void clear() {
    _entities.clear();
    super.clear();
  }

  /// Parses the current text and populates `_entities` based on a list of valid mention names.
  /// Useful when the text is set externally (e.g., when editing an existing message).
  void parseMentions(List<String> validNames) {
    if (validNames.isEmpty || text.isEmpty) return;
    
    _entities.clear();
    
    // Sort names by length descending to match longest first
    final sortedNames = List<String>.from(validNames)
      ..sort((a, b) => b.length.compareTo(a.length));
      
    final textToSearch = text.toLowerCase();
    
    for (final name in sortedNames) {
      final nameLower = name.toLowerCase();
      final expectedStr = '@$nameLower';
      
      int searchStartIndex = 0;
      while (true) {
        final index = textToSearch.indexOf(expectedStr, searchStartIndex);
        if (index == -1) break;
        
        // Ensure boundary conditions
        final isStartBoundary = index == 0 ||
            textToSearch[index - 1] == ' ' ||
            textToSearch[index - 1] == '\n' ||
            textToSearch[index - 1] == '\t';
            
        final endIndex = index + expectedStr.length;
        final isEndBoundary = endIndex == textToSearch.length ||
            textToSearch[endIndex] == ' ' ||
            textToSearch[endIndex] == '\n' ||
            textToSearch[endIndex] == '\t' ||
            RegExp(r'[^\w]').hasMatch(textToSearch[endIndex]);
            
        if (isStartBoundary && isEndBoundary) {
          // Check if not already in _entities (e.g. part of a longer name already matched)
          final overlap = _entities.any((e) => index < e.end && endIndex > e.start);
          if (!overlap) {
            _entities.add(
              MentionEntity(
                name: name, // Original casing
                id: 0,
                start: index,
                end: endIndex,
                hasTrailingSpace: endIndex < textToSearch.length && textToSearch[endIndex] == ' ',
              ),
            );
          }
        }
        searchStartIndex = index + 1;
      }
    }
    
    _entities.sort((a, b) => a.start.compareTo(b.start));
    
    if (_entities.isNotEmpty) {
      final lastEntity = _entities.last;
      if (lastEntity.end == text.length && !lastEntity.hasTrailingSpace) {
        lastEntity.hasTrailingSpace = true;
        _isInternalUpdating = true;
        value = value.copyWith(
          text: '$text ',
          selection: TextSelection.collapsed(offset: text.length + 1),
        );
        _isInternalUpdating = false;
        return; // value setter handles notifyListeners
      }
    }
    
    notifyListeners();
  }

  void _updateEntitiesOnTextChange(String oldText, String newText) {
    if (_entities.isEmpty) return;
    if (newText.isEmpty) {
      _entities.clear();
      return;
    }

    // Find common prefix
    int prefixLen = 0;
    final minLen = math.min(oldText.length, newText.length);
    while (prefixLen < minLen && oldText[prefixLen] == newText[prefixLen]) {
      prefixLen++;
    }

    // Find common suffix
    int suffixLen = 0;
    while (suffixLen < (minLen - prefixLen) &&
        oldText[oldText.length - 1 - suffixLen] ==
            newText[newText.length - 1 - suffixLen]) {
      suffixLen++;
    }

    final oldEditStart = prefixLen;
    final oldEditEnd = oldText.length - suffixLen;
    final delta = newText.length - oldText.length;

    _entities.removeWhere((entity) {
      final expectedText = '@${entity.name}';

      // 1. Edit before this entity (or a greedy leading '@' match): if the mention is intact at
      // entity.start + delta, shift its range.
      final shiftedStart = entity.start + delta;
      final shiftedEnd = entity.end + delta;
      if (oldEditEnd <= entity.start || oldEditStart <= entity.start + 1) {
        if (shiftedStart >= 0 &&
            shiftedEnd <= newText.length &&
            newText.substring(shiftedStart, shiftedEnd).toLowerCase() ==
                expectedText.toLowerCase()) {
          final isStartBoundary = shiftedStart == 0 ||
              newText[shiftedStart - 1] == ' ' ||
              newText[shiftedStart - 1] == '\n' ||
              newText[shiftedStart - 1] == '\t';
          if (!isStartBoundary) {
            return true; // Revert to normal string if leading space was deleted (e.g. `am@demo`)
          }

          final isEndBoundary = shiftedEnd == newText.length ||
              newText[shiftedEnd] == ' ' ||
              newText[shiftedEnd] == '\n' ||
              newText[shiftedEnd] == '\t' ||
              RegExp(r'[^\w]').hasMatch(newText[shiftedEnd]);
          if (isEndBoundary) {
            entity.start = shiftedStart;
            entity.end = shiftedEnd;
            entity.hasTrailingSpace =
                shiftedEnd < newText.length && newText[shiftedEnd] == ' ';
            return false;
          }
        }
      }

      // 2. If edit overlapped or touched inside this entity range in oldText
      if (oldEditStart < entity.end && oldEditEnd > entity.start) {
        return true; // Modified entity text -> revert to plain string
      }

      // 3. If edit occurred entirely before this entity, shift its range
      if (oldEditEnd <= entity.start) {
        entity.start += delta;
        entity.end += delta;
      }

      // 4. Validate entity bounds and exact text match in newText
      if (entity.start < 0 ||
          entity.end > newText.length ||
          entity.start >= entity.end) {
        return true;
      }
      if (newText.substring(entity.start, entity.end).toLowerCase() !=
          expectedText.toLowerCase()) {
        return true;
      }

      // 5. Ensure mention is bounded at start (start of string, space, newline, or tab)
      final isStartBoundary = entity.start == 0 ||
          newText[entity.start - 1] == ' ' ||
          newText[entity.start - 1] == '\n' ||
          newText[entity.start - 1] == '\t';
      if (!isStartBoundary) {
        return true; // Revert to normal string if attached to preceding word
      }

      // 6. Ensure mention is bounded at end (space, newline, punctuation, or end of string)
      final isEndBoundary = entity.end == newText.length ||
          newText[entity.end] == ' ' ||
          newText[entity.end] == '\n' ||
          newText[entity.end] == '\t' ||
          RegExp(r'[^\w]').hasMatch(newText[entity.end]);
      if (!isEndBoundary) {
        return true;
      }

      entity.hasTrailingSpace =
          entity.end < newText.length && newText[entity.end] == ' ';
      return false;
    });
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;

    if (!_isInternalUpdating && oldText != newText && _entities.isNotEmpty) {
      _updateEntitiesOnTextChange(oldText, newText);
    }

    TextEditingValue adjustedValue = newValue;

    // 1. Prevent caret cursor from landing in the middle of a mention entity
    if (_entities.isNotEmpty) {
      final sel = newValue.selection;
      if (sel.isCollapsed && sel.baseOffset >= 0) {
        final offset = sel.baseOffset;
        final oldOffset = selection.isCollapsed ? selection.baseOffset : -1;
        for (final r in _entities) {
          if (offset > r.start && offset < r.end) {
            int snapOffset;
            if (oldOffset >= r.end) {
              // User moved LEFT into the mention -> jump across to start of mention
              snapOffset = r.start;
            } else if (oldOffset <= r.start && oldOffset >= 0) {
              // User moved RIGHT into the mention -> jump across to end of mention
              snapOffset = r.end;
            } else {
              // Direct tap inside mention -> snap to nearest boundary
              final distToStart = (offset - r.start).abs();
              final distToEnd = (r.end - offset).abs();
              snapOffset = distToEnd < distToStart ? r.end : r.start;
            }
            adjustedValue = newValue.copyWith(
              selection: TextSelection.collapsed(offset: snapOffset),
            );
            break;
          }
        }
      }
    }

    // 2. Cleanup partial mention entity edits caused by soft keyboard backspaces
    if (oldText.length > newText.length &&
        (oldText.length - newText.length) <= 3) {
      final oldSel = selection;
      if (oldSel.isCollapsed && oldSel.baseOffset > 0) {
        final oldOffset = oldSel.baseOffset;
        for (final r in List<MentionEntity>.from(_entities)) {
          // Only trigger atomic deletion when backspace was pressed specifically at mention end
          if (oldOffset == r.end ||
              (r.hasTrailingSpace && oldOffset == r.end + 1)) {
            final endDel = r.hasTrailingSpace ? r.end + 1 : r.end;
            final cleanedText =
                oldText.substring(0, r.start) + oldText.substring(endDel);
            _entities.remove(r);
            _updateEntitiesOnTextChange(oldText, cleanedText);
            adjustedValue = TextEditingValue(
              text: cleanedText,
              selection: TextSelection.collapsed(offset: r.start),
            );
            break;
          }
        }
      }
    }

    super.value = adjustedValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final currentText = text;
    if (currentText.isEmpty || _entities.isEmpty) {
      return TextSpan(style: style, text: currentText);
    }

    final children = <InlineSpan>[];
    int currentOffset = 0;

    final mentionStyle = (style ?? const TextStyle()).copyWith(
      color: AppColors.secondary,
      fontWeight: FontWeight.w500,
    );

    final normalStyle = (style ?? const TextStyle()).copyWith(
      color: isDark ? AppColors.white : const Color(0xFF252525),
      fontWeight: FontWeight.w500,
    );

    final sortedEntities = List<MentionEntity>.from(_entities)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final entity in sortedEntities) {
      if (entity.start > currentOffset) {
        children.add(
          TextSpan(
            text: currentText.substring(currentOffset, entity.start),
            style: normalStyle,
          ),
        );
      }
      final safeEnd = entity.end.clamp(entity.start, currentText.length);
      children.add(
        TextSpan(
          text: currentText.substring(entity.start, safeEnd),
          style: mentionStyle,
        ),
      );
      currentOffset = safeEnd;
    }

    if (currentOffset < currentText.length) {
      children.add(
        TextSpan(
          text: currentText.substring(currentOffset),
          style: normalStyle,
        ),
      );
    }

    return TextSpan(style: normalStyle, children: children);
  }

  /// Utility static method to parse mentions in any chat message string and return a styled [TextSpan].
  static TextSpan buildMentionTextSpan({
    required String text,
    required TextStyle defaultStyle,
    required TextStyle mentionStyle,
    List<String> memberNames = const [],
  }) {
    if (text.isEmpty) {
      return TextSpan(text: text, style: defaultStyle);
    }

    final List<MentionRange> ranges = [];
    final occupied = List<bool>.filled(text.length, false);

    if (memberNames.isNotEmpty) {
      final sortedNames = List<String>.from(memberNames)
        ..sort((a, b) => b.length.compareTo(a.length));
      final lowerSrc = text.toLowerCase();

      for (final name in sortedNames) {
        if (name.trim().isEmpty) continue;
        final pattern = '@${name.toLowerCase()}';
        int startSearch = 0;
        while (startSearch < text.length) {
          final found = lowerSrc.indexOf(pattern, startSearch);
          if (found == -1) break;
          final end = found + pattern.length;

          final isStartBoundary = found == 0 ||
              text[found - 1] == ' ' ||
              text[found - 1] == '\n' ||
              text[found - 1] == '\t';

          if (isStartBoundary) {
            bool isOverlap = false;
            for (int i = found; i < end; i++) {
              if (occupied[i]) {
                isOverlap = true;
                break;
              }
            }

            if (!isOverlap) {
              final isEndBoundary = end == text.length ||
                  text[end] == ' ' ||
                  text[end] == '\n' ||
                  text[end] == '\t' ||
                  RegExp(r'[^\w]').hasMatch(text[end]);
              if (isEndBoundary) {
                for (int i = found; i < end; i++) {
                  occupied[i] = true;
                }
                ranges.add(MentionRange(
                  start: found,
                  end: end,
                  name: name,
                  hasTrailingSpace: end < text.length && text[end] == ' ',
                ));
              }
            }
          }
          startSearch = found + 1;
        }
      }
    }

    // Fallback: match single @word tokens for API-received or unregistered messages
    final fallbackRegExp = RegExp(r'(?:^|(?<=[\s\n]))@[A-Za-z0-9_]+');
    for (final m in fallbackRegExp.allMatches(text)) {
      final atStart = text.indexOf('@', m.start);
      if (atStart == -1 || atStart >= m.end) continue;

      bool isOverlap = false;
      for (int i = atStart; i < m.end; i++) {
        if (occupied[i]) {
          isOverlap = true;
          break;
        }
      }

      if (!isOverlap) {
        for (int i = atStart; i < m.end; i++) {
          occupied[i] = true;
        }
        ranges.add(MentionRange(
          start: atStart,
          end: m.end,
          name: text.substring(atStart + 1, m.end),
          hasTrailingSpace: m.end < text.length && text[m.end] == ' ',
        ));
      }
    }

    if (ranges.isEmpty) {
      return TextSpan(text: text, style: defaultStyle);
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));

    final children = <InlineSpan>[];
    int currentOffset = 0;

    for (final range in ranges) {
      if (range.start > currentOffset) {
        children.add(
          TextSpan(
            text: text.substring(currentOffset, range.start),
            style: defaultStyle,
          ),
        );
      }
      children.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: mentionStyle,
        ),
      );
      currentOffset = range.end;
    }

    if (currentOffset < text.length) {
      children.add(
        TextSpan(text: text.substring(currentOffset), style: defaultStyle),
      );
    }

    return TextSpan(style: defaultStyle, children: children);
  }
}
