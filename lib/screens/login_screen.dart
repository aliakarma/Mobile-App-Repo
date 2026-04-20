import 'package:flutter/material.dart';

import '../services/auth_api_service.dart';
import '../services/auth_controller.dart';
import '../widgets/app_ui.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authController,
    required this.onOpenSignUp,
  });

  final AuthController authController;
  final VoidCallback onOpenSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authController.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyLoginError(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to log in. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _friendlyLoginError(AuthApiException error) {
    if (error.statusCode == 401) {
      return 'Invalid credentials. Please verify your email and password.';
    }
    return error.message;
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (text.isEmpty) {
      return 'Email is required.';
    }
    if (!emailRegex.hasMatch(text)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Password is required.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue managing your applications.',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(opacity: value.clamp(0, 1), child: child),
          );
        },
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  prefixIcon: const Icon(Icons.mail_outline),
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                ),
                const SizedBox(height: AppSpacing.s12),
                AuthTextField(
                  controller: _passwordController,
                  label: 'Password',
                  textInputAction: TextInputAction.done,
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  autofillHints: const [AutofillHints.password],
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip:
                        _obscurePassword ? 'Show password' : 'Hide password',
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                    ),
                    const Expanded(
                      child: Text('Remember me'),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Forgot password is not available yet. Please contact support.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _errorMessage == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                          child: Text(
                            _errorMessage!,
                            key: ValueKey<String>(_errorMessage!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                PrimaryLoadingButton(
                  onPressed: _submit,
                  label: 'Login',
                  icon: Icons.login,
                  isLoading: _isSubmitting,
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Need an account?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _isSubmitting ? null : widget.onOpenSignUp,
                      child: const Text('Create account'),
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
