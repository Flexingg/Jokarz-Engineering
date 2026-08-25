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

  void _onClear() {
    setState(() {
      _display = '0';
      _expression = '';
      _firstOperand = 0;
      _pendingOperator = null;
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

  void _onToggleSign() {
    setState(() {
      if (_display != '0') {
        if (_display.startsWith('-')) {
          _display = _display.substring(1);
        } else {
          _display = '-$_display';
        }
      }
    });
  }

  void _onPercent() {
    setState(() {
      final val = double.tryParse(_display) ?? 0;
      _display = (val / 100).toString();
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
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      final currentVal = double.tryParse(_display) ?? 0;
      if (_pendingOperator != null && !_shouldResetDisplay) {
        _calculate();
      } else {
        _firstOperand = currentVal;
      }
      _pendingOperator = op;
      _expression = '${_formatResult(_firstOperand)} $op';
      _shouldResetDisplay = true;
    });
  }

  void _calculate() {
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
          return;
        }
        break;
    }

    _expression = '${_formatResult(_firstOperand)} $_pendingOperator ${_formatResult(secondOperand)} =';
    _display = _formatResult(result);
    _firstOperand = result;
    _pendingOperator = null;
    _shouldResetDisplay = true;
  }

  String _formatResult(double val) {
    if (val.isNaN || val.isInfinite) return 'Error';
    if (val == val.toInt().toDouble()) {
      return val.toInt().toString();
    }
    // Limit decimals cleanly
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
            glowColor: AppTheme.primaryCyan,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_memory != 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentEmerald.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('M', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentEmerald)),
                      )
                    else
                      const SizedBox(),
                    Text(
                      _expression,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primaryCyan),
                      tooltip: 'Copy Value',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _display));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied "$_display" to clipboard'), duration: const Duration(seconds: 1)),
                        );
                      },
                    ),
                    Expanded(
                      child: SelectableText(
                        _display,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Memory & Scientific Quick Functions Row
          Row(
            children: [
              _buildBtn('MC', () => setState(() => _memory = 0), isAccent: false, isSmall: true),
              const SizedBox(width: 8),
              _buildBtn('MR', () => setState(() => _display = _formatResult(_memory)), isAccent: false, isSmall: true),
              const SizedBox(width: 8),
              _buildBtn('M+', () => setState(() => _memory += double.tryParse(_display) ?? 0), isAccent: false, isSmall: true),
              const SizedBox(width: 8),
              _buildBtn('M-', () => setState(() => _memory -= double.tryParse(_display) ?? 0), isAccent: false, isSmall: true),
            ],
          ),
          const SizedBox(height: 8),

          // Keypad Grid
          Column(
            children: [
              Row(
                children: [
                  _buildBtn('%', _onPercent, isOperator: true),
                  const SizedBox(width: 8),
                  _buildBtn('CE / C', _onClear, isCoral: true),
                  const SizedBox(width: 8),
                  _buildBtn('⌫', _onBackspace, isOperator: true),
                  const SizedBox(width: 8),
                  _buildBtn('÷', () => _onOperator('÷'), isOperator: true, isCyan: true),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildBtn('1/x', _onReciprocal, isOperator: true),
                  const SizedBox(width: 8),
                  _buildBtn('x²', _onSquare, isOperator: true),
                  const SizedBox(width: 8),
                  _buildBtn('√x', _onSqrt, isOperator: true),
                  const SizedBox(width: 8),
                  _buildBtn('×', () => _onOperator('×'), isOperator: true, isCyan: true),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildBtn('7', () => _onDigit('7')),
                  const SizedBox(width: 8),
                  _buildBtn('8', () => _onDigit('8')),
                  const SizedBox(width: 8),
                  _buildBtn('9', () => _onDigit('9')),
                  const SizedBox(width: 8),
                  _buildBtn('-', () => _onOperator('-'), isOperator: true, isCyan: true),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildBtn('4', () => _onDigit('4')),
                  const SizedBox(width: 8),
                  _buildBtn('5', () => _onDigit('5')),
                  const SizedBox(width: 8),
                  _buildBtn('6', () => _onDigit('6')),
                  const SizedBox(width: 8),
                  _buildBtn('+', () => _onOperator('+'), isOperator: true, isCyan: true),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildBtn('1', () => _onDigit('1')),
                  const SizedBox(width: 8),
                  _buildBtn('2', () => _onDigit('2')),
                  const SizedBox(width: 8),
                  _buildBtn('3', () => _onDigit('3')),
                  const SizedBox(width: 8),
                  _buildBtn('=', _calculate, isEmerald: true),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildBtn('±', _onToggleSign),
                  const SizedBox(width: 8),
                  _buildBtn('0', () => _onDigit('0')),
                  const SizedBox(width: 8),
                  _buildBtn('.', _onDecimal),
                  const SizedBox(width: 8),
                  _buildBtn('=', _calculate, isEmerald: true),
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
    bool isAccent = false,
    bool isSmall = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;

    if (isEmerald) {
      bg = AppTheme.accentEmerald;
      fg = Colors.black87;
    } else if (isCoral) {
      bg = AppTheme.accentCoral.withValues(alpha: 0.2);
      fg = AppTheme.accentCoral;
    } else if (isCyan) {
      bg = AppTheme.primaryCyan.withValues(alpha: 0.25);
      fg = isDark ? AppTheme.primaryCyan : AppTheme.primaryBlue;
    } else if (isOperator) {
      bg = isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant;
      fg = isDark ? Colors.white : Colors.black87;
    } else {
      bg = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
      fg = isDark ? Colors.white : Colors.black87;
    }

    return Expanded(
      child: SizedBox(
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
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 0.8,
              ),
            ),
          ),
          onPressed: onTap,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 11 : 17,
              fontWeight: (isOperator || isEmerald || isCyan) ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
