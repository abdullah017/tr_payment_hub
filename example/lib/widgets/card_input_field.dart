import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tr_payment_hub/tr_payment_hub.dart';

/// Formatted card number input with validation and card type detection.
class CardNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;

  const CardNumberField({
    super.key,
    required this.controller,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: 'Card Number',
        hintText: '5528 7900 0000 0008',
        prefixIcon: const Icon(Icons.credit_card),
        suffixIcon: _buildCardTypeIcon(controller.text),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _CardNumberFormatter(),
      ],
      validator: validator ??
          (v) {
            final number = v?.replaceAll(' ', '') ?? '';
            if (number.isEmpty) return 'Card number is required';
            if (!CardValidator.isValidCardNumber(number)) {
              return 'Invalid card number';
            }
            return null;
          },
      onChanged: onChanged,
    );
  }

  Widget? _buildCardTypeIcon(String number) {
    final cleanNumber = number.replaceAll(' ', '');
    if (cleanNumber.length < 4) return null;

    final brand = CardValidator.detectCardBrand(cleanNumber);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        brand.name.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Card number formatter that adds spaces every 4 digits.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Expiry date input with MM/YY format.
class ExpiryDateField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool enabled;

  const ExpiryDateField({
    super.key,
    required this.controller,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: const InputDecoration(
        labelText: 'Expiry',
        hintText: 'MM/YY',
        prefixIcon: Icon(Icons.calendar_today),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _ExpiryDateFormatter(),
      ],
      validator: validator ??
          (v) {
            if (v == null || v.length < 5) return 'Invalid expiry';
            final parts = v.split('/');
            if (parts.length != 2) return 'Invalid format';
            final month = int.tryParse(parts[0]);
            final year = int.tryParse(parts[1]);
            if (month == null || year == null) return 'Invalid date';
            if (month < 1 || month > 12) return 'Invalid month';
            if (!CardValidator.isValidExpiry(parts[0], parts[1])) {
              return 'Card expired';
            }
            return null;
          },
    );
  }
}

/// Expiry date formatter that adds slash between month and year.
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    if (text.length > 4) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// CVV input with validation.
class CVVField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool enabled;

  const CVVField({
    super.key,
    required this.controller,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: const InputDecoration(
        labelText: 'CVV',
        hintText: '123',
        prefixIcon: Icon(Icons.lock),
      ),
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      validator: validator ??
          (v) {
            if (v == null || v.isEmpty) return 'CVV required';
            if (!CardValidator.isValidCVV(v)) return 'Invalid CVV';
            return null;
          },
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
    );
  }
}

/// Complete card input form section.
class CardInputSection extends StatelessWidget {
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final TextEditingController? nameController;
  final bool enabled;

  const CardInputSection({
    super.key,
    required this.cardNumberController,
    required this.expiryController,
    required this.cvvController,
    this.nameController,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nameController != null) ...[
          TextFormField(
            controller: nameController,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Card Holder Name',
              hintText: 'JOHN DOE',
              prefixIcon: Icon(Icons.person),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (v) => v?.isEmpty ?? true ? 'Name required' : null,
          ),
          const SizedBox(height: 16),
        ],
        CardNumberField(
          controller: cardNumberController,
          enabled: enabled,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ExpiryDateField(
                controller: expiryController,
                enabled: enabled,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CVVField(
                controller: cvvController,
                enabled: enabled,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
