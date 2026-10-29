import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../common/custom_error_text.dart';
import '../common/frame_metrics.dart';

/// Outlined login input (Figma): icon, placeholder, label on the border when focused/filled.
/// Wraps its own [FormField]; errors show below via [CustomErrorText].
class LoginInputField extends StatefulWidget {
  const LoginInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.initialValue = '',
    this.validator,
    this.validateOnChange = false,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.suffix,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hint;

  /// SVG asset shown before the text.
  final String icon;
  final ValueChanged<String> onChanged;
  final String initialValue;
  final FormFieldValidator<String>? validator;

  /// Re-validates on every keystroke (after the first submit attempt).
  final bool validateOnChange;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<LoginInputField> createState() => _LoginInputFieldState();
}

class _LoginInputFieldState extends State<LoginInputField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = FrameMetrics.of(context);
    return FormField<String>(
      initialValue: widget.initialValue,
      validator: widget.validator,
      builder: (field) {
        final hasError = field.hasError;
        final isFocused = _focusNode.hasFocus;
        final showLabel = isFocused || _controller.text.isNotEmpty;
        final borderColor = hasError
            ? AppColors.red
            : isFocused
            ? AppColors.main
            : AppColors.loginFieldBorder;
        final textStyle = GoogleFonts.inter(
          fontSize: m(16),
          fontWeight: FontWeight.w400,
          height: 24 / 16,
          color: AppColors.black,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: m(60)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(m(10)),
                      border: Border.all(color: borderColor),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: m(18),
                        right: widget.suffix == null ? m(10) : 0,
                      ),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            widget.icon,
                            width: m(24),
                            height: m(24),
                          ),
                          SizedBox(width: m(10)),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              obscureText: widget.obscureText,
                              keyboardType: widget.keyboardType,
                              inputFormatters: widget.inputFormatters,
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
                              autofillHints: widget.autofillHints,
                              textInputAction: widget.textInputAction,
                              onSubmitted: widget.onSubmitted,
                              cursorColor: hasError
                                  ? AppColors.red
                                  : AppColors.main,
                              style: textStyle,
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: m(18),
                                ),
                                hintText: showLabel ? null : widget.hint,
                                hintStyle: textStyle.copyWith(
                                  color: AppColors.navColor,
                                ),
                              ),
                              onChanged: (value) {
                                field.didChange(value);
                                widget.onChanged(value);
                                if (widget.validateOnChange) field.validate();
                              },
                            ),
                          ),
                          if (widget.suffix != null) widget.suffix!,
                        ],
                      ),
                    ),
                  ),
                ),
                if (showLabel)
                  Positioned(
                    left: m(14),
                    top: -m(9.5),
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: AppColors.white,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: m(5),
                            vertical: m(2),
                          ),
                          child: Text(
                            widget.label,
                            style: GoogleFonts.inter(
                              fontSize: m(12),
                              fontWeight: FontWeight.w400,
                              height: 15 / 12,
                              color: hasError
                                  ? AppColors.red
                                  : AppColors.loginFieldLabel,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            CustomErrorText(errorText: field.errorText),
          ],
        );
      },
    );
  }
}
