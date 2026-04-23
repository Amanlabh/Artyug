import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/auth_error_messages.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_background.dart';

const _cardBg = Color(0xFF101216);
const _cardBorder = Color(0xFF1C1F26);
const _primaryText = Color(0xFFE9EAF0);
const _mutedText = Color(0xFF9DA3B2);
const _lineColor = Color(0xFF2B3040);
const _accent = Color(0xFFFF5A1F);
const _accentSoft = Color(0xFFFFB29A);

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
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
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
      await auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // ── CRED-style animated orb background ──────────────────────────
            const Positioned.fill(child: AuthBackground()),
            // ── Auth card ───────────────────────────────────────────────────
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: _glassCard(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _cardBorder.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ARTYUG. logo ────────────────────────────────────────────
            const Center(
              child: _ArtyugLogo(),
            ),
            const SizedBox(height: 28),
            const Text(
              'Welcome back.',
              style: TextStyle(
                fontSize: 36,
                height: 1.02,
                fontWeight: FontWeight.w800,
                color: _primaryText,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your art world is waiting.',
              style: TextStyle(
                fontSize: 16,
                color: _mutedText,
              ),
            ),
            const SizedBox(height: 34),
            _fieldLabel('EMAIL'),
            _lineField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              hint: 'artist@studio.com',
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _fieldLabel('PASSWORD'),
            _lineField(
              controller: _passCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signIn(),
              hint: '........',
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 19,
                  color: _accentSoft,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your password' : null,
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SIGN IN',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            _orDivider(),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _loading ? null : _googleSignIn,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _lineColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: _primaryText,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _googleGlyph(),
                    const SizedBox(width: 10),
                    const Text(
                      'CONTINUE WITH GOOGLE',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(color: _mutedText, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/sign-up'),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: _accentSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: _primaryText,
          fontSize: 12,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _lineField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool obscureText = false,
    Widget? suffix,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(
        color: _primaryText,
        fontSize: 20,
        letterSpacing: 0.4,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF535A69),
          fontSize: 22,
          letterSpacing: 0.4,
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.only(bottom: 8, top: 2),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _lineColor),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _accentSoft),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent),
        ),
      ),
      validator: validator,
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: _lineColor,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: _mutedText,
              fontSize: 12,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: _lineColor,
          ),
        ),
      ],
    );
  }

  Widget _googleGlyph() {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _lineColor),
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── ARTYUG. Logo ─────────────────────────────────────────────────────────────

class _ArtyugLogo extends StatelessWidget {
  const _ArtyugLogo();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: 'ARTYUG',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE9EAF0),
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFF5A1F),
            ),
          ),
        ],
      ),
    );
  }
}
