import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_api_service.dart';
import '../services/auth_controller.dart';
import '../widgets/app_ui.dart';
import '../widgets/auth_widgets.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    super.key,
    required this.authController,
    required this.onOpenLogin,
  });

  final AuthController authController;
  final VoidCallback onOpenLogin;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();
    try {
      await widget.authController.signUp(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );
      HapticFeedback.mediumImpact();
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlySignUpError(error);
      });
      HapticFeedback.heavyImpact();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to create account. Please try again.';
      });
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _friendlySignUpError(AuthApiException error) {
    if (error.statusCode == 409) {
      final detail = error.message.toLowerCase();
      if (detail.contains('already exists')) {
        return 'An account with this email already exists.';
      }
    }
    return error.message;
  }

  int _passwordStrength(String password) {
    if (password.isEmpty) {
      return 0;
    }

    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score;
  }

  String _passwordStrengthLabel(int score) {
    if (score <= 1) return 'Weak';
    if (score <= 3) return 'Medium';
    return 'Strong';
  }

  Color _passwordStrengthColor(int score) {
    if (score <= 1) return const Color(0xFFC62828);
    if (score <= 3) return const Color(0xFFF57C00);
    return const Color(0xFF2E7D32);
  }

  String? _validateFullName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Full name is required.';
    }
    if (text.length < 2) {
      return 'Full name must be at least 2 characters.';
    }
    return null;
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
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final passwordStrength = _passwordStrength(_passwordController.text);

    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Get started with your smart application workflow.',
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
                  controller: _fullNameController,
                  label: 'Full name',
                  textInputAction: TextInputAction.next,
                  validator: _validateFullName,
                  prefixIcon: const Icon(Icons.person_outline),
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: AppSpacing.s12),
                AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  prefixIcon: const Icon(Icons.mail_outline),
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                AuthTextField(
                  controller: _passwordController,
                  label: 'Password',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 6,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: passwordStrength / 5,
                      child: Container(
                        color: _passwordStrengthColor(passwordStrength),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Password strength: ${_passwordStrengthLabel(passwordStrength)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _passwordStrengthColor(passwordStrength),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.s12),
                AuthTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm password',
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirmPassword,
                  onFieldSubmitted: (_) => _submit(),
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  autofillHints: const [AutofillHints.newPassword],
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscureConfirmPassword
                        ? 'Show password'
                        : 'Hide password',
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _rememberMe,
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                  title: const Text('Keep me signed in on this device'),
                  controlAffinity: ListTileControlAffinity.leading,
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
                  label: 'Create account',
                  icon: Icons.person_add_alt_1,
                  isLoading: _isSubmitting,
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _isSubmitting ? null : widget.onOpenLogin,
                      child: const Text('Login'),
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
