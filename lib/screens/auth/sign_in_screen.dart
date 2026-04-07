import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/auth_error_messages.dart';
import '../../providers/auth_provider.dart';

// ─── Design tokens (light/white+orange) ─────────────────────────────────────
const _bg = Color(0xFFFAF9F7);
const _orange = Color(0xFFE8470A); // exact landing-page orange
const _black = Color(0xFF0A0A0A); // exact landing-page near-black
const _grey = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);
const _fieldBg = Color(0xFFFFFFFF);

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
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
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      // signInWithEmail throws on bad credentials — do NOT navigate manually.
      // GoRouter's refreshListenable fires after onAuthStateChange and redirects.
      await auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      // If we are still mounted and auth didn't redirect yet, push it manually
      // (edge case: router may not have re-evaluated yet on web).
      if (!mounted) return;
      // Wait a tick for the provider to update, then let GoRouter redirect handle it.
      // Don't call context.go() here — it races with the router's refreshListenable.
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

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }
    try {
      await Provider.of<AuthProvider>(context, listen: false)
          .resetPassword(_emailCtrl.text.trim());
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Check your inbox',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            content: const Text(
              'A password reset link was sent to your email address.',
              style: TextStyle(color: _grey, fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it', style: TextStyle(color: _orange)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyAuthMessage(e))),
        );
      }
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

  // ── Wide (desktop/tablet) ──────────────────────────────────────────────────
  Widget _wideLayout() {
    return Row(
      children: [
        // Left panel — brand artwork
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F0F0F), Color(0xFF1A1A1A)],
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  top: -60,
                  left: -60,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _orange.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  right: -40,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _orange.withOpacity(0.06),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _logo(light: true),
                      const Spacer(),
                      const Text(
                        'The operating\nsystem for\ntrusted art.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Sell. Auction. Certify.\nAll in one platform.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          color: Colors.white54,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _statRow(),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right panel — form
        SizedBox(
          width: 480,
          child: _formPanel(),
        ),
      ],
    );
  }

  Widget _statRow() {
    return Row(
      children: [
        _stat('10', 'Artists'),
        const SizedBox(width: 32),
        _stat('₹90k+', 'Revenue'),
        const SizedBox(width: 32),
        _stat('30', 'Users'),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _orange,
            )),
        Text(label,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: Colors.white54,
            )),
      ],
    );
  }

  // ── Narrow (mobile) ────────────────────────────────────────────────────────
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

  Widget _formPanel() {
    return Container(
      color: _bg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 48),
          child: _formContent(),
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
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: light ? Colors.white : _black,
              letterSpacing: -0.26, // -0.01em
            ),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 26,
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
          // Headline
          const Text(
            'Welcome\nback.',
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
            'Your art world is waiting.',
            style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: _grey),
          ),
          const SizedBox(height: 36),

          // Email
          _field(
            controller: _emailCtrl,
            label: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            action: TextInputAction.next,
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
            obscure: _obscure,
            action: TextInputAction.done,
            onSubmit: (_) => _signIn(),
            suffix: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: _grey,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your password' : null,
          ),
          const SizedBox(height: 10),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _forgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: _orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // CTA
          _ctaButton(
            label: 'Sign In',
            loading: _loading,
            onTap: _signIn,
          ),
          const SizedBox(height: 20),

          // OR divider
          _orDivider(),
          const SizedBox(height: 20),

          // Google
          _googleButton(),
          const SizedBox(height: 36),

          // Sign up link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account? ",
                  style: TextStyle(fontFamily: 'Outfit', color: _grey, fontSize: 14)),
              GestureDetector(
                onTap: () => context.push('/sign-up'),
                child: const Text('Sign Up',
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
        fillColor: _fieldBg,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }

  Widget _ctaButton({
    required String label,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _orange.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _orDivider() {
    return Row(children: [
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
    ]);
  }

  Widget _googleButton() {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
          foregroundColor: _black,
          side: const BorderSide(color: _border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _googleIcon(),
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
    );
  }

  Widget _googleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text(
        'G',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _orange,
        ),
      ),
    );
  }
}
