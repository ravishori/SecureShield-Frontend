import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable text field with standard SecureShield decoration.
/// Wraps TextFormField — works inside Form widgets for validation.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int? maxLines;
  final bool obscureText;
  final bool readOnly;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.obscureText = false,
    this.readOnly = false,
    this.validator,
    this.onChanged,
    this.onTap,
    this.textInputAction,
    this.focusNode,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      obscureText: obscureText,
      readOnly: readOnly,
      validator: validator,
      onChanged: onChanged,
      onTap: onTap,
      textInputAction: textInputAction,
      focusNode: focusNode,
      autofocus: autofocus,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffix: suffix,
        counterText: '',
      ),
    );
  }
}

/// Dropdown wrapper — equivalent to AppTextField but for dropdowns.
class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final IconData? prefixIcon;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final String? disabledHint;

  const AppDropdownField({
    super.key,
    required this.label,
    this.prefixIcon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.disabledHint,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      ),
      hint: enabled
          ? null
          : Text(
              disabledHint ?? 'Select…',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 13),
            ),
      isExpanded: true,
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
      items: enabled
          ? items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item)),
                  ))
              .toList()
          : [],
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }
}
