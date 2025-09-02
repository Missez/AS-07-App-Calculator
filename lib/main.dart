
import 'package:flutter/material.dart';

void main() => runApp(const CalculatorApp());

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF7C4DFF),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.w600),
        displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calculator',
      theme: theme,
      home: const CalculatorPage(),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});
  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  String _expression = '';
  String _display = '0';

// เดิม: final List<_KeyDef> _keys = const [ ... ];
final List<_KeyDef> _keys = [
  _KeyDef('C',  kind: KeyKind.func),
  _KeyDef('%',  kind: KeyKind.op),
  _KeyDef('DEL',kind: KeyKind.func),
  _KeyDef('/',  kind: KeyKind.op),
  _KeyDef('7'), _KeyDef('8'), _KeyDef('9'), _KeyDef('*', kind: KeyKind.op),
  _KeyDef('4'), _KeyDef('5'), _KeyDef('6'), _KeyDef('-', kind: KeyKind.op),
  _KeyDef('1'), _KeyDef('2'), _KeyDef('3'), _KeyDef('+', kind: KeyKind.op),
  _KeyDef('00'), _KeyDef('0'), _KeyDef('.'), _KeyDef('=', kind: KeyKind.equals),
];

  void _onKeyTap(String v, KeyKind kind) {
    setState(() {
      if (kind == KeyKind.equals) {
        _evaluate();
        return;
      }
      if (v == 'C') {
        _expression = '';
        _display = '0';
        return;
      }
      if (v == 'DEL') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _display = _expression.isEmpty ? '0' : _expression;
        }
        return;
      }
      if (v == '%') {
        // แปลงเลขล่าสุดให้เป็นเปอร์เซ็นต์ (หาร 100)
        _expression = _applyPercent(_expression);
        _display = _expression.isEmpty ? '0' : _expression;
        return;
      }
      // ป้องกันโอเปอเรเตอร์ซ้อนกัน
      if (_isOperator(v)) {
        if (_expression.isEmpty) return;
        if (_isOperator(_expression.characters.last)) {
          _expression = _expression.substring(0, _expression.length - 1) + v;
        } else {
          _expression += v;
        }
      } else {
        // จุดทศนิยม: ห้ามมีหลายจุดใน segment ล่าสุด
        if (v == '.' && _lastNumberHasDot(_expression)) return;
        _expression += v;
      }
      _display = _expression.isEmpty ? '0' : _expression;
    });
  }

  bool _isOperator(String s) => s == '+' || s == '-' || s == '*' || s == '/';

  bool _lastNumberHasDot(String expr) {
    int i = expr.length - 1;
    while (i >= 0 && !_isOperator(expr[i])) {
      if (expr[i] == '.') return true;
      i--;
    }
    return false;
  }

  String _applyPercent(String expr) {
    if (expr.isEmpty) return expr;
    int i = expr.length - 1;
    while (i >= 0 && !_isOperator(expr[i])) i--;
    final left = expr.substring(0, i + 1);
    final numStr = expr.substring(i + 1);
    if (numStr.isEmpty) return expr;
    final val = double.tryParse(numStr);
    if (val == null) return expr;
    final p = (val / 100.0).toString();
    return left + _trimNumber(p);
  }

  void _evaluate() {
    if (_expression.isEmpty) return;
    // ตัดท้ายถ้าเป็นโอเปอเรเตอร์
    String expr = _expression;
    if (_isOperator(expr.characters.last)) {
      expr = expr.substring(0, expr.length - 1);
    }
    try {
      final result = _evalInfix(expr);
      _display = _trimNumber(result.toString());
      _expression = _display; // chain ต่อได้
    } catch (_) {
      _display = 'Error';
      // ไม่เปลี่ยน _expression เพื่อให้แก้ต่อได้
    }
  }

  /// ประเมินนิพจน์ infix ด้วย two-stack (Shunting-yard light)
  double _evalInfix(String expr) {
    final nums = <double>[];
    final ops = <String>[];

    int i = 0;
    while (i < expr.length) {
      final ch = expr[i];
      if (ch == ' ') {
        i++;
        continue;
      }
      if (_isOperator(ch)) {
        while (ops.isNotEmpty && _precedence(ops.last) >= _precedence(ch)) {
          _collapse(nums, ops.removeLast());
        }
        ops.add(ch);
        i++;
      } else {
        // number (supports decimal)
        final sb = StringBuffer();
        while (i < expr.length &&
            (RegExp(r'[0-9.]').hasMatch(expr[i]))) {
          sb.write(expr[i]);
          i++;
        }
        final n = double.parse(sb.toString());
        nums.add(n);
      }
    }
    while (ops.isNotEmpty) {
      _collapse(nums, ops.removeLast());
    }
    if (nums.isEmpty) throw Exception('bad expr');
    return nums.last;
  }

  int _precedence(String op) => (op == '+' || op == '-') ? 1 : 2;

  void _collapse(List<double> nums, String op) {
    if (nums.length < 2) throw Exception('bad expr');
    final b = nums.removeLast();
    final a = nums.removeLast();
    switch (op) {
      case '+':
        nums.add(a + b);
        break;
      case '-':
        nums.add(a - b);
        break;
      case '*':
        nums.add(a * b);
        break;
      case '/':
        if (b == 0) {
          nums.add(double.nan);
        } else {
          nums.add(a / b);
        }
        break;
    }
  }

  String _trimNumber(String s) {
    if (s == 'NaN' || s == 'Infinity' || s == '-Infinity') return 'Error';
    if (s.contains('.')) {
      // ตัดศูนย์ท้าย
      s = s.replaceFirst(RegExp(r'\.0+$'), '');
      s = s.replaceFirst(RegExp(r'(\.\d*?[1-9])0+$'), r'\1');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    // จำกัดความยาวแสดงผล
    if (s.length > 16) {
      final d = double.tryParse(s);
      if (d != null) {
        s = d.toStringAsPrecision(10);
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Display
              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.surfaceContainerHighest,
                        cs.surface,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    alignment: Alignment.bottomRight,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _display,
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge!
                          .copyWith(letterSpacing: 1.2),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Keyboard
              Expanded(
                flex: 5,
                child: GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  padding: const EdgeInsets.only(bottom: 6),
                  children: _keys.map((k) {
                    final isOp = k.kind == KeyKind.op || k.kind == KeyKind.equals;
                    final bg = switch (k.label) {
                      'C' => Colors.redAccent,
                      'DEL' => Colors.orangeAccent,
                      '=' => Colors.greenAccent,
                      _ => isOp
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                    };
                    final fg = (k.label == '=')
                        ? Colors.black
                        : Theme.of(context).colorScheme.onSurface;

                    return CalculatorButton(
                      label: k.label,
                      background: bg,
                      foreground: fg,
                      onTap: () => _onKeyTap(k.label, k.kind),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalculatorButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const CalculatorButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

enum KeyKind { num, op, func, equals }

class _KeyDef {
  final String label;
  final KeyKind kind;

  _KeyDef(this.label, {KeyKind? kind})
      : kind = kind ??
            (label == '='
                ? KeyKind.equals
                : (label == 'C' || label == 'DEL'
                    ? KeyKind.func
                    : (label == '+' ||
                           label == '-' ||
                           label == '*' ||
                           label == '/' ||
                           label == '%'
                        ? KeyKind.op
                        : KeyKind.num)));
}
