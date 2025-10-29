import 'package:flutter/material.dart';
import 'AuthService.dart'; // chỉnh đường dẫn nếu file của bạn khác

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl  = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  final _auth = AuthService();

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });
    try {
      final ok = await _auth.signIn(
        email: _emailCtl.text.trim(),
        password: _passCtl.text,
      );
      if (!mounted) return;
      if (ok) {
        // Quay về màn gốc (Shell/main)
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      } else {
        setState(() => _error = _auth.lastError ?? 'Đăng nhập thất bại');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Đăng nhập thất bại: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onForgotPassword() async {
    final email = _emailCtl.text.trim();
    final controller = TextEditingController(text: email);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đặt lại mật khẩu'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email tài khoản',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final mail = controller.text.trim();
              if (mail.isEmpty) return;
              await _auth.sendResetPassword(mail);
              if (!mounted) return;
              Navigator.pop(ctx);
              final msg = _auth.lastError == null
                  ? 'Đã gửi email đặt lại mật khẩu'
                  : _auth.lastError!;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }

  void _goRegister() {
    // Dùng route tên nếu bạn đã khai báo '/register' trong MaterialApp.routes
    Navigator.of(context, rootNavigator: true).pushNamed('/register');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Icon(Icons.sports_tennis, size: 64, color: cs.primary),
                const SizedBox(height: 12),
                Text(
                  'Chào mừng trở lại',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Email
                TextFormField(
                  controller: _emailCtl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim());
                    if (!ok) return 'Email không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Mật khẩu
                TextFormField(
                  controller: _passCtl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _loading ? null : _onLogin(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                    if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                    return null;
                  },
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _onForgotPassword,
                    child: const Text('Quên mật khẩu?'),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],

                const SizedBox(height: 12),

                FilledButton(
                  onPressed: _loading ? null : _onLogin,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Đăng nhập', style: TextStyle(fontSize: 16)),
                ),

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chưa có tài khoản?'),
                    TextButton(
                      onPressed: _loading ? null : _goRegister,
                      child: Text('Đăng ký ngay', style: TextStyle(color: cs.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
