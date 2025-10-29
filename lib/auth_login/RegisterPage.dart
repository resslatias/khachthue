import 'package:flutter/material.dart';
import 'AuthService.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtl   = TextEditingController();
  final _emailCtl  = TextEditingController();
  final _phoneCtl  = TextEditingController();
  final _passCtl   = TextEditingController();
  final _repassCtl = TextEditingController();

  bool _ob1 = true; // ẩn/hiện mật khẩu
  bool _ob2 = true; // ẩn/hiện xác nhận
  bool _loading = false;
  String? _error;

  final _auth = AuthService();

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _passCtl.dispose();
    _repassCtl.dispose();
    super.dispose();
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ok = await _auth.signUp(
        hoTen: _nameCtl.text.trim(),
        email: _emailCtl.text.trim(),
        password: _passCtl.text,
        soDienThoai: _phoneCtl.text.trim(),
      );

      if (!mounted) return;

      if (ok) {
        // về màn gốc (Shell/main)
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
        // (tuỳ chọn) toast/snackbar
        // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng ký thành công!')));
      } else {
        setState(() => _error = _auth.lastError ?? 'Đăng ký thất bại');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Đăng ký thất bại: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Icon(Icons.sports_tennis, size: 64, color: cs.primary),
                  const SizedBox(height: 10),
                  Text(
                    'Tạo tài khoản mới',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 22),

                  // Họ và tên
                  TextFormField(
                    controller: _nameCtl,
                    decoration: _decoration(label: 'Họ và tên', icon: Icons.person),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập họ tên';
                      if (v.trim().length < 2) return 'Họ tên quá ngắn';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextFormField(
                    controller: _emailCtl,
                    decoration: _decoration(label: 'Email', icon: Icons.email),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                      final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                      if (!ok) return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Số điện thoại (tuỳ chọn)
                  TextFormField(
                    controller: _phoneCtl,
                    decoration: _decoration(label: 'Số điện thoại (tuỳ chọn)', icon: Icons.phone),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  const SizedBox(height: 12),

                  // Mật khẩu
                  TextFormField(
                    controller: _passCtl,
                    obscureText: _ob1,
                    decoration: _decoration(
                      label: 'Mật khẩu',
                      icon: Icons.lock,
                      suffix: IconButton(
                        onPressed: () => setState(() => _ob1 = !_ob1),
                        icon: Icon(_ob1 ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                      if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Xác nhận mật khẩu
                  TextFormField(
                    controller: _repassCtl,
                    obscureText: _ob2,
                    decoration: _decoration(
                      label: 'Nhập lại mật khẩu',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        onPressed: () => setState(() => _ob2 = !_ob2),
                        icon: Icon(_ob2 ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _loading ? null : _onRegister(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vui lòng nhập lại mật khẩu';
                      if (v != _passCtl.text) return 'Mật khẩu không trùng khớp';
                      return null;
                    },
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[100]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[700]))),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: _loading ? null : _onRegister,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Tạo tài khoản', style: TextStyle(fontSize: 16)),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Đã có tài khoản?'),
                      TextButton(
                        onPressed: _loading ? null : () => Navigator.of(context).pop(),
                        child: Text('Đăng nhập ngay', style: TextStyle(color: cs.primary)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'Lưu ý: Sau khi đăng ký, hãy kiểm tra hộp thư để xác minh email.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
