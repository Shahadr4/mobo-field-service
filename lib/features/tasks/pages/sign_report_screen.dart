import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mobo_feild_service/core/const/app_colors.dart';

class SignReport extends StatefulWidget {
  final String url;
  final String sessionId;
  final String taskName;

  const SignReport({
    super.key,
    required this.url,
    required this.sessionId,
    required this.taskName,
  });

  @override
  State<SignReport> createState() => _SignReportState();
}

class _SignReportState extends State<SignReport> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _injectSessionCookie();
  }

  Future<void> _injectSessionCookie() async {
    final uri = Uri.parse(widget.url);
    await CookieManager.instance().setCookie(
      url: WebUri('${uri.scheme}://${uri.host}'),
      name: 'session_id',
      value: widget.sessionId,
      path: '/',
      isHttpOnly: true,
      isSecure: uri.scheme == 'https',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        title: Text(
          'Sign Report',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useShouldOverrideUrlLoading: false,
              mediaPlaybackRequiresUserGesture: false,
              clearCache: false,
              useOnLoadResource: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            ),
            onLoadStart: (c, u) => setState(() => _isLoading = true),
            onLoadStop: (c, u) => setState(() => _isLoading = false),
            onReceivedError: (c, r, e) => setState(() => _isLoading = false),
          ),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
        ],
      ),
    );
  }
}
