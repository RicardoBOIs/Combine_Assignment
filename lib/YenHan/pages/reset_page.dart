import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../widgets/fancy_button.dart';

class ResetPage extends StatefulWidget {
  const ResetPage({super.key});
  @override
  State<ResetPage> createState() => _ResetPageState();
}

class _ResetPageState extends State<ResetPage> {
  final _mail = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _sent = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset Password')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: _sent
          ? const Center(child: Text('Please check your email for reset password link'))
          : Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _mail,
              decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) =>
              v != null && v.contains('@') ? null : 'Email 格式不正确',
            ),
            const SizedBox(height: 24),
            FancyButton(
              text: 'Send Reset Link',
              onTap: () async {
                if (!_form.currentState!.validate()) return;
                await authService.value.resetPassword(email: _mail.text.trim());
                setState(() => _sent = true);
              },
            )
          ],
        ),
      ),
    ),
  );
}
