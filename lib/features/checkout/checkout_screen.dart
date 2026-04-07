import 'dart:async' show Timer;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/order_repository.dart';
import '../../models/painting.dart';
import '../../services/payments/payment_service.dart';
import '../../services/demo_wallet_service.dart';

class CheckoutScreen extends StatefulWidget {
  final String paintingId;
  final PaintingModel? initialPainting;

  const CheckoutScreen({
    super.key,
    required this.paintingId,
    this.initialPainting,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postal = TextEditingController();
  final _country = TextEditingController(text: 'IN');

  PaintingModel? _painting;
  bool _loading = true;
  bool _purchasing = false;
  bool _awaitingWebhook = false;
  PaymentGateway? _awaitingGateway;
  String? _error;

  CheckoutPaymentMethod? _selectedMethod;

  @override
  void initState() {
    super.initState();
    if (widget.initialPainting != null) {
      _painting = widget.initialPainting;
      _loading = false;
    }
    _loadPainting();
  }

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _postal.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _loadPainting() async {
    try {
      final p = await OrderRepository.getPainting(widget.paintingId);
      if (mounted) {
        setState(() {
          _painting = p ?? _painting;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = _painting == null;
        });
      }
    }
  }

  Map<String, dynamic> _billingPayload() {
    return {
      'line1': _line1.text.trim(),
      if (_line2.text.trim().isNotEmpty) 'line2': _line2.text.trim(),
      'city': _city.text.trim(),
      'state': _state.text.trim(),
      'postal_code': _postal.text.trim(),
      'country': _country.text.trim().toUpperCase(),
    };
  }

  bool _validateShipping() {
    final ok = _line1.text.trim().isNotEmpty &&
        _city.text.trim().isNotEmpty &&
        _postal.text.trim().isNotEmpty &&
        _country.text.trim().isNotEmpty;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in address line, city, postal code, and country.'),
        ),
      );
    }
    return ok;
  }

  bool _isStripeSupportedCountry(String raw) {
    // Stripe availability varies by account, currency, and region. For this demo build,
    // we intentionally disable Stripe Checkout for countries we haven't validated.
    final c = raw.trim().toUpperCase();
    // Expand this allowlist when you confirm Stripe works for those countries.
    return const {'US'}.contains(c);
  }

  Future<void> _doPurchase() async {
    final auth = context.read<AuthProvider>();
    final modeProvider = context.read<AppModeProvider>();
    final runtimeLive = modeProvider.isLiveMode;

    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to purchase')),
      );
      return;
    }

    final painting = _painting!;
    final methods = PaymentService.availableCheckoutMethods();

    if (runtimeLive) {
      if (painting.isSold) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This artwork has already been sold and cannot be purchased again.'),
          ),
        );
        return;
      }
      if (!painting.isForSale) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This artwork is not currently listed for sale.'),
          ),
        );
        return;
      }
      final block = PaymentService.blockMessageForLiveMode(true);
      if (block != null) {
        _showBlockedDialog(block);
        return;
      }
      if (_selectedMethod == null && methods.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a payment method (Dodo, Stripe, or Razorpay).')),
        );
        return;
      }
      if (!_validateShipping()) return;
    }

    final gateway = PaymentService.resolveGateway(
      runtimeLiveMode: runtimeLive,
      currency: 'INR',
      selectedMethod: _selectedMethod,
    );

    setState(() {
      _purchasing = true;
      _error = null;
      _awaitingWebhook = false;
      _awaitingGateway = null;
    });

    try {
      if (gateway == PaymentGateway.demo) {
        final started = DateTime.now();

        // Demo wallet: ₹5000 starting balance, decreases per demo purchase.
        final priceInr = (_painting?.price ?? 0).round();
        final bal = await DemoWalletService.getBalanceInr();
        if (bal < priceInr) {
          if (!mounted) return;
          setState(() => _purchasing = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient demo balance. Available: ₹$bal',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        final result = await OrderRepository.createDemoOrder(widget.paintingId);
        // Spend only after order succeeds (so errors don't burn demo funds).
        await DemoWalletService.trySpendInr(priceInr);
        const minShow = Duration(milliseconds: 1450);
        final elapsed = DateTime.now().difference(started);
        if (elapsed < minShow && mounted) {
          await Future<void>.delayed(minShow - elapsed);
        }
        if (mounted) context.pushReplacement('/order-confirm', extra: result);
        return;
      }

      // ── Live: never silently fall back to demo ─────────────────────────
      if (gateway == PaymentGateway.razorpay) {
        final rzBlock = PaymentService.razorpayBlockMessage;
        if (rzBlock != null) {
          _showBlockedDialog('Live payments are not configured ($rzBlock).');
          setState(() => _purchasing = false);
          return;
        }

        final payResult = await PaymentService.initiateRazorpayPayment(
          artworkId: painting.id,
          amountInr: painting.price?.toDouble() ?? 0,
        );

        if (payResult == null || !payResult.success) {
          debugPrint('[Checkout] Razorpay initiation failed');
          if (mounted) {
            setState(() => _purchasing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not start Razorpay. Check the create-razorpay-order Edge Function and keys.',
                ),
              ),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _purchasing = false;
            _awaitingWebhook = true;
            _awaitingGateway = PaymentGateway.razorpay;
          });
        }
        return;
      }

      if (gateway == PaymentGateway.dodo) {
        final payResult = await PaymentService.initiateDodoCheckout(
          artworkId: painting.id,
          artworkTitle: painting.title,
          amountInr: painting.price?.toDouble() ?? 0,
          billingAddress: _billingPayload(),
        );
        if (payResult == null || !payResult.success) {
          if (mounted) {
            setState(() => _purchasing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not start Dodo checkout. Deploy create-dodo-checkout and set secrets.',
                ),
              ),
            );
          }
          return;
        }
        if (mounted) {
          setState(() {
            _purchasing = false;
            _awaitingWebhook = true;
            _awaitingGateway = PaymentGateway.dodo;
          });
        }
        return;
      }

      if (gateway == PaymentGateway.stripe) {
        if (!_isStripeSupportedCountry(_country.text)) {
          if (mounted) {
            setState(() => _purchasing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Stripe is not available for the selected country in this demo. Choose Dodo Payments.',
                ),
              ),
            );
          }
          return;
        }
        final payResult = await PaymentService.initiateStripeCheckout(
          artworkId: painting.id,
          artworkTitle: painting.title,
          amountInr: painting.price?.toDouble() ?? 0,
          billingAddress: _billingPayload(),
        );
        if (payResult == null || !payResult.success) {
          if (mounted) {
            setState(() => _purchasing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not start Stripe Checkout. Deploy create-stripe-checkout and set STRIPE_SECRET_KEY.',
                ),
              ),
            );
          }
          return;
        }
        if (mounted) {
          setState(() {
            _purchasing = false;
            _awaitingWebhook = true;
            _awaitingGateway = PaymentGateway.stripe;
          });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _purchasing = false;
        });
      }
    }
  }

  void _showBlockedDialog(String reason) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Live Payments Not Configured',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '$reason\n\n'
          'Set ARTYUG_APP_MODE=live in .env, use the in-app Live toggle, add gateway env flags, '
          'and deploy Supabase Edge Functions. Rebuild web after .env changes.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeProvider = context.watch<AppModeProvider>();
    final runtimeLive = modeProvider.isLiveMode;
    final methods = PaymentService.availableCheckoutMethods();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _awaitingWebhook
                ? _buildAwaitingWebhook()
                : _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _error != null && _painting == null
                        ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                        : _buildContent(runtimeLive, methods),
          ),
          if (_purchasing && !runtimeLive)
            const Positioned.fill(child: _DemoPayingOverlay()),
        ],
      ),
    );
  }

  static const double _wideBreakpoint = 960;

  /// Avoid mixed-content blocking artwork on https pages.
  String _displayImageUrl(String raw) {
    final u = Uri.tryParse(raw.trim());
    if (u == null || !u.hasScheme) return raw;
    if (kIsWeb && u.scheme == 'http') {
      return u.replace(scheme: 'https').toString();
    }
    return raw;
  }

  Widget _buildContent(bool runtimeLive, List<CheckoutPaymentMethod> methods) {
    final p = _painting!;

    if (runtimeLive && _selectedMethod == null && methods.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedMethod = methods.first);
      });
    }

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wideBreakpoint;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 46,
                      child: Container(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 28, 24, 32),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: _productColumn(
                                p,
                                runtimeLive,
                                maxImageSide: 380,
                                centerText: false,
                                bottomError:
                                    !runtimeLive && _error != null ? _error : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.border.withValues(alpha: 0.9),
                    ),
                    Expanded(
                      flex: 54,
                      child: ColoredBox(
                        color: AppColors.background,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 28, 32, 32),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: _checkoutFormColumn(runtimeLive, methods),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _productColumn(
                          p,
                          runtimeLive,
                          maxImageSide: 360,
                          centerText: true,
                          bottomError: null,
                        ),
                        const SizedBox(height: 28),
                        if (runtimeLive) _checkoutFormColumn(runtimeLive, methods),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!, style: const TextStyle(color: AppColors.error)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= _wideBreakpoint;
            return _checkoutPayBar(
              p: p,
              runtimeLive: runtimeLive,
              wide: wide,
            );
          },
        ),
      ],
    );
  }

  /// Artwork, title, summary, certificate (used in left column or stacked mobile).
  Widget _productColumn(
    PaintingModel p,
    bool runtimeLive, {
    required double maxImageSide,
    required bool centerText,
    String? bottomError,
  }) {
    final align = centerText ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment:
          centerText ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      children: [
        Text(
          'Order summary',
          textAlign: align,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 14),
        _artworkImageTile(p, maxSide: maxImageSide),
        const SizedBox(height: 20),
        Text(
          p.title,
          textAlign: align,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'by ${p.artistDisplayName ?? 'Artist'}',
          textAlign: align,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.95),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 22),
        _checkoutCard(
          child: Column(
            children: [
              _buildInfoRow('Price', p.displayPrice, emphasizeValue: true),
              _infoDivider(),
              _buildInfoRow('Currency', p.price != null ? 'INR' : 'N/A'),
              _infoDivider(),
              _buildInfoRow('Certificate', 'Yes — QR + Blockchain'),
              _infoDivider(),
              _buildInfoRow(
                'Session',
                runtimeLive ? 'Live checkout' : 'Demo (no charge)',
              ),
              if (AppConfig.solanaEnabled) ...[
                _infoDivider(),
                _buildInfoRow(
                  'Blockchain',
                  'Solana ${AppConfig.chainMode == ChainMode.devnet ? 'Devnet' : 'Mainnet'}',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _certificateBanner(),
        if (bottomError != null) ...[
          const SizedBox(height: 16),
          Text(bottomError, style: const TextStyle(color: AppColors.error)),
        ],
      ],
    );
  }

  Widget _checkoutFormColumn(bool runtimeLive, List<CheckoutPaymentMethod> methods) {
    if (!runtimeLive) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Checkout',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Delivery & payment',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 24),
        _sectionLabel('Shipping address'),
        const SizedBox(height: 6),
        Text(
          'Where should we send certificate and shipping updates?',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: AppColors.textSecondary.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 16),
        _checkoutCard(
          child: AutofillGroup(
            child: Column(
              children: [
                _addressField(
                  'Address line 1',
                  _line1,
                  autofillHints: const [AutofillHints.streetAddressLine1],
                  keyboardType: TextInputType.streetAddress,
                ),
                _addressField(
                  'Address line 2 (optional)',
                  _line2,
                  autofillHints: const [AutofillHints.streetAddressLine2],
                  keyboardType: TextInputType.streetAddress,
                ),
                _addressField(
                  'City',
                  _city,
                  autofillHints: const [AutofillHints.addressCity],
                ),
                _addressField(
                  'State / Region',
                  _state,
                  autofillHints: const [AutofillHints.addressState],
                ),
                _addressField(
                  'Postal code',
                  _postal,
                  autofillHints: const [AutofillHints.postalCode],
                  keyboardType: TextInputType.text,
                ),
                _addressField(
                  'Country (ISO, e.g. IN)',
                  _country,
                  autofillHints: const [AutofillHints.countryCode],
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        _sectionLabel('Payment method'),
        const SizedBox(height: 10),
        _checkoutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Text(
                'Notes',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Dodo Payments is running in test mode (sandbox). If the browser cannot be opened, the checkout link is copied to clipboard.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
              ),
              SizedBox(height: 8),
              Text(
                'Stripe is intentionally disabled for unsupported countries in this demo build.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
              ),
              SizedBox(height: 8),
              Text(
                'Arc Pay (stablecoin) is coming soon and will be enabled later.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (methods.isEmpty)
          _checkoutCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'No gateway enabled in .env. Add RAZORPAY_KEY_ID and/or '
                  'CHECKOUT_ENABLE_DODO / CHECKOUT_ENABLE_STRIPE (with Edge Functions).',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                _arcPayComingSoonTile(),
              ],
            ),
          )
        else
          _checkoutCard(
            child: Column(
              children: [
                ...methods.map((m) => _methodTile(m)),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _infoDivider(),
                ),
                _arcPayComingSoonTile(),
              ],
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
      ],
    );
  }

  Widget _artworkImageTile(PaintingModel p, {required double maxSide}) {
    final url = _displayImageUrl(p.imageUrl);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(200.0, maxSide)
            : maxSide;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.9),
                  ),
                ),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: side,
                  height: side,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary.withValues(alpha: 0.85),
                          value: progress.expectedTotalBytes != null &&
                                  progress.expectedTotalBytes! > 0
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 44,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Could not load artwork image',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
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
      },
    );
  }

  Widget _certificateBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your purchase includes an Artyug Authenticity Certificate, '
              '${AppConfig.solanaEnabled ? 'blockchain-anchored on Solana.' : 'cryptographically generated.'}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkoutPayBar({
    required PaintingModel p,
    required bool runtimeLive,
    required bool wide,
  }) {
    final btn = FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 17),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: _purchasing ? null : _doPurchase,
      child: _purchasing
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                color: AppColors.onPrimary,
                strokeWidth: 2,
              ),
            )
          : Text(
              runtimeLive
                  ? 'Pay — ${p.displayPrice}'
                  : 'Buy Now (Demo) — ${p.displayPrice}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(wide ? 28 : 20, 14, wide ? 32 : 20, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.9))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: wide
            ? Row(
                children: [
                  const Spacer(flex: 46),
                  Expanded(
                    flex: 54,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: btn,
                    ),
                  ),
                ],
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SizedBox(width: double.infinity, child: btn),
                ),
              ),
      ),
    );
  }

  Widget _addressField(
    String label,
    TextEditingController c, {
    Iterable<String>? autofillHints,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surfaceHigh.withValues(alpha: 0.45),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.75)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _arcPayComingSoonTile() {
    return ListTile(
      enabled: false,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(
        Icons.account_balance_wallet_outlined,
        color: AppColors.textTertiary,
        size: 22,
      ),
      title: Text(
        'Arc Pay (Stablecoins)',
        style: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        'Coming soon (ARC Network)',
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _methodTile(CheckoutPaymentMethod m) {
    final country = _country.text.trim().toUpperCase();
    final stripeSupported = _isStripeSupportedCountry(country);

    final title = switch (m) {
      CheckoutPaymentMethod.razorpay => 'Razorpay (INR, cards / UPI)',
      CheckoutPaymentMethod.dodo => 'Dodo Payments',
      CheckoutPaymentMethod.stripe => 'Stripe Checkout',
    };

    final subtitle = switch (m) {
      CheckoutPaymentMethod.razorpay => 'Best for India payments.',
      CheckoutPaymentMethod.dodo =>
        'Sandbox/test mode. If browser won’t open, link is copied.',
      CheckoutPaymentMethod.stripe => stripeSupported
          ? 'Test mode supported for $country.'
          : 'Not available for $country in this demo.',
    };

    final icon = switch (m) {
      CheckoutPaymentMethod.razorpay => Icons.payments_outlined,
      CheckoutPaymentMethod.dodo => Icons.shopping_bag_outlined,
      CheckoutPaymentMethod.stripe => Icons.credit_card_outlined,
    };

    final enabled = switch (m) {
      CheckoutPaymentMethod.stripe => stripeSupported,
      _ => true,
    };

    if (!enabled && _selectedMethod == m) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedMethod = null);
      });
    }

    return Material(
      color: Colors.transparent,
      child: RadioListTile<CheckoutPaymentMethod>(
        value: m,
        groupValue: _selectedMethod,
        onChanged: enabled ? (v) => setState(() => _selectedMethod = v) : null,
        secondary: Icon(icon, color: enabled ? AppColors.textSecondary : AppColors.textTertiary),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: enabled ? AppColors.textSecondary : AppColors.textTertiary,
            fontSize: 12,
            height: 1.25,
          ),
        ),
        activeColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildAwaitingWebhook() {
    final label = switch (_awaitingGateway) {
      PaymentGateway.razorpay => 'Razorpay',
      PaymentGateway.dodo => 'Dodo Payments',
      PaymentGateway.stripe => 'Stripe',
      _ => 'Payment',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_browser_outlined, color: AppColors.primary, size: 56),
            const SizedBox(height: 20),
            Text(
              'Complete payment in browser',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '$label checkout opened in a new tab. After payment, your order will appear '
              'in Orders when the webhook runs.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/orders'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Go to My Orders', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() {
                _awaitingWebhook = false;
                _awaitingGateway = null;
              }),
              child: const Text('Back to checkout', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkoutCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.15,
      ),
    );
  }

  Widget _infoDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border.withValues(alpha: 0.5),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool emphasizeValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.95),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: emphasizeValue ? FontWeight.w800 : FontWeight.w600,
                fontSize: emphasizeValue ? 17 : 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen paying experience for demo checkout (no real charge).
