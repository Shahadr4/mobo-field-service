import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/services/biometric_service.dart';

/// App lock screen that prompts for biometric authentication
/// Displayed when app is locked and biometric authentication is enabled
class AppLockScreen extends StatefulWidget {
  final VoidCallback? onAuthenticationSuccess;

  const AppLockScreen({super.key, this.onAuthenticationSuccess});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _isAuthenticating = false;
  bool _authenticationFailed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    /// Authenticate immediately when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performAuthentication();
    });
  }

  Future<void> _performAuthentication() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      /// Check if biometric is available first
      final isAvailable = await BiometricService.isBiometricAvailable();
      if (!isAvailable) {
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _authenticationFailed = true;
            _errorMessage =
                'Biometric authentication is not available on this device. Please disable biometric lock in settings.';
          });
        }
        return;
      }

      final success = await BiometricService.authenticateWithBiometrics(
        reason: 'Please authenticate to access the Mobo Expenses App',
      );

      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });

        if (success) {
          setState(() {
            _authenticationFailed = false;
            _errorMessage = null;
          });

          /// Call the callback to notify parent widget
          widget.onAuthenticationSuccess?.call();
        } else {
          setState(() {
            _authenticationFailed = true;
            _errorMessage =
                'Authentication failed or was cancelled. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _authenticationFailed = true;
          _errorMessage = 'Authentication error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          /// Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  ///set your login image
                  image: const AssetImage('assets/images/loginbg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Main content
          LayoutBuilder(
            builder: (context, viewportConstraints) {
              return Column(
                children: [
                  /// App name and logo at the top
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 68),
                      child: _buildAppHeader(),
                    ),
                  ),

                  /// Scrollable content area for authentication
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: viewportConstraints.maxHeight - 180,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  /// Authentication header
                                  _buildAuthHeader(),
                                  const SizedBox(height: 24),

                                  /// Authentication content
                                  if (_isAuthenticating)
                                    _buildAuthenticatingDisplay()
                                  else if (_authenticationFailed)
                                    _buildRetryButton()
                                  else
                                    _buildInitialDisplay(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build app header (Inventory App + logo at top)
  Widget _buildAppHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          "assets/Icon.png",
          width: 50,
          height: 50,
          fit: BoxFit.contain,

        ),
        const SizedBox(width: 8),
        Text(
          'mobo field service',
          style: const TextStyle(
            fontFamily: 'MyFont',
            color: Colors.white,
            fontSize: 28,
          ),
        ),

      ],
    );
  }

  /// Build authentication header (centered)
  Widget _buildAuthHeader() {
    return Column(
      children: [
        /// "App Locked" text
        Text(
          'App Locked',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        /// Subtitle text
        Text(
          'Please authenticate to continue',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAuthenticatingDisplay() {
    return Column(
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Authenticating...',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRetryButton() {
    return Column(
      children: [
        if (_errorMessage != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const HugeIcon(
              icon:   HugeIcons.strokeRoundedAlertCircle,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        SizedBox(
          height: 48,
          width: MediaQuery.of(context).size.width * 0.7,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _authenticationFailed = false;
                _errorMessage = null;
              });
              _performAuthentication();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Try Again',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialDisplay() {
    return Column(
      children: [
        Icon(Icons.fingerprint, size: 48, color: Colors.white.withOpacity(0.8)),
        const SizedBox(height: 16),
        Text(
          'Touch sensor or use face unlock',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
