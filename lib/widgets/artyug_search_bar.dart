import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Tappable pill matching [ArtyugSearchBar] — for shell / nav rows (no [TextField]).
class ArtyugSearchRouteTrigger extends StatelessWidget {
  final String hintText;
  final VoidCallback onTap;
  final double height;

  const ArtyugSearchRouteTrigger({
    super.key,
    this.hintText = 'Search artists, creators, artworks…',
    required this.onTap,
    this.height = 46,
  });

  static const _fillDark = Color(0xFF1A1428);
  static const _neon = Color(0xFFC4B5FD);
  static const _neonCore = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    // Always use dark neon pill (Explore reference). Search and shell often sit on
    // dark surfaces while [ThemeMode.light] would wrongly pick the lavender fill.
    const fill = _fillDark;
    final hintColor = _neon.withValues(alpha: 0.55);
    final iconColor = _neon.withValues(alpha: 0.75);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _neonCore.withValues(alpha: 0.42),
            ),
            boxShadow: [
              BoxShadow(
                color: _neonCore.withValues(alpha: 0.22),
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.search_rounded, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hintText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hintColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Violet “neon” pill search field — matches Explore / global Search styling.
class ArtyugSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool autofocus;

  const ArtyugSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Search artists, creators, artworks…',
    this.readOnly = false,
    this.onTap,
    this.trailing,
    this.autofocus = false,
  });

  @override
  State<ArtyugSearchBar> createState() => _ArtyugSearchBarState();
}

class _ArtyugSearchBarState extends State<ArtyugSearchBar> {
  late final FocusNode _internalFocus;
  FocusNode get _effectiveFocus => widget.focusNode ?? _internalFocus;
  bool _ownsFocus = false;
  bool _focused = false;

  // Violet neon system (Explore reference) — always dark pill for brand consistency
  static const _fillDark = Color(0xFF1A1428);
  static const _neon = Color(0xFFC4B5FD);
  static const _neonCore = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _internalFocus = FocusNode();
    _effectiveFocus.addListener(_onFocus);
    _focused = _effectiveFocus.hasFocus;
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() => _focused = _effectiveFocus.hasFocus);
  }

  @override
  void dispose() {
    _effectiveFocus.removeListener(_onFocus);
    if (_ownsFocus) _internalFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fill = _fillDark;
    final hintColor = _neon.withValues(alpha: 0.55);
    final iconColor = _neon.withValues(alpha: 0.75);
    const textColor = AppColors.textPrimary;
    final borderColor = _focused
        ? _neon.withValues(alpha: 0.95)
        : _neonCore.withValues(alpha: 0.42);
    final glow = _focused ? 20.0 : 14.0;
    final glowOpacity = _focused ? 0.36 : 0.24;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: _focused ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: _neonCore.withValues(alpha: glowOpacity),
            blurRadius: glow,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.readOnly ? widget.onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Icon(Icons.search_rounded, color: iconColor, size: 22),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode ?? _internalFocus,
                    autofocus: widget.autofocus,
                    readOnly: widget.readOnly,
                    onTap: widget.readOnly ? widget.onTap : null,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: hintColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
                if (!widget.readOnly)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (_, val, __) => val.text.isNotEmpty
                        ? IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              color: iconColor,
                              size: 20,
                            ),
                            onPressed: () {
                              widget.controller.clear();
                              widget.onChanged?.call('');
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
