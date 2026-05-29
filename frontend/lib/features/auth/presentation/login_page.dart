import 'package:easy_localization/easy_localization.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_provider.dart';

// ─────────────────────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────────────────────

class _C {
  static const bg = Color(0xFF020617);

  static const card = Color(0xCC0F172A);

  static const primary = Color(0xFF3B82F6);
  static const cyan = Color(0xFF06B6D4);

  static const text = Color(0xFFF8FAFC);
  static const soft = Color(0xFF94A3B8);

  static const input = Color(0xFF111827);

  static const error = Color(0xFFEF4444);
}

// ─────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;

  Offset _mousePos = Offset.zero;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _login() {
    final u = _usernameCtrl.text.trim();
    final p = _passwordCtrl.text.trim();

    if (u.isEmpty || p.isEmpty) return;

    ref.read(authProvider.notifier).login(u, p);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (_, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/');
      }
    });

    final isLoading = authState.status == AuthStatus.loading;

    final size = MediaQuery.sizeOf(context);

    final isMobile = size.width < 900;

    return MouseRegion(
      onHover: (event) {
        // Only rebuild if mouse moved significantly (>10px) to reduce rebuilds
        if ((_mousePos - event.localPosition).distance > 10) {
          setState(() {
            _mousePos = event.localPosition;
          });
        }
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(
          children: [
            _AnimatedBackground(mousePos: _mousePos),

            // GRID — wrapped in AnimatedBuilder to repaint on animation tick
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _GridPainter(
                    progress: _controller.value,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 18 : 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 20,
                        sigmaY: 20,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 1200,
                          maxHeight: 760,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: isMobile
                            ? SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _HeroSection(
                                      mousePos: _mousePos,
                                    ),
                                    _LoginSection(
                                      authState: authState,
                                      isLoading: isLoading,
                                      usernameCtrl: _usernameCtrl,
                                      passwordCtrl: _passwordCtrl,
                                      obscure: _obscure,
                                      onToggleObscure: () {
                                        setState(() {
                                          _obscure = !_obscure;
                                        });
                                      },
                                      onLogin: _login,
                                    ),
                                  ],
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _HeroSection(
                                      mousePos: _mousePos,
                                    ),
                                  ),
                                  Expanded(
                                    child: _LoginSection(
                                      authState: authState,
                                      isLoading: isLoading,
                                      usernameCtrl: _usernameCtrl,
                                      passwordCtrl: _passwordCtrl,
                                      obscure: _obscure,
                                      onToggleObscure: () {
                                        setState(() {
                                          _obscure = !_obscure;
                                        });
                                      },
                                      onLogin: _login,
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BACKGROUND
// ─────────────────────────────────────────────────────────────

class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground({
    required this.mousePos,
  });

  final Offset mousePos;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          left: mousePos.dx * 0.02 - 140,
          top: mousePos.dy * 0.02 - 140,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _C.primary.withOpacity(0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          right: mousePos.dx * 0.015 - 120,
          bottom: mousePos.dy * 0.015 - 120,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _C.cyan.withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.mousePos,
  });

  final Offset mousePos;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX((mousePos.dy - 300) * 0.0002)
        ..rotateY(-(mousePos.dx - 500) * 0.0002),
      child: Container(
        padding: const EdgeInsets.all(42),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.04),
              Colors.white.withOpacity(0.01),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [
                    _C.primary,
                    _C.cyan,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.primary.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.dashboard_customize_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Next Gen\nERP Platform',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 58,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Manage production, inventory,\norders and analytics in one futuristic dashboard.',
              style: GoogleFonts.inter(
                color: _C.soft,
                fontSize: 16,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 18,
              runSpacing: 18,
              children: const [
                _InfoCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Inventory',
                  subtitle: 'Track stock in real-time',
                ),
                _InfoCard(
                  icon: Icons.analytics_outlined,
                  title: 'Analytics',
                  subtitle: 'Smart business insights',
                ),
                _InfoCard(
                  icon: Icons.local_shipping_outlined,
                  title: 'Orders',
                  subtitle: 'Delivery management',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LOGIN SECTION
// ─────────────────────────────────────────────────────────────

class _LoginSection extends StatelessWidget {
  const _LoginSection({
    required this.authState,
    required this.isLoading,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final dynamic authState;

  final bool isLoading;

  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;

  final bool obscure;

  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.12),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(42),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'auth.login_title'.tr(),
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'auth.login_subtitle'.tr(),
                  style: GoogleFonts.inter(
                    color: _C.soft,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 40),
                if (authState.error != null) ...[
                  _ErrorCard(
                    message: authState.error.toString(),
                  ),
                  const SizedBox(height: 20),
                ],
                _Input(
                  controller: usernameCtrl,
                  hint: 'auth.username'.tr(),
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 18),
                _Input(
                  controller: passwordCtrl,
                  hint: 'auth.password'.tr(),
                  icon: Icons.lock_outline_rounded,
                  obscure: obscure,
                  onToggleObscure: onToggleObscure,
                  onSubmitted: (_) => onLogin(),
                ),
                const SizedBox(height: 28),
                _HoverButton(
                  onTap: onLogin,
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [
                              _C.primary,
                              _C.cyan,
                            ],
                          ),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'auth.login_button'.tr(),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Center(
                  child: Text(
                    'Enterprise-grade security',
                    style: GoogleFonts.inter(
                      color: _C.soft,
                      fontSize: 12,
                    ),
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

// ─────────────────────────────────────────────────────────────
// INPUT
// ─────────────────────────────────────────────────────────────

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.onSubmitted,
  });

  final TextEditingController controller;

  final String hint;

  final IconData icon;

  final bool obscure;

  final VoidCallback? onToggleObscure;

  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: _C.input,
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          color: _C.soft,
        ),
        prefixIcon: Icon(
          icon,
          color: _C.soft,
        ),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _C.soft,
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: _C.primary,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INFO CARD
// ─────────────────────────────────────────────────────────────

class _InfoCard extends StatefulWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  State<_InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<_InfoCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovered = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 220,
        padding: const EdgeInsets.all(18),
        transform: Matrix4.identity()..scale(hovered ? 1.03 : 1.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
          boxShadow: hovered
              ? [
                  BoxShadow(
                    color: _C.primary.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.06),
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.inter(
                      color: _C.soft,
                      fontSize: 12,
                      height: 1.5,
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
}

// ─────────────────────────────────────────────────────────────
// HOVER BUTTON
// ─────────────────────────────────────────────────────────────

class _HoverButton extends StatefulWidget {
  const _HoverButton({
    required this.child,
    required this.onTap,
  });

  final Widget child;

  final VoidCallback onTap;

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovered = false;
        });
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: hovered ? 1.02 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: hovered
                ? [
                    BoxShadow(
                      color: _C.primary.withOpacity(0.45),
                      blurRadius: 35,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ERROR
// ─────────────────────────────────────────────────────────────

class _ErrorCard extends StatefulWidget {
  const _ErrorCard({
    required this.message,
  });

  final String message;

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -0.2),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ),
  );

  late final Animation<double> _fade = Tween(
    begin: 0.0,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF4D4D).withOpacity(0.15),
                const Color(0xFFFF6B6B).withOpacity(0.08),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFF4D4D).withOpacity(0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.12),
                blurRadius: 25,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.12),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFFFF6B6B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'فشل تسجيل الدخول',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GRID PAINTER
// ─────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final double progress;

  _GridPainter({
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    const gap = 40.0;

    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          _C.primary.withOpacity(0.20),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width * progress,
            size.height * 0.4,
          ),
          radius: 180,
        ),
      );

    canvas.drawCircle(
      Offset(
        size.width * progress,
        size.height * 0.4,
      ),
      180,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
