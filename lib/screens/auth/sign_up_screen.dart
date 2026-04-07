import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/auth_error_messages.dart';
import '../../providers/auth_provider.dart';

const _bg = Color(0xFFFAF9F7);
const _orange = Color(0xFFE8470A); // exact landing-page orange
const _black = Color(0xFF0A0A0A); // exact landing-page near-black
const _grey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final ok = await auth.signInWithGoogle();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the Google sign-in page. Check your browser or app settings.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyAuthMessage(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.signUpWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      // If Supabase requires email confirmation, user is not yet authenticated.
      // Show a message and stay on sign-up screen.
      if (!auth.isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created! Check your email to confirm, then sign in.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
        // Don't navigate — GoRouter will redirect when auth state changes.
        return;
      }
      // If auto-confirmed (e.g. dev mode), GoRouter's refreshListenable will
      // redirect automatically via the onAuthStateChange listener.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyAuthMessage(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 720;
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: wide ? _wideLayout() : _narrowLayout(),
      ),
    );
  }

  Widget _wideLayout() {
    return Row(
      children: [
        // Left brand panel
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F0F0F), Color(0xFF1C1C1C)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -60,
                  right: -40,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _orange.withOpacity(0.07),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  left: -40,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _orange.withOpacity(0.05),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _logo(light: true),
                      const Spacer(),
                      // Feature bullets
                      _featureBullet(Icons.verified_outlined,
                          'Blockchain-backed certificates'),
                      const SizedBox(height: 20),
                      _featureBullet(Icons.gavel_rounded, 'Run live auctions'),
                      const SizedBox(height: 20),
                      _featureBullet(Icons.groups_outlined,
                          'Build your artist guild'),
                      const SizedBox(height: 20),
                      _featureBullet(Icons.store_outlined,
                          'Sell globally — keep 95%'),
                      const SizedBox(height: 48),
                      // Social proof
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.format_quote,
                                color: _orange, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Sold 3 paintings in my first week.',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right form panel
        SizedBox(
          width: 480,
          child: Container(
            color: _bg,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 48),
                child: _formContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureBullet(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _orange, size: 18),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Outfit',
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            Center(child: _logo(light: false)),
            const SizedBox(height: 40),
            _formContent(),
          ],
        ),
      ),
    );
  }

  Widget _logo({required bool light}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'ARTYUG',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: light ? Colors.white : _black,
              letterSpacing: -0.5,
            ),
          ),
          const TextSpan(
            text: '.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create your\nart world.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: _black,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join 10 artists and 30 users already on the platform.',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: _grey),
          ),
          const SizedBox(height: 36),

          // Email
          _field(
            controller: _emailCtrl,
            label: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Password
          _field(
            controller: _passCtrl,
            label: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscurePass,
            suffix: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: _grey,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a password';
              if (v.length < 6) return 'At least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Confirm password
          _field(
            controller: _confirmCtrl,
            label: 'Confirm password',
            icon: Icons.lock_outline,
            obscure: _obscureConfirm,
            action: TextInputAction.done,
            onSubmit: (_) => _signUp(),
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: _grey,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _passCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 28),

          // CTA
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _signUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _orange.withOpacity(0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // OR
          Row(children: [
            const Expanded(child: Divider(color: _border)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text('OR',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: _grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            const Expanded(child: Divider(color: _border)),
          ]),
          const SizedBox(height: 20),

          // Google
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _googleSignIn,
              style: OutlinedButton.styleFrom(
                foregroundColor: _black,
                side: const BorderSide(color: _border, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Text('G',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _orange,
                  )),
              label: const Text(
                'Continue with Google',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Sign in link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Already have an account? ',
                  style: TextStyle(
                      fontFamily: 'Outfit', color: _grey, fontSize: 14)),
              GestureDetector(
                onTap: () => context.push('/sign-in'),
                child: const Text('Sign In',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _orange,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmit,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: action,
      obscureText: obscure,
      onFieldSubmitted: onSubmit,
      style: const TextStyle(fontFamily: 'Outfit', color: _black, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Outfit', color: _grey, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, size: 20, color: _grey),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _orange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}
