import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_role.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final authNotifier = ref.read(authProvider.notifier);

    final success = await authNotifier.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      final role = ref.read(authProvider).currentUser.role;
      switch (role) {
        case UserRole.owner:
          context.go('/owner/tables');
          break;
        case UserRole.manager:
          context.go('/manager/tables');
          break;
        case UserRole.cashier:
          context.go('/sales/tables');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          // 1. Bottom-Right Red Accent Curve
          Positioned(
            bottom: 0,
            right: 0,
            child: SizedBox(
              width: 450,
              height: 300,
              child: CustomPaint(
                painter: BottomRightRedCurvePainter(),
              ),
            ),
          ),

          // 2. Top-Right Red Grid Dots Pattern
          Positioned(
            top: 40,
            right: 40,
            child: _buildRedDotsGrid(),
          ),

          // 3. Faint Background Pizza Watermark (Right side)
          Positioned(
            right: -40,
            top: MediaQuery.of(context).size.height * 0.2,
            child: Opacity(
              opacity: 0.04,
              child: Icon(
                Icons.local_pizza_outlined,
                size: 450,
                color: Colors.black,
              ),
            ),
          ),

          // 4. Main Responsive Content (Left Panel + Right Login Card)
          if (isDesktop)
            Row(
              children: [
                // Left Side: Diagonally Clipped Image Panel
                Expanded(
                  flex: 5,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipPath(
                          clipper: DiagonalRightClipper(),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/image.jpg',
                                  fit: BoxFit.cover,
                                ),
                              ),

                              // Top-Left Brand Logo
                              Positioned(
                                top: 30,
                                left: 35,
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 58,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Row(
                                      children: [
                                        Icon(Icons.local_pizza_rounded, color: Colors.amber, size: 36),
                                        SizedBox(width: 8),
                                        Text(
                                          'Hungry Howie\'s',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Side: Centered Login Card
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _buildLoginCard(context, authState, authNotifier),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            // Mobile / Small Screen Layout
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _buildLoginCard(context, authState, authNotifier),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Grid of Red Dots (Top-Right Decor)
  Widget _buildRedDotsGrid() {
    return Column(
      children: List.generate(
        3,
        (row) => Row(
          children: List.generate(
            4,
            (col) => Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Elevated White Login Card (Matching Reference Image)
  Widget _buildLoginCard(BuildContext context, AuthState authState, AuthNotifier authNotifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo centered inside card
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              height: 60,
              errorBuilder: (context, error, stackTrace) {
                return const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_pizza_rounded, color: Colors.amber, size: 32),
                    SizedBox(width: 8),
                    Text(
                      'Hungry Howie\'s',
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Welcome Back Title
          const Text(
            'Welcome Back',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),

          // Red Underline Indicator
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          const Text(
            'Sign in to your restaurant portal',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 28),

          // Error Message Banner
          if (authState.errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 1. Username Label & Field
          const Text(
            'Username',
            style: TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter username (e.g. superadmin, storemanager, poscashier)',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFFE53935), size: 20),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Password Label & Field
          const Text(
            'Password',
            style: TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleLogin(),
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter password',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFE53935), size: 20),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 3. Red LOGIN Button with Arrow Icon
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFFE53935).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: authState.isLoading ? null : _handleLogin,
              child: authState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 28),

          // Footer Text (Secure Access | Restaurant Management System)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                SizedBox(width: 5),
                Text(
                  'Secure Access',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('|', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                ),
                Text(
                  'Restaurant Management System',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diagonal Clipper for Left Panel Image
class DiagonalRightClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width * 0.85, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Bottom-Right Red Accent Curve Painter
class BottomRightRedCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width, size.height * 0.2);
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.85,
      0,
      size.height,
    );
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