class _DemoPayingOverlay extends StatefulWidget {
  const _DemoPayingOverlay();

  @override
  State<_DemoPayingOverlay> createState() => _DemoPayingOverlayState();
}

class _DemoPayingOverlayState extends State<_DemoPayingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _glow;
  Timer? _dotTimer;
  int _dots = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOutCubic),
    );
    _dotTimer = Timer.periodic(const Duration(milliseconds: 380), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotStr = '.' * _dots;
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.58)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: AnimatedBuilder(
                animation: _glow,
                builder: (context, child) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.22 + 0.28 * _glow.value),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12 + 0.22 * _glow.value),
                          blurRadius: 36 + 12 * _glow.value,
                          spreadRadius: 1,
                        ),
                      ],
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surface.withValues(alpha: 0.96),
                          AppColors.surfaceVariant.withValues(alpha: 0.99),
                        ],
                      ),
                    ),
                    child: child,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 38, 32, 34),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.06).animate(
                          CurvedAnimation(parent: _pulse, curve: Curves.easeInOutCubic),
                        ),
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.goldGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 32,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            size: 46,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        'Paying${dotStr.padRight(3)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.35,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Demo — no charge',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.primary.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Preparing your authenticity certificate and order receipt.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textSecondary.withValues(alpha: 0.94),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          width: double.infinity,
                          height: 3,
                          child: LinearProgressIndicator(
                            backgroundColor: AppColors.border.withValues(alpha: 0.45),
                            color: AppColors.primary,
                            minHeight: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
