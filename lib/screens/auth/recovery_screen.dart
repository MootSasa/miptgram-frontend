import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({Key? key}) : super(key: key);

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendRecoveryEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simulate API call - replace with actual gRPC call to backend
      await Future.delayed(const Duration(seconds: 2));

      // In a real app, you would call your backend service here
      // Example: await AuthService.sendRecoveryEmail(_emailController.text.trim());

      if (!mounted) return;

      final l10n = context.l10n;
      
      setState(() {
        _isLoading = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.translate('auth_recovery_email_sent')),
          backgroundColor: Colors.green,
        ),
      );

      // Optionally navigate to login screen after a delay
      // Future.delayed(const Duration(seconds: 2), () {
      //   Navigator.of(context).pop();
      // });
    } catch (e) {
      if (!mounted) return;

      final l10n = context.l10n;
      
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.translate('auth_recovery_email_failed')}: $_errorMessage'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('auth_password_recovery')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.translate('auth_enter_email_for_recovery'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: l10n.translate('auth_email'),
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: Color(0xFF0088CC), width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.translate('validation_enter_email');
                    }
                    // Simple email validation regex
                    final emailRegex = RegExp(
                      r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$',
                    );
                    if (!emailRegex.hasMatch(value)) {
                      return l10n.translate('validation_valid_email');
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendRecoveryEmail,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          l10n.translate('auth_send_recovery_email'),
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
