import 'package:flutter/material.dart';
import '../../core/auth_repository.dart';
import '../../core/auth_session.dart';
import '../splash/splash_screen.dart';

class MandatoryPasswordPage extends StatefulWidget {
  const MandatoryPasswordPage({super.key, required this.session});
  final AuthSession session;
  @override
  State<MandatoryPasswordPage> createState() => _MandatoryPasswordState();
}

class _MandatoryPasswordState extends State<MandatoryPasswordPage> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, visible = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.setMandatoryPassword(password.text);
      if (mounted) {
        password.clear();
        confirmation.clear();
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is HttpError
              ? failure.message
              : 'Your update could not be confirmed. Try again or sign out and use password recovery.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AutofillGroup(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: CreoWordmark(fontSize: 32),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Password update required',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose a new password before opening your workspace. Use 8–128 characters with a letter and a number.',
                    ),
                    const SizedBox(height: 24),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    TextFormField(
                      key: const Key('mandatory-password'),
                      controller: password,
                      enabled: !busy,
                      obscureText: !visible,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          tooltip: visible ? 'Hide password' : 'Show password',
                          onPressed: () => setState(() => visible = !visible),
                          icon: Icon(
                            visible ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value == null ||
                              value.length < 8 ||
                              value.length > 128 ||
                              !RegExp('[a-zA-Z]').hasMatch(value) ||
                              !RegExp('[0-9]').hasMatch(value)
                          ? 'Use 8–128 characters with a letter and a number.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const Key('mandatory-confirmation'),
                      controller: confirmation,
                      enabled: !busy,
                      obscureText: !visible,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => submit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                      ),
                      validator: (value) => value == password.text
                          ? null
                          : 'Passwords must match.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(
                        busy ? 'Updating password…' : 'Update password',
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.session.logout(),
                      child: const Text('Sign out on this device'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
