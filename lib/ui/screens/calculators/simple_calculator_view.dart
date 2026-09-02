import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/expressive_card.dart';

class SimpleCalculatorView extends StatefulWidget {
  const SimpleCalculatorView({super.key});

  @override
  State<SimpleCalculatorView> createState() => _SimpleCalculatorViewState();
}

class _SimpleCalculatorViewState extends State<SimpleCalculatorView> {
  String _display = '0';
  String _expression = '';
  double _firstOperand = 0;
  String? _pendingOperator;
  bool _shouldResetDisplay = false;
  double _memory = 0;
  String _fractionDisplay = '';

  void _onDigit(String digit) {
    setState(() {
      if (_display == '0' || _shouldResetDisplay) {
        _display = digit;
        _shouldResetDisplay = false;
      } else {
        _display += digit;
      }
      _updateFraction();
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
      _updateFraction();
    });
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _expression = '';
      _firstOperand = 0;
      _pendingOperator = null;
      _shouldResetDisplay = false;
      _fractionDisplay = '';
    });
  }

  void _onBackspace() {
    setState(() {
      if (_display.length > 1) {
        _display = _display.substring(0, _display.length - 1);
      } else {
        _display = '0';
      }
      _updateFraction();
    });
  }

  void _onToggleSign() {
    setState(() {
      if (_display != '0') {
        if (_display.startsWith('-')) {
          _display = _display.substring(1);
        } else {
          _display = '-$_display';
        }
      }
      _updateFraction();
    });
  }

  void _onSqrt() {
    setState(() {
      final val = double.tryParse(_display) ?? 0;
      if (val >= 0) {
        final res = math.sqrt(val);
        _expression = '√($val)';
        _display = _formatResult(res);
        _shouldResetDisplay = true;
        _updateFraction();
      }
    });
  }

  void _onSquare() {
    setState(() {
      final val = double.tryParse(_display) ?? 0;
      final res = val * val;
      _expression = 'sqr($val)';
      _display = _formatResult(res);
      _shouldResetDisplay = true;
      _updateFraction();
    });
  }

  void _onReciprocal() {
    setState(() {
      final val = double.tryParse(_display) ?? 0;
      if (val != 0) {
        final res = 1.0 / val;
        _expression = '1/($val)';
        _display = _formatResult(res);
        _shouldResetDisplay = true;
        _updateFraction();
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      final currentVal = double.tryParse(_display) ?? 0;
      if (_pendingOperator != null && !_shouldResetDisplay) {
        _executeCalculation();
      } else {
        _firstOperand = currentVal;
      }
      _pendingOperator = op;
      _expression = '${_formatResult(_firstOperand)} $op';
      _shouldResetDisplay = true;
      _updateFraction();
    });
  }

  void _onEquals() {
    setState(() {
      _executeCalculation();
    });
  }

  /// Unit-conversion button: multiplies the current display by [factor].
  /// `mm` divides by 25.4 (mm→in); `in` multiplies by 25.4 (in→mm).
  void _convertDisplay(double factor) {
    setState(() {
      final val = double.tryParse(_display) ?? 0;
      _display = _formatResult(val * factor);
      _shouldResetDisplay = true;
      _updateFraction();
    });
  }

  void _executeCalculation() {
    if (_pendingOperator == null) return;
    final secondOperand = double.tryParse(_display) ?? 0;
    double result = 0;

    switch (_pendingOperator) {
      case '+':
        result = _firstOperand + secondOperand;
        break;
      case '-':
        result = _firstOperand - secondOperand;
        break;
      case '×':
        result = _firstOperand * secondOperand;
        break;
      case '÷':
        if (secondOperand != 0) {
          result = _firstOperand / secondOperand;
        } else {
          _display = 'Error';
          _pendingOperator = null;
          _shouldResetDisplay = true;
          _fractionDisplay = '';
          return;
        }
        break;
    }

    _expression = '${_formatResult(_firstOperand)} $_pendingOperator ${_formatResult(secondOperand)} =';
    _display = _formatResult(result);
    _firstOperand = result;
    _pendingOperator = null;
    _shouldResetDisplay = true;
    _updateFraction();
  }

  void _updateFraction() {
    final val = double.tryParse(_display);
    if (val != null) {
      _fractionDisplay = _decimalToFraction(val);
    } else {
      _fractionDisplay = '';
    }
  }

  String _decimalToFraction(double val) {
    if (val.isNaN || val.isInfinite) return '';
    final isNegative = val < 0;
    final absVal = val.abs();
    final integerPart = absVal.floor();
    final decimalPart = absVal - integerPart;

    if (decimalPart < 0.0001) {
      return '${isNegative ? '-' : ''}$integerPart"';
    }

    // Standard fractional inches up to 64ths
    const maxDenominator = 64;
    int bestNumerator = (decimalPart * maxDenominator).round();
    int bestDenominator = maxDenominator;

    if (bestNumerator == 0) {
      return '${isNegative ? '-' : ''}$integerPart"';
    }
    if (bestNumerator == maxDenominator) {
      return '${isNegative ? '-' : ''}${integerPart + 1}"';
    }

    int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
    final divisor = gcd(bestNumerator, bestDenominator);
    bestNumerator ~/= divisor;
    bestDenominator ~/= divisor;

    final approxError = (absVal - (integerPart + (bestNumerator / bestDenominator))).abs();
    final approxPrefix = approxError > 0.001 ? '≈ ' : '';

    if (integerPart == 0) {
      return '$approxPrefix${isNegative ? '-' : ''}$bestNumerator/$bestDenominator"';
    } else {
      return '$approxPrefix${isNegative ? '-' : ''}$integerPart $bestNumerator/$bestDenominator"';
    }
  }

  String _formatResult(double val) {
    if (val.isNaN || val.isInfinite) return 'Error';
    if (val == val.toInt().toDouble()) {
      return val.toInt().toString();
    }
    final formatter = NumberFormat('0.########');
    return formatter.format(val);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Calculator LCD Display Card
          ExpressiveCard(
            isGlowing: true,
            glowColor: AppTheme.of(context).primary,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (_memory != 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.of(context).emerald.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('M', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.of(context).emerald)),
                          ),
                    ],
                    ),
                    Text(
                      _expression,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.of(context).textSecondary : AppTheme.of(context).textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Main Number Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy_rounded, size: 18, color: AppTheme.of(context).primary),
                      tooltip: 'Copy Result',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _display));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied "$_display" to clipboard'), duration: const Duration(seconds: 1)),
                        );
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SelectableText(
                            _display,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                              color: isDark ? Colors.white : AppTheme.of(context).textPrimary,
                            ),
                          ),
                          if (_fractionDisplay.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Fraction (Inch): $_fractionDisplay',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.of(context).amber,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Unit Conversion & Memory Row
          Row(
            children: [
              _buildBtn('mm', () => _convertDisplay(1 / 25.4), isSmall: true, tooltip: 'mm → in (÷25.4)'),
              const SizedBox(width: 8),
              _buildBtn('in', () => _convertDisplay(25.4), isSmall: true, tooltip: 'in → mm (×25.4)'),
              const SizedBox(width: 8),
              _buildBtn('M+', () => setState(() => _memory += double.tryParse(_display) ?? 0), isSmall: true),
              const SizedBox(width: 8),
              _buildBtn('M-', () => setState(() => _memory -= double.tryParse(_display) ?? 0), isSmall: true),
            ],
          ),
          const SizedBox(height: 8),

          // Keypad Rows
          Column(
            children: [
              // Row 1: Clear & Backspace — take full width of their row
              Row(
                children: [
                  _buildBtn('CE / C', _onClear, isCoral: true),
                  const SizedBox(width: 8),
                  _buildBtn('⌫', _onBackspace, isOperator: true),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Powers, Roots, Divide
              Row(
                children: [
                  _buildBtn('1/x', _onReciprocal, isOperator: true),
                  const SizedBox(width: 8),
                  _buildBtn('x²', _onSquare, isOperator: true),
                  const SizedBox(width: 8),
                  _buildBtn('√x', _onSqrt, isOperator: true),
                  const SizedBox(width: 8),
                  _buildBtn('÷', () => _onOperator('÷'), isCyan: true),
                ],
              ),
              const SizedBox(height: 8),

              // Row 3: 7, 8, 9, Multiply
              Row(
                children: [
                  _buildBtn('7', () => _onDigit('7')),
                  const SizedBox(width: 8),
                  _buildBtn('8', () => _onDigit('8')),
                  const SizedBox(width: 8),
                  _buildBtn('9', () => _onDigit('9')),
                  const SizedBox(width: 8),
                  _buildBtn('×', () => _onOperator('×'), isCyan: true),
                ],
              ),
              const SizedBox(height: 8),

              // Row 4: 4, 5, 6, Minus
              Row(
                children: [
                  _buildBtn('4', () => _onDigit('4')),
                  const SizedBox(width: 8),
                  _buildBtn('5', () => _onDigit('5')),
                  const SizedBox(width: 8),
                  _buildBtn('6', () => _onDigit('6')),
                  const SizedBox(width: 8),
                  _buildBtn('-', () => _onOperator('-'), isCyan: true),
                ],
              ),
              const SizedBox(height: 8),

              // Row 5: 1, 2, 3, Plus
              Row(
                children: [
                  _buildBtn('1', () => _onDigit('1')),
                  const SizedBox(width: 8),
                  _buildBtn('2', () => _onDigit('2')),
                  const SizedBox(width: 8),
                  _buildBtn('3', () => _onDigit('3')),
                  const SizedBox(width: 8),
                  _buildBtn('+', () => _onOperator('+'), isCyan: true),
                ],
              ),
              const SizedBox(height: 8),

              // Row 6: ±, 0, ., Equals (=)
              Row(
                children: [
                  _buildBtn('±', _onToggleSign),
                  const SizedBox(width: 8),
                  _buildBtn('0', () => _onDigit('0')),
                  const SizedBox(width: 8),
                  _buildBtn('.', _onDecimal),
                  const SizedBox(width: 8),
                  _buildBtn('=', _onEquals, isEmerald: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(
    String label,
    VoidCallback onTap, {
    bool isOperator = false,
    bool isCyan = false,
    bool isEmerald = false,
    bool isCoral = false,
    bool isAmber = false,
    bool isSmall = false,
    String? tooltip,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;

    if (isEmerald) {
      bg = AppTheme.of(context).emerald;
      fg = Colors.black87;
    } else if (isAmber) {
      bg = AppTheme.of(context).amber;
      fg = Colors.black87;
    } else if (isCoral) {
      bg = AppTheme.of(context).coral.withValues(alpha: 0.2);
      fg = AppTheme.of(context).coral;
    } else if (isCyan) {
      bg = AppTheme.of(context).primary.withValues(alpha: 0.25);
      fg = isDark ? AppTheme.of(context).primary : AppTheme.of(context).primaryBlue;
    } else if (isOperator) {
      bg = isDark ? AppTheme.of(context).surfaceVariant : AppTheme.of(context).surfaceVariant;
      fg = isDark ? Colors.white : Colors.black87;
    } else {
      bg = isDark ? AppTheme.of(context).surface : AppTheme.of(context).surface;
      fg = isDark ? Colors.white : Colors.black87;
    }

    final button = SizedBox(
      height: isSmall ? 36 : 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            side: BorderSide(
              color: isDark ? AppTheme.of(context).border : AppTheme.of(context).border,
              width: 0.8,
            ),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 11 : 16,
            fontWeight: (isOperator || isEmerald || isCyan || isAmber) ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );

    return Expanded(
      child: tooltip == null ? button : Tooltip(message: tooltip, child: button),
    );
  }

}
