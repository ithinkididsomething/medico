import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';

/// Accessible clinical search input field with clear action and keyboard optimization.
class SearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final bool autofocus;

  const SearchField({
    super.key,
    this.hintText = 'Search facilities, patients, or symptoms...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.controller,
    this.autofocus = false,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  bool _isInternalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _isInternalController = true;
    }
  }

  @override
  void dispose() {
    if (_isInternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleClear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      textField: true,
      label: widget.hintText,
      child: Container(
        height: AppConstants.buttonHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: AppColors.borderLight, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textNavyPrimary,
          ),
          onChanged: (val) {
            setState(() {});
            widget.onChanged?.call(val);
          },
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textNavyMuted,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.secondarySlateTeal,
              size: 22,
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.textNavyMuted,
                    onPressed: _handleClear,
                    tooltip: 'Clear search query',
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}
