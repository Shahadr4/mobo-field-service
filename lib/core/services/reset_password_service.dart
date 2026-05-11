import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ResetPasswordService {
  static Future<Map<String, dynamic>> sendResetPasswordEmail({
    required String serverUrl,
    required String database,
    required String login,
  }) async {
    try {
      // Clean the server URL
      String cleanUrl = serverUrl.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      debugPrint('[ResetPasswordService] Prepared URLs');
      debugPrint('  • serverUrl: $serverUrl');
      debugPrint('  • cleanUrl:  $cleanUrl');

      // Prefer the professional, browser-aligned flow first.
      // This mirrors how Odoo handles the reset in the web UI and is the most reliable.
      final webFlowResult = await _tryWebInterfaceReset(cleanUrl, database, login);
      // If the web flow succeeded or requires a WebView (recaptcha/routing), return immediately.
      if (webFlowResult['success'] == true || webFlowResult['requiresWebView'] == true) {
        return webFlowResult;
      }

      // Try multiple possible reset password endpoints
      final possibleEndpoints = [
        '/web/reset_password',
        '/auth_signup/reset_password',
        '/web/signup',
        '/web/database/reset_password',
        '/auth_signup/signup',
      ];

      http.Response? getResponse;
      String? workingEndpoint;
      String? responseBody;
      Map<String, String>? cookies;
      bool requiresRecaptcha = false;

      // Step 1: Find a working reset password endpoint
      debugPrint('[ResetPasswordService] Testing reset password endpoints...');
      for (final endpoint in possibleEndpoints) {
        final testUrl = '$cleanUrl$endpoint';
        debugPrint('[ResetPasswordService] Testing: $testUrl');
        try {
          debugPrint('[ResetPasswordService] Testing: $cleanUrl$endpoint');

          final response = await http.get(
            Uri.parse('$cleanUrl$endpoint?db=$database'),
            headers: {
              'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
              'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.5',
            },
          ).timeout(Duration(seconds: 10));

          debugPrint(
              '[ResetPasswordService] Response for $endpoint: ${response.statusCode}');

          if (response.statusCode == 200) {
            // Check if this is actually a reset password form
            final body = response.body.toLowerCase();

            // More specific checks to avoid website error pages
            bool isValidResetForm = false;

            if (body.contains('password') && (body.contains('reset') || body.contains('forgot'))) {
              // Make sure it's not an error page
              if (!body.contains('400 |') && !body.contains('404 |') && !body.contains('error')) {
                // Check for form elements that indicate a real reset form
                if (body.contains('<form') &&
                    (body.contains('name="login"') || body.contains('type="email"'))) {
                  isValidResetForm = true;
                }
              }
            }

            if (isValidResetForm) {
              workingEndpoint = endpoint;
              responseBody = response.body;

              // Check for reCAPTCHA presence
              requiresRecaptcha = _detectRecaptcha(response.body);
              if (requiresRecaptcha) {
                debugPrint(
                    '[ResetPasswordService] reCAPTCHA detected on server - WebView required');
              }

              // Extract cookies
              final cookieHeader = response.headers['set-cookie'];
              if (cookieHeader != null) {
                cookies = _parseCookies(cookieHeader);
              }

              debugPrint(
                  '[ResetPasswordService] Found working endpoint: $endpoint');
              break;
            } else {
              debugPrint(
                  '[ResetPasswordService] Endpoint $endpoint returned website error page, skipping');
            }
          }
        } catch (e) {
          debugPrint('[ResetPasswordService] Error testing $endpoint: $e');
          continue;
        }
      }

      if (workingEndpoint == null) {
        debugPrint('[ResetPasswordService] No working endpoint found, trying direct API approach');

        // Try direct API call to Odoo's JSON-RPC endpoint for password reset
        return await _tryDirectApiReset(cleanUrl, database, login);
      }

      // If reCAPTCHA is detected, return WebView requirement
      if (requiresRecaptcha) {
        final webViewUrl = '$cleanUrl$workingEndpoint?db=$database';
        debugPrint(
            '[ResetPasswordService] Returning WebView requirement for: $webViewUrl');
        return {
          'success': false,
          'requiresWebView': true,
          'webViewUrl': webViewUrl,
          'message':
          'This server requires additional security verification. Please complete the reset in the secure browser.',
        };
      }

      debugPrint('[ResetPasswordService] Using endpoint: $workingEndpoint');

      // Extract all form data from the HTML response
      final Map<String, String> formData = _extractAllFormData(responseBody!, login, database);

      debugPrint(
          '[ResetPasswordService] Form data extracted: ${formData.map((k, v) => MapEntry(k, (k.contains('token') || k.contains('csrf')) && v.isNotEmpty ? '(${v.length} chars)' : v))}');

      debugPrint('[ResetPasswordService] Sending reset request');
      debugPrint('  • endpoint:  $workingEndpoint');
      debugPrint('  • db:        ${database.isEmpty ? '(none)' : database}');
      debugPrint('  • login:     $login');
      debugPrint('  • form fields: ${formData.length}');
      debugPrint('  • cookies:   ${cookies != null ? 'included' : 'none'}');

      // Step 3: Try multiple approaches to handle different Odoo configurations

      // Approach 1: Standard form submission
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
        'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Origin': cleanUrl,
        'Referer': '$cleanUrl$workingEndpoint',
        'Upgrade-Insecure-Requests': '1',
      };

      if (cookies != null) {
        headers['Cookie'] = cookies.values.join('; ');
      }

      // First attempt with current form data - use proper form encoding
      var response = await http
          .post(
        Uri.parse('$cleanUrl$workingEndpoint'),
        headers: headers,
        body: Uri(queryParameters: formData).query,
      )
          .timeout(const Duration(seconds: 30));

      debugPrint('[ResetPasswordService] Response received (attempt 1)');
      debugPrint('  • status: ${response.statusCode}');

      // If 400 error, try different approaches
      if (response.statusCode == 400) {
        debugPrint(
            '[ResetPasswordService] Bad request (400). Trying alternative approaches...');

        // Approach 2: Try without any tokens
        final simpleFormData = {
          'login': login,
          if (database.isNotEmpty) 'db': database,
          'redirect': '/web/login',
        };

        debugPrint('[ResetPasswordService] Trying without tokens...');
        response = await http
            .post(
          Uri.parse('$cleanUrl$workingEndpoint'),
          headers: headers,
          body: Uri(queryParameters: simpleFormData).query,
        )
            .timeout(const Duration(seconds: 30));

        debugPrint(
            '[ResetPasswordService] Response received (attempt 2 - no tokens)');
        debugPrint('  • status: ${response.statusCode}');

        // If still 400, try with database in URL instead of form data
        if (response.statusCode == 400 && database.isNotEmpty) {
          debugPrint('[ResetPasswordService] Trying with database in URL...');
          final urlWithDb = '$cleanUrl$workingEndpoint?db=$database';
          final formDataWithoutDb = Map<String, String>.from(formData);
          formDataWithoutDb.remove('db'); // Remove db from form data since it's in URL

          response = await http
              .post(
            Uri.parse(urlWithDb),
            headers: {
              ...headers,
              'Referer': urlWithDb,
            },
            body: Uri(queryParameters: formDataWithoutDb).query,
          )
              .timeout(const Duration(seconds: 30));

          debugPrint(
              '[ResetPasswordService] Response received (attempt 3 - db in URL)');
          debugPrint('  • status: ${response.statusCode}');

          // If still 400, try a minimal approach with just login and db
          if (response.statusCode == 400) {
            debugPrint('[ResetPasswordService] Trying minimal form data...');
            final minimalData = {
              'login': login,
            };

            response = await http
                .post(
              Uri.parse(urlWithDb),
              headers: {
                ...headers,
                'Referer': urlWithDb,
              },
              body: Uri(queryParameters: minimalData).query,
            )
                .timeout(const Duration(seconds: 30));

            debugPrint(
                '[ResetPasswordService] Response received (attempt 4 - minimal)');
            debugPrint('  • status: ${response.statusCode}');
          }
        }
      }

      // Log response headers for debugging
      debugPrint('  • response headers: ${response.headers}');

      // Check for redirect (common in successful form submissions)
      if (response.statusCode == 302 || response.statusCode == 303) {
        final location = response.headers['location'];
        debugPrint('[ResetPasswordService] Redirect detected: $location');

        // Follow redirect to get the final response
        if (location != null) {
          try {
            final redirectUrl =
            location.startsWith('http') ? location : '$cleanUrl$location';
            final redirectResponse = await http.get(
              Uri.parse(redirectUrl),
              headers: {
                'User-Agent': headers['User-Agent']!,
                'Accept': headers['Accept']!,
                if (cookies != null)
                  'Cookie': cookies.entries
                      .map((e) => '${e.key}=${e.value}')
                      .join('; '),
              },
            ).timeout(const Duration(seconds: 30));

            debugPrint(
                '[ResetPasswordService] Redirect response: ${redirectResponse.statusCode}');

            // Check the final page for success/error indicators
            final responseBody = redirectResponse.body.toLowerCase();
            if (_containsSuccessIndicators(responseBody)) {
              return {
                'success': true,
                'message':
                'Password reset email sent successfully. Please check your email for reset instructions.',
              };
            } else if (_containsErrorIndicators(responseBody)) {
              return {
                'success': false,
                'message': 'User not found or invalid email address.',
              };
            }
          } catch (e) {
            debugPrint('[ResetPasswordService] Redirect follow failed: $e');
          }
        }

        // Assume success for redirects (common pattern in Odoo)
        return {
          'success': true,
          'message':
          'Password reset email sent successfully. Please check your email for reset instructions.',
        };
      }

      if (response.statusCode == 200) {
        // Check if the response contains success indicators
        final responseBody = response.body.toLowerCase();

        if (_containsSuccessIndicators(responseBody)) {
          debugPrint(
              '[ResetPasswordService] Detected success indicators in response.');
          return {
            'success': true,
            'message':
            'Password reset email sent successfully. Please check your email for reset instructions.',
          };
        } else if (_containsErrorIndicators(responseBody)) {
          debugPrint(
              '[ResetPasswordService] Detected error indicators in response.');
          return {
            'success': false,
            'message': 'User not found or invalid email address.',
          };
        } else {
          // Check if we're still on the reset password form (indicates error)
          if (responseBody.contains('<form') &&
              responseBody.contains('reset') &&
              responseBody.contains('password')) {
            debugPrint(
                '[ResetPasswordService] Still on reset form - likely validation error.');
            return {
              'success': false,
              'message':
              'Unable to send reset email. Please verify the email address is correct.',
            };
          }

          // Assume success if no error indicators found
          debugPrint(
              '[ResetPasswordService] No explicit indicators found; assuming success.');
          return {
            'success': true,
            'message':
            'Password reset email sent successfully. Please check your email for reset instructions.',
          };
        }
      } else if (response.statusCode == 400) {
        debugPrint(
            '[ResetPasswordService] Bad request (400). Checking response body for specific errors.');

        // Log the full response body for debugging
        debugPrint('[ResetPasswordService] Response body (first 1000 chars): ${response.body.length > 1000 ? response.body.substring(0, 1000) : response.body}');

        final errorBody = response.body.toLowerCase();
        if (errorBody.contains('user not found') ||
            errorBody.contains('no user found')) {
          return {
            'success': false,
            'message': 'No user found with this email address.',
          };
        } else if (errorBody.contains('invalid email') ||
            errorBody.contains('invalid login')) {
          return {
            'success': false,
            'message': 'Please enter a valid email address.',
          };
        }

        return {
          'success': false,
          'message':
          'Unable to send reset email. Please verify your email address and try again.',
        };
      } else if (response.statusCode == 404) {
        debugPrint(
            '[ResetPasswordService] Endpoint not found (404). Check Odoo version/modules.');
        return {
          'success': false,
          'message': 'Reset password service not available on this server.',
        };
      } else {
        debugPrint(
            '[ResetPasswordService] Non-success status: ${response.statusCode}');
        return {
          'success': false,
          'message':
          'Failed to send reset email. Server returned status: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('[ResetPasswordService] Exception: $e');
      if (e.toString().contains('TimeoutException')) {
        return {
          'success': false,
          'message':
          'Request timeout. Please check your internet connection and try again.',
        };
      } else if (e.toString().contains('SocketException')) {
        return {
          'success': false,
          'message': 'Network error. Please check your internet connection.',
        };
      } else {
        return {
          'success': false,
          'message': 'An error occurred: ${e.toString()}',
        };
      }
    }
  }

  static bool _containsSuccessIndicators(String responseBody) {
    return responseBody.contains('password reset') ||
        responseBody.contains('email sent') ||
        responseBody.contains('check your email') ||
        responseBody.contains('reset link') ||
        responseBody.contains('instructions sent') ||
        responseBody.contains('email has been sent');
  }

  static bool _containsErrorIndicators(String responseBody) {
    return responseBody.contains('user not found') ||
        responseBody.contains('invalid email') ||
        responseBody.contains('error') ||
        responseBody.contains('not found') ||
        responseBody.contains('invalid user');
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  static bool isValidUrl(String url) {
    if (url.trim().isEmpty) return false;
    try {
      final input = url.trim();
      final withScheme = input.startsWith('http://') || input.startsWith('https://')
          ? input
          : 'https://$input';

      final uri = Uri.tryParse(withScheme);
      if (uri == null) return false;

      // Must have http/https scheme and non-empty authority/host
      if (!(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
        return false;
      }
      if (!uri.hasAuthority || (uri.host).isEmpty) {
        return false;
      }

      // Validate host characters (simple DNS-ish check). Allow dots and hyphens in labels.
      final host = uri.host;
      final hostPattern = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$');
      if (!hostPattern.hasMatch(host)) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, String> _extractAllFormData(String html, String login, String database) {
    final Map<String, String> formData = {};

    // Add the login (email) - this is always required
    formData['login'] = login;

    // Add database if provided
    if (database.isNotEmpty) {
      formData['db'] = database;
    }

    // Add redirect parameter
    formData['redirect'] = '/web/login';

    // Extract all input fields from the form
    final inputPattern = RegExp(
      r'<input[^>]*name=["\x27]([^"\x27]+)["\x27][^>]*(?:value=["\x27]([^"\x27]*)["\x27])?[^>]*>',
      caseSensitive: false,
    );

    final matches = inputPattern.allMatches(html);
    for (final match in matches) {
      final name = match.group(1);
      final value = match.group(2) ?? '';

      if (name != null && name.isNotEmpty) {
        // Skip login field as we're setting it manually
        if (name.toLowerCase() == 'login') continue;

        // Include important fields like tokens, csrf, etc.
        if (name.toLowerCase().contains('token') ||
            name.toLowerCase().contains('csrf') ||
            name.toLowerCase() == 'db' ||
            name.toLowerCase() == 'redirect') {
          formData[name] = value;
          debugPrint('[ResetPasswordService] Found form field: $name = ${value.isNotEmpty ? '(${value.length} chars)' : '(empty)'}');
        }
      }
    }

    // Also try to extract CSRF token from meta tags
    final metaCsrfPattern = RegExp(
      r'<meta[^>]*name=["\x27]csrf-token["\x27][^>]*content=["\x27]([^"\x27]*)["\x27]',
      caseSensitive: false,
    );
    final metaMatch = metaCsrfPattern.firstMatch(html);
    if (metaMatch != null && metaMatch.group(1) != null) {
      formData['csrf_token'] = metaMatch.group(1)!;
      debugPrint('[ResetPasswordService] Found meta CSRF token: (${metaMatch.group(1)!.length} chars)');
    }

    // Extract JavaScript variables for tokens
    final jsTokenPatterns = [
      RegExp(r'csrf_token["\x27]?\s*:\s*["\x27]([^"\x27]+)["\x27]', caseSensitive: false),
      RegExp(r'"csrf_token"\s*:\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'var\s+csrf_token\s*=\s*["\x27]([^"\x27]+)["\x27]', caseSensitive: false),
    ];

    for (final pattern in jsTokenPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null && match.group(1) != null && match.group(1)!.isNotEmpty) {
        formData['csrf_token'] = match.group(1)!;
        debugPrint('[ResetPasswordService] Found JS CSRF token: (${match.group(1)!.length} chars)');
        break;
      }
    }

    return formData;
  }

  static String? _extractCsrfToken(String html) {
    // Look for CSRF token in various common patterns
    final patterns = [
      RegExp(
          r'<input[^>]*name=["\x27]csrf_token["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]'),
      RegExp(
          r'<meta[^>]*name=["\x27]csrf-token["\x27][^>]*content=["\x27]([^"\x27]*)["\x27]'),
      RegExp(r'csrf_token["\x27]?\s*:\s*["\x27]([^"\x27]*)'),
      RegExp(r'"csrf_token"\s*:\s*"([^"]*)"'),
      RegExp(
          r'name=["\x27]csrf_token["\x27]\s+value=["\x27]([^"\x27]*)["\x27]'),
      RegExp(
          r'value=["\x27]([^"\x27]*)["\x27]\s+name=["\x27]csrf_token["\x27]'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null &&
          match.group(1) != null &&
          match.group(1)!.isNotEmpty) {
        return match.group(1);
      }
    }

    return null;
  }

  static String? _extractTokenValue(String html) {
    // Look for token field with value - try multiple patterns
    final patterns = [
      // Standard input with value attribute
      RegExp(
          r'<input[^>]*name=["\x27]token["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]',
          caseSensitive: false),
      RegExp(
          r'<input[^>]*value=["\x27]([^"\x27]*)["\x27][^>]*name=["\x27]token["\x27]',
          caseSensitive: false),

      // Hidden input variations
      RegExp(
          r'<input[^>]*type=["\x27]hidden["\x27][^>]*name=["\x27]token["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]',
          caseSensitive: false),
      RegExp(
          r'<input[^>]*name=["\x27]token["\x27][^>]*type=["\x27]hidden["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]',
          caseSensitive: false),

      // JavaScript variable patterns
      RegExp(r'token["\x27]?\s*:\s*["\x27]([^"\x27]+)["\x27]',
          caseSensitive: false),
      RegExp(r'var\s+token\s*=\s*["\x27]([^"\x27]+)["\x27]',
          caseSensitive: false),

      // Form data patterns
      RegExp(r'name=["\x27]token["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null &&
          match.group(1) != null &&
          match.group(1)!.isNotEmpty) {
        debugPrint(
            '[ResetPasswordService] Token found with pattern: ${pattern.pattern}');
        return match.group(1);
      }
    }

    // If no value found, check if token field exists but is empty
    if (html.toLowerCase().contains('name="token"') ||
        html.toLowerCase().contains("name='token'")) {
      debugPrint(
          '[ResetPasswordService] Token field exists but no value found - this might be dynamically populated');
      // Return null instead of empty string to indicate we shouldn't include this field
      return null;
    }

    return null;
  }

  static bool _detectRecaptcha(String responseBody) {
    final body = responseBody.toLowerCase();

    // Check for various reCAPTCHA indicators
    final recaptchaIndicators = [
      'recaptcha',
      'grecaptcha',
      'google.com/recaptcha',
      'recaptcha_token_response',
      'data-sitekey',
      'g-recaptcha',
    ];

    for (String indicator in recaptchaIndicators) {
      if (body.contains(indicator)) {
        debugPrint(
            '[ResetPasswordService] reCAPTCHA indicator found: $indicator');
        return true;
      }
    }

    return false;
  }

  static Future<Map<String, dynamic>> _tryDirectApiReset(String cleanUrl, String database, String login) async {
    try {
      debugPrint('[ResetPasswordService] Trying public signup API approach');

      // Try the public signup endpoint which doesn't require authentication
      final signupUrl = '$cleanUrl/auth_signup/signup';

      final signupBody = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'dbname': database,
          'login': login,
          'name': login,
          'password': '',
          'confirm_password': '',
          'redirect': '/web',
          'token': '',
          'type': 'reset',
        },
        'id': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await http.post(
        Uri.parse(signupUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(signupBody),
      ).timeout(const Duration(seconds: 30));

      debugPrint('[ResetPasswordService] Signup API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['error'] == null) {
          debugPrint('[ResetPasswordService] Signup API reset successful');
          return {
            'success': true,
            'message': 'Password reset email sent successfully. Please check your email for reset instructions.',
          };
        } else {
          debugPrint('[ResetPasswordService] Signup API error: ${responseData['error']}');
        }
      } else {
        debugPrint('[ResetPasswordService] Signup API failed with status ${response.statusCode}');
        debugPrint('[ResetPasswordService] Signup API response body: ${response.body}');
      }

      // If signup API fails, try the web interface approach directly
      return await _tryWebInterfaceReset(cleanUrl, database, login);

    } catch (e) {
      debugPrint('[ResetPasswordService] Signup API failed: $e');
      return await _tryWebInterfaceReset(cleanUrl, database, login);
    }
  }

  static Future<Map<String, dynamic>> _tryWebInterfaceReset(String cleanUrl, String database, String login) async {
    try {
      debugPrint('[ResetPasswordService] Trying web interface fallback');
      // 1) Establish session on /web/login with a redirect (no db in URL)
      final loginUrl = '$cleanUrl/web/login';
      final resetUrl = '$cleanUrl/web/reset_password';

      final initialGet = await http
          .get(
        Uri.parse('$loginUrl?redirect=/web/login'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        },
      )
          .timeout(const Duration(seconds: 15));

      if (initialGet.statusCode != 200) {
        debugPrint('[ResetPasswordService] Failed to open /web/login: ${initialGet.statusCode}');
      }

      // Collect cookies from initial GET
      Map<String, String> cookies = {};
      final initialSetCookie = initialGet.headers['set-cookie'];
      if (initialSetCookie != null) {
        cookies.addAll(_parseCookies(initialSetCookie));
      }

      // 2) Load the reset password form (no db in URL, use redirect)
      final resetGet = await http
          .get(
        Uri.parse('$resetUrl?redirect=/web/login'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          if (cookies.isNotEmpty)
            'Cookie': cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
          'Referer': '$loginUrl?redirect=/web/login',
        },
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('[ResetPasswordService] GET /web/reset_password status: ${resetGet.statusCode}');

      if (resetGet.statusCode != 200) {
        // Fallback to WebView to handle website routing intricacies
        return {
          'success': false,
          'requiresWebView': true,
          'webViewUrl': '$cleanUrl/web/login?db=$database',
          'message': 'Unable to load reset form automatically. Please complete the reset in the secure browser.',
        };
      }

      // Merge any new cookies
      final resetSetCookie = resetGet.headers['set-cookie'];
      if (resetSetCookie != null) {
        cookies.addAll(_parseCookies(resetSetCookie));
      }

      // Extract CSRF/token and hidden inputs from the reset page
      final csrfToken = _extractCsrfToken(resetGet.body);
      final formData = _extractAllFormData(resetGet.body, login, database);
      if (csrfToken != null && csrfToken.isNotEmpty) {
        formData['csrf_token'] = csrfToken;
      }

      // Ensure required fields
      formData['login'] = login;
      formData['redirect'] = '/web/login';

      // 3) Submit the reset form back to /web/reset_password (with redirect in URL)
      final postHeaders = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Origin': cleanUrl,
        'Referer': '$resetUrl?redirect=/web/login',
        if (cookies.isNotEmpty)
          'Cookie': cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
      };

      final postResponse = await http
          .post(
        Uri.parse('$resetUrl?redirect=/web/login'),
        headers: postHeaders,
        body: Uri(queryParameters: formData).query,
      )
          .timeout(const Duration(seconds: 30));

      debugPrint('[ResetPasswordService] POST /web/reset_password status: ${postResponse.statusCode}');

      // Handle redirects as success pattern
      if (postResponse.statusCode == 302 || postResponse.statusCode == 303) {
        final location = postResponse.headers['location'];
        debugPrint('[ResetPasswordService] Redirect after reset: $location');
        return {
          'success': true,
          'message': 'Password reset email sent successfully. Please check your email for reset instructions.',
        };
      }

      if (postResponse.statusCode == 200) {
        final body = postResponse.body.toLowerCase();
        if (_containsSuccessIndicators(body)) {
          return {
            'success': true,
            'message': 'Password reset email sent successfully. Please check your email for reset instructions.',
          };
        }
        if (_containsErrorIndicators(body)) {
          return {
            'success': false,
            'message': 'No user found with this email address.',
          };
        }
        // If ambiguous, assume success like the browser flow
        return {
          'success': true,
          'message': 'Password reset email sent successfully. Please check your email for reset instructions.',
        };
      }

      // Fallback to WebView if unexpected status
      return {
        'success': false,
        'requiresWebView': true,
        'webViewUrl': '$cleanUrl/web/login?db=$database',
        'message': 'Unable to reset password automatically. Please complete the reset in the secure browser.',
      };

    } catch (e) {
      debugPrint('[ResetPasswordService] Web interface fallback failed: $e');
      return {
        'success': false,
        'requiresWebView': true,
        'webViewUrl': '$cleanUrl/web/login?db=$database',
        'message': 'Unable to reset password automatically. Please complete the reset in the secure browser.',
      };
    }
  }

  static Map<String, String> _parseCookies(String cookieHeader) {
    // Parse multiple cookies from a combined Set-Cookie header value.
    // Strategy: capture name=value pairs that occur at the beginning or just after ", "
    // and stop at the first semicolon (attributes come after semicolons).
    final cookies = <String, String>{};
    final cookiePattern = RegExp(r'(?:(?<=^)|(?<=,\s))([^=;,\s]+)=([^;\r\n,]+)');
    for (final match in cookiePattern.allMatches(cookieHeader)) {
      final name = match.group(1);
      final value = match.group(2);
      if (name != null && value != null) {
        cookies[name.trim()] = value.trim();
      }
    }
    return cookies;
  }
}
