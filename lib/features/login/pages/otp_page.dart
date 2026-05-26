import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_entry.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../providers/login_provider.dart';

class TotpPage extends StatefulWidget {
  final String serverUrl;
  final String database;
  final String username;
  final String password;
  final String protocol;

  const TotpPage({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
    required this.protocol,
  });

  @override
  State<TotpPage> createState() => _TotpPageState();
}

class _TotpPageState extends State<TotpPage> {
  InAppWebViewController? _webController;
  final _totpController = TextEditingController();
  String? _error;
  bool _loading = true;
  bool _verifying = false;
  bool _isButtonEnabled = false;
  final _formKey = GlobalKey<FormState>();
  bool _credentialsInjected = false;
  String? sessionId;
  final OdooSessionManager _commonStorageService = OdooSessionManager();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[950] : Colors.grey[50],
                  image: DecorationImage(
                    image: AssetImage('assets/images/loginbg.png'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? Colors.black.withOpacity(1)
                          : Colors.white.withOpacity(1),
                      BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Opacity(
              opacity: 0.0,
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(
                    '${widget.serverUrl}/web/login?db=${widget.database}',
                  ),
                ),
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    javaScriptEnabled: true,
                    cacheEnabled: false,
                    clearCache: true,
                    userAgent:
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                        "(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
                  ),
                  android: AndroidInAppWebViewOptions(
                    useHybridComposition: true,
                    allowContentAccess: true,
                    allowFileAccess: true,
                    mixedContentMode:
                    AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    forceDark: AndroidForceDark.FORCE_DARK_AUTO,
                    disableDefaultErrorPage: true,
                  ),
                ),
                onWebViewCreated: (controller) {
                  _webController = controller;
                },
                onReceivedServerTrustAuthRequest:
                    (controller, challenge) async {
                  return ServerTrustAuthResponse(
                    action: ServerTrustAuthResponseAction.PROCEED,
                  );
                },

                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },

                onLoadError: (controller, url, code, message) {},

                onReceivedError: (controller, request, errorResponse) {},
                onLoadStop: (controller, url) async {
                  final urlStr = url?.toString() ?? '';

                  if (urlStr.contains('/web/database/selector') ||
                      urlStr.contains('/web/database/manager')) {
                    await _handleDatabaseSelector();
                    return;
                  }

                  if (urlStr.contains('/web/login') && !_credentialsInjected) {
                    await Future.delayed(const Duration(milliseconds: 800));
                    await _injectCredentials();
                    return;
                  }

                  if (urlStr.contains('/web/login/totp') ||
                      urlStr.contains('totp_token')) {
                    if (mounted) {
                      setState(() {
                        _loading = false;
                      });
                    }
                    await Future.delayed(const Duration(milliseconds: 600));
                    await _focusTotpField();
                    return;
                  }

                  if (urlStr.contains('/web') && !urlStr.contains('login')) {
                    await _finalizeLogin();
                  }
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: _loading,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      height: 64,
                      width: 64,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios,
                        color: _loading ? Colors.white54 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildForm(),
              ],
            ),
          ),

          if (_loading)
            Container(
              color: isDark ? Colors.black54 : Colors.white70,
              child: Center(
                child: LoadingAnimationWidget.fourRotatingDots(
                  color: Theme.of(context).colorScheme.primary,
                  size: 60,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Future<void> _submitTotp() async {
    if (_verifying || _webController == null) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    final totp = _totpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(totp)) {
      setState(() {
        _error = 'Please enter a valid 6-digit code';
        _verifying = false;
      });
      return;
    }

    try {
      /// Inject TOTP and submit form
      await _webController!.evaluateJavascript(source: """
      (function() {
        const input = document.querySelector(
          'input[name="totp_token"], input[autocomplete="one-time-code"]'
        );
        if (!input) return 'input_not_found';

        input.focus();
        input.value = '$totp';
        input.dispatchEvent(new Event('input', { bubbles: true }));

        const trust = document.querySelector('input[name="trust_device"]');
        if (trust && !trust.checked) trust.click();

        const form = input.closest('form');
        if (form) form.submit();

        return 'submitted';
      })();
    """);

      /// Wait briefly for server to respond (NO LONG POLLING)
      await Future.delayed(const Duration(milliseconds: 700));

      /// Check session cookie (REAL login signal)
      final currentUrl = await _webController!.getUrl();
      if (currentUrl == null) {
        throw Exception('Unable to read current URL');
      }

      final cookies =
      await CookieManager.instance().getCookies(url: currentUrl);

      final sessionCookie = cookies.firstWhere(
            (c) => c.name == 'session_id' && c.value.isNotEmpty,
        orElse: () => Cookie(name: '', value: ''),
      );

      if (sessionCookie.value.isEmpty) {
        setState(() {
          _error = 'Invalid code or authentication failed';
        });
        return;
      }

      await _saveSessionData();

      /// Navigate IMMEDIATELY (don’t block UX)
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppEntry()),
      );

      ///Save session in background (non-blocking)


    } catch (e, st) {
      setState(() {
        _error = 'Authentication failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _finalizeLogin() async {
    try {

      final result =await OdooSessionManager.loginAndSaveSession(
        serverUrl: widget.serverUrl,
        database: widget.database,
        userLogin: widget.username,
        password: widget.password,

      );


      if (!mounted) return;



      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppEntry()),
      );
    } catch (e) {
      setState(() {
        _error = 'Authentication failed. Please try again.';
      });
    }
  }


  Future<void> _saveUrlHistory({
    required String protocol,
    required String url,
    required String database,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('urlHistory') ?? [];

    String finalProtocol = protocol;
    String finalUrl = url.trim();

    if (finalUrl.startsWith('https://')) {
      finalProtocol = 'https://';
      finalUrl = finalUrl.replaceFirst('https://', '');
    } else if (finalUrl.startsWith('http://')) {
      finalProtocol = 'http://';
      finalUrl = finalUrl.replaceFirst('http://', '');
    }

    final entry = jsonEncode({
      'protocol': finalProtocol,
      'url': finalUrl,
      'db': database,
      'username': username,
    });

    history.removeWhere((e) {
      final d = jsonDecode(e);
      return d['url'] == finalUrl && d['protocol'] == finalProtocol;
    });

    history.insert(0, entry);
    await prefs.setStringList('urlHistory', history.take(10).toList());
  }

  Future<void> _saveSessionData() async {
    final currentUrl = await _webController!.getUrl();

    final cookies = await CookieManager.instance().getCookies(url: currentUrl!);
    final sessionCookie = cookies.firstWhere(
          (c) => c.name == 'session_id',
      orElse: () => Cookie(name: '', value: ''),
    );

    if (sessionCookie.value.isEmpty) {
      throw Exception('Session cookie missing');
    }

    sessionId = sessionCookie.value;

    final sessionInfo = await fetchSessionInfo(
      serverUrl: widget.serverUrl,
      database: widget.database,
      sessionId: sessionId!,
    );




    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('sessionId', sessionId!);
    await prefs.setString('username', widget.username);
    await prefs.setString('url', widget.serverUrl);
    await prefs.setString('database', widget.database);
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);

    await context.read<LoginProvider>().onLoginSuccessFromSession(
        sessionInfo,
        login: widget.username,
        password2: widget.password,
        serverUrls: widget.serverUrl,
        databses: widget.database,
        sessionId: sessionId!
    );
  }

  Future<void> _injectCredentials() async {
    if (_credentialsInjected) return;

    final safeUser = jsonEncode(widget.username);
    final safePass = jsonEncode(widget.password);
    final safeDb = jsonEncode(widget.database);

    final result = await _webController?.evaluateJavascript(
      source:
      """
      (function() {
        const login = document.querySelector('input[name="login"], input[type="email"]');
        const password = document.querySelector('input[name="password"]');
        const db = document.querySelector('input[name="db"], select[name="db"]');
        const form = document.querySelector('form[action*="/web/login"]');

        if (!login || !password || !form) return "missing";

        login.value = $safeUser;
        password.value = $safePass;
        if (db) {
          if (db.tagName === 'INPUT') db.value = $safeDb;
          else db.value = $safeDb;
        }

        const btn = form.querySelector('button[type="submit"]');
        if (btn) btn.click();
        else form.requestSubmit();

        return "submitted";
      })();
    """,
    );

    if (result == "submitted") {
      _credentialsInjected = true;
    }
  }

  Future<void> _focusTotpField() async {
    await _webController?.evaluateJavascript(
      source: """
      const input = document.querySelector('input[name="totp_token"], input[autocomplete="one-time-code"]');
      if (input) {
        input.focus();
        input.select();
      }
    """,
    );
  }

  Future<void> _handleDatabaseSelector() async {
    await _webController?.evaluateJavascript(
      source:
      """
      const select = document.querySelector('select[name="db"]');
      if (select) {
        select.value = '${widget.database}';
        const btn = document.querySelector('button[type="submit"]');
        if (btn) btn.click();
      }
    """,
    );
  }

  Future<Map<String, dynamic>?> waitForSessionInfo() async {
    for (int i = 0; i < 10; i++) {
      final result = await _webController!.evaluateJavascript(
        source: """
        (function () {
          if (window.odoo && odoo.session_info) {
            return odoo.session_info;
          }
          return null;
        })();
      """,
      );

      if (result != null) {
        return Map<String, dynamic>.from(result);
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  Future<void> _extractAndSaveSession() async {
    final currentUrl = await _webController?.getUrl();
    if (currentUrl == null) return;

    final cookies = await CookieManager.instance().getCookies(url: currentUrl);
    final sessionCookie = cookies.firstWhere(
          (c) => c.name == 'session_id',
      orElse: () => Cookie(name: 'session_id', value: ''),
    );

    if (sessionCookie.value.isEmpty) {
      setState(() => _error = "Login failed. Please try again.");
      return;
    }
  }

  Widget _buildHeader() {
    return Column(
      children: [
        HugeIcon(
          icon:
          HugeIcons.strokeRoundedTwoFactorAccess,
          color: Colors.white,
          size: 48,
        ),
        const SizedBox(height: 24),
        Text(
          'Two-factor Authentication',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 25,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'To login, enter below the six-digit authentication code provided by your Authenticator app.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.serverUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Server: ${widget.serverUrl}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _totpController,
            keyboardType: TextInputType.number,
            enabled: !_loading || !_verifying,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return
                    'TOTP is required';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _isButtonEnabled = value.trim().isNotEmpty;
                _formKey.currentState?.validate();
                if (_error != null) _error = null;
              });
            },
            cursorColor: Colors.black,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText:
                  'Enter TOTP Code',
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withOpacity(.4),
              ),
              prefixIcon:  Padding(
                padding: const EdgeInsets.all(8.0),
                child: HugeIcon(icon: HugeIcons.strokeRoundedSmsCode, size: 10),
              ),
              prefixIconColor: MaterialStateColor.resolveWith(
                    (states) => states.contains(MaterialState.disabled)
                    ? Colors.black26
                    : Colors.black54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              errorStyle: const TextStyle(color: Colors.white),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red[900]!, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _error != null ? 48 : 0,
            child: _error != null
                ? Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  HugeIcon(icon:
                    HugeIcons.strokeRoundedAlertCircle,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            )
                : null,
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_verifying || !_isButtonEnabled) ? null : _submitTotp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _verifying
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Authenticating',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  LoadingAnimationWidget.staggeredDotsWave(
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              )
                  : Text(
                'Authenticate',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _webController?.dispose();
    _totpController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> fetchSessionInfo({
    required String serverUrl,
    required String database,
    required String sessionId,
  }) async {
    final uri = Uri.parse('$serverUrl/web/session/get_session_info');

    final response = await HttpClient()
        .postUrl(uri)
        .then((req) async {
      req.headers.set(
        HttpHeaders.cookieHeader,
        'session_id=$sessionId',
      );
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json',
      );
      req.write(jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {},
      }));
      return await req.close();
    });

    final responseBody = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(responseBody);

    if (decoded['result'] == null) {
      throw Exception('Failed to fetch session info');
    }

    return Map<String, dynamic>.from(decoded['result']);
  }

}