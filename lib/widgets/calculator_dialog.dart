import 'package:flutter/material.dart';

class CalculatorDialog extends StatefulWidget {
  const CalculatorDialog({super.key});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  String _display = '0';
  double? _firstOperand;
  String? _operator;
  bool _shouldResetDisplay = false;

  void _onDigit(String digit) {
    setState(() {
      if (_display == '0' || _shouldResetDisplay) {
        _display = digit;
        _shouldResetDisplay = false;
      } else {
        _display += digit;
      }
    });
  }

  void _onDecimal() {
    setState(() {
      if (_shouldResetDisplay) {
        _display = '0.';
        _shouldResetDisplay = false;
      } else if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      _firstOperand = double.tryParse(_display);
      _operator = op;
      _shouldResetDisplay = true;
    });
  }

  void _onEquals() {
    if (_firstOperand == null || _operator == null) return;
    final secondOperand = double.tryParse(_display) ?? 0.0;
    double result = 0.0;
    switch (_operator) {
      case '+':
        result = _firstOperand! + secondOperand;
        break;
      case '-':
        result = _firstOperand! - secondOperand;
        break;
      case '×':
        result = _firstOperand! * secondOperand;
        break;
      case '÷':
        result = secondOperand != 0 ? _firstOperand! / secondOperand : 0.0;
        break;
    }

    setState(() {
      _display = result % 1 == 0 ? result.toInt().toString() : result.toStringAsFixed(2);
      _firstOperand = null;
      _operator = null;
      _shouldResetDisplay = true;
    });
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _firstOperand = null;
      _operator = null;
      _shouldResetDisplay = false;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_display.length > 1) {
        _display = _display.substring(0, _display.length - 1);
      } else {
        _display = '0';
      }
    });
  }

  Widget _btn(String label, {Color? bg, Color? fg, VoidCallback? onPressed}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bg ?? Colors.grey.shade100,
            foregroundColor: fg ?? const Color(0xFF1E293B),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calculate_rounded, color: Color(0xFF4F46E5)),
                    SizedBox(width: 8),
                    Text(
                      'Calculator',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.centerRight,
              child: Text(
                _display,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _btn('C', bg: const Color(0xFFFEE2E2), fg: const Color(0xFFEF4444), onPressed: _onClear),
                _btn('⌫', bg: const Color(0xFFF1F5F9), fg: const Color(0xFF475569), onPressed: _onBackspace),
                _btn('%', bg: const Color(0xFFF1F5F9), fg: const Color(0xFF475569), onPressed: () {
                  final val = (double.tryParse(_display) ?? 0) / 100;
                  setState(() => _display = val.toString());
                }),
                _btn('÷', bg: const Color(0xFFEEF2FF), fg: const Color(0xFF4F46E5), onPressed: () => _onOperator('÷')),
              ],
            ),
            Row(
              children: [
                _btn('7', onPressed: () => _onDigit('7')),
                _btn('8', onPressed: () => _onDigit('8')),
                _btn('9', onPressed: () => _onDigit('9')),
                _btn('×', bg: const Color(0xFFEEF2FF), fg: const Color(0xFF4F46E5), onPressed: () => _onOperator('×')),
              ],
            ),
            Row(
              children: [
                _btn('4', onPressed: () => _onDigit('4')),
                _btn('5', onPressed: () => _onDigit('5')),
                _btn('6', onPressed: () => _onDigit('6')),
                _btn('-', bg: const Color(0xFFEEF2FF), fg: const Color(0xFF4F46E5), onPressed: () => _onOperator('-')),
              ],
            ),
            Row(
              children: [
                _btn('1', onPressed: () => _onDigit('1')),
                _btn('2', onPressed: () => _onDigit('2')),
                _btn('3', onPressed: () => _onDigit('3')),
                _btn('+', bg: const Color(0xFFEEF2FF), fg: const Color(0xFF4F46E5), onPressed: () => _onOperator('+')),
              ],
            ),
            Row(
              children: [
                _btn('0', onPressed: () => _onDigit('0')),
                _btn('00', onPressed: () => _onDigit('00')),
                _btn('.', onPressed: _onDecimal),
                _btn('=', bg: const Color(0xFF4F46E5), fg: Colors.white, onPressed: _onEquals),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
