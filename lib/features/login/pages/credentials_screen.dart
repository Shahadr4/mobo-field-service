import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import 'package:provider/provider.dart';
import '../../../shared/widgets/loaders/loading_widget.dart';
import '../../../app/app_entry.dart';
import '../../../core/routing/page_transition.dart';
import '../providers/login_provider.dart';
import 'otp_page.dart';
import 'reset_password_screen.dart';
import 'login_layout.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/biometric_context_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/dashboard/provider/timesheet_provider.dart';
import '../../../features/dashboard/provider/dashboard_task_provider.dart';
import '../../../features/dashboard/provider/check_in_provider.dart';
import '../../../features/dashboard/provider/task_stats_provider.dart';
import '../../../features/tasks/provider/task_provider.dart';
import '../../../features/employee/provider/employee_provider.dart';
import '../../../features/timesheet/provider/timesheet_list_provider.dart';
import '../../../features/map/provider/map_provider.dart';
import '../../profile/providers/profile_provider.dart';

class CredentialsScreen extends StatefulWidget {
  final String url;
  final String database;
  final bool isAddingAccount;
  final String? prefilledUsername;

  const CredentialsScreen({
    super.key,
    required this.url,
    required this.database,
    this.isAddingAccount = false,
    this.prefilledUsername,
  });

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  late LoginProvider _provider;

  // Control when to show validation messages
  bool _shouldValidate = false;

  // Track field-level errors
  bool emailHasError = false;
  bool passwordHasError = false;

  // General/inline error shown under fields
  String? inlineError;

  // Focus management
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _provider = LoginProvider();

    // Set the URL and database from the previous screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.urlController.text = widget.url;
      _provider.setDatabase(widget.database);

      // Set prefilled username if provided
      if (widget.prefilledUsername != null &&
          widget.prefilledUsername!.isNotEmpty) {
        _provider.emailController.text = widget.prefilledUsername!;
      }

      // Smart autofocus: if email is empty, focus email; otherwise focus password
      if (mounted) {
        if (_provider.emailController.text.isEmpty) {
          FocusScope.of(context).requestFocus(_emailFocus);
        } else {
          FocusScope.of(context).requestFocus(_passwordFocus);
        }
      }
    });
  }

  // Unified submit handler used by both the Sign In button and Enter key on password field
  Future<void> _handleSubmit(LoginProvider provider) async {
    log("_handleSubmit");
    FocusScope.of(context).unfocus();
    setState(() {
      _shouldValidate = true;
    });
    final formValid = provider.formKey.currentState?.validate() ?? false;
    setState(() {
      emailHasError = provider.emailController.text.isEmpty;
      final pwd = provider.passwordController.text;
      passwordHasError = pwd.isEmpty || pwd.isEmpty;
      inlineError = null;
    });

    if (!formValid) {
      await HapticFeedback.lightImpact();
      return;
    }

    if (widget.isAddingAccount) {
      final success = await _addNewAccount(provider);
      if (!mounted) return;
      if (success) {
        // Navigation to HomeScaffold is handled in _addNewAccount
        setState(() {
          inlineError = null;
        });
      } else {
        await HapticFeedback.heavyImpact();
        if (!mounted) return;
        setState(() {
          inlineError = provider.errorMessage ?? 'Failed to add account';
        });
      }
    } else {
      final biometricContext = BiometricContextService();
      biometricContext.startAccountOperation('login');

      debugPrint('[CredentialsScreen] Starting login process');
      final ok = await provider.login(context);
      debugPrint('[CredentialsScreen] Login result: $ok');


      if (!mounted) return;


      switch(ok){
        case LoginResult.success:
          debugPrint(
            '[CredentialsScreen] Login successful, navigating to BasePage',
          );
          setState(() {
            inlineError = null;
          });

          await Future.delayed(const Duration(milliseconds: 100));
          // Save autofill data and finish autofill context
          TextInput.finishAutofillContext(shouldSave: true);

          if (mounted) {
            context.read<TimesheetProvider>().reset();
            context.read<DashboardTaskProvider>().reset();
            context.read<TaskProvider>().reset();
            context.read<AssigneeProvider>().reset();
            context.read<TimesheetListProvider>().reset();
            context.read<TaskStatsProvider>().reset();
            context.read<CheckInProvider>().reset();
            context.read<MapProvider>().reset();
            context.read<ProfileProvider>().resetState();
          }

          Navigator.of(context).pushAndRemoveUntil(
            dynamicRoute(context, const AppEntry()),
            // dynamicRoute(context, const OtpPage()),
                (route) => false,
          );
          break;

        case LoginResult.twoFactorRequired:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TotpPage(
                protocol: provider.selectedProtocol,
                serverUrl: provider.urlController.text.trim(),
                database: provider.database!,
                username: provider.emailController.text.trim(),
                password: provider.passwordController.text.trim(),
              ),
            ),
          );
          break;
        case LoginResult.invalidCredentials:
          setState(() => inlineError = 'Invalid username or password');
          break;

        case LoginResult.networkError:
          setState(() => inlineError = 'Network error');
          break;
      }




      // if (ok) {
      //   debugPrint(
      //     '[CredentialsScreen] Login successful, navigating to BasePage',
      //   );
      //   setState(() {
      //     inlineError = null;
      //   });
      //
      //   await Future.delayed(const Duration(milliseconds: 100));
      //   // Save autofill data and finish autofill context
      //   TextInput.finishAutofillContext(shouldSave: true);
      //   final expense = context.read<ExpenseProvider>();
      //   final commonProvider = context.read<CommonProvider>();
      //   final bottom = context.read<BottomNavProvider>();
      //
      //   expense.reset();
      //   commonProvider.reset();
      //   bottom.changeIndex(0);
      //
      //   Navigator.of(context).pushAndRemoveUntil(
      //     dynamicRoute(context, const AppEntry()),
      //   // dynamicRoute(context, const OtpPage()),
      //    (route) => false,
      //   );
      // }
    }
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<bool> _addNewAccount(LoginProvider provider) async {
    try {
      debugPrint('[CredentialsScreen] Adding new account');

      // Mark as account operation to prevent biometric prompt
      final biometricContext = BiometricContextService();
      biometricContext.startAccountOperation('add_account');

      // Derive serverUrl and database from passed params or current session
      final sessionService = SessionService.instance;
      final current = sessionService.currentSession;
      String serverUrl = widget.url.isNotEmpty
          ? widget.url
          : (current?.serverUrl ?? '');
      String database = widget.database.isNotEmpty
          ? widget.database
          : (current?.database ?? '');

      // Ensure URL has scheme to avoid: Bad state: Cannot use origin without a scheme
      serverUrl = _ensureScheme(serverUrl);

      if (serverUrl.isEmpty || database.isEmpty) {
        debugPrint('[CredentialsScreen] Missing serverUrl or database');
        provider.errorMessage =
            'Server URL or Database is missing. Please go back and try again.';
        biometricContext.endAccountOperation('add_account');
        return false;
      }

      log("starting authentication while adding");

      // Authenticate with the new credentials
      final newSession = await OdooSessionManager.authenticate(
        serverUrl: serverUrl,
        database: database,
        username: provider.emailController.text.trim(),
        password: provider.passwordController.text,
      );

      if (newSession == null) {
        debugPrint('[CredentialsScreen] Authentication failed for new account');
        provider.errorMessage =
            'Authentication failed. Please check your credentials.';
        biometricContext.endAccountOperation('add_account');
        return false;
      }

      final client = await OdooSessionManager.getClientEnsured();

      final userCompanies = await OdooSessionManager.getAllowedCompaniesList();

      final allowed = userCompanies.map((e) => e['id'] as int).toList();

      final selectedCompany = newSession.companyId;
      final fixedSession = newSession.copyWith(
        selectedCompanyId: selectedCompany,
        allowedCompanyIds: newSession.allowedCompanyIds,
      );
      await fixedSession.saveToPrefs();
      await OdooSessionManager.updateSession(fixedSession);
      sessionService.updateSession(fixedSession);
      // Persist server URL history and server->database mapping for reuse
      try {
        final prefs = await SharedPreferences.getInstance();
        // Save URL history (keep most recent first, max 10)
        List<String> urls = prefs.getStringList('previous_server_urls') ?? [];
        if (!urls.contains(serverUrl)) {
          urls.insert(0, serverUrl);
          if (urls.length > 10) {
            urls = urls.take(10).toList();
          }
          await prefs.setStringList('previous_server_urls', urls);
        }
        // Save mapping: server -> database
        await prefs.setString('server_db_$serverUrl', database);
      } catch (_) {
        // Non-fatal: ignore persistence errors
      }

      // Switch to the new account
      await sessionService.switchToAccount(newSession);

      debugPrint(
        '[CredentialsScreen] New account added and switched successfully',
      );

      // Navigate to AppEntry so startup checks (including inventory module check)
      // can run and show MissingInventoryScreen if needed.

      if (mounted) {
        context.read<TimesheetProvider>().reset();
        context.read<DashboardTaskProvider>().reset();
        context.read<TaskProvider>().reset();
        context.read<AssigneeProvider>().reset();
        context.read<TimesheetListProvider>().reset();
        context.read<TaskStatsProvider>().reset();
        context.read<CheckInProvider>().reset();
        context.read<MapProvider>().reset();
        context.read<ProfileProvider>().resetState();

        Navigator.of(context).pushAndRemoveUntil(
          dynamicRoute(context, const AppEntry()),
          (route) => false,
        );
      }

      biometricContext.endAccountOperation('add_account');
      return true;
    }  catch (e) {
      log("++++++EEEEEEEEEEEEEEEEEEEEEE+++++++++++++++++++");
      debugPrint('[CredentialsScreen] Error adding new account: ${e}');


      final msg = e.toString().toLowerCase();

      if( msg.contains('type \'null\'') &&
          msg.contains('map<string') &&
          !msg.contains('html') &&
          !msg.contains('502') &&
          !msg.contains('timeout')) {
        log("errror 2fa");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TotpPage(
              protocol: provider.selectedProtocol,
              serverUrl: provider.urlController.text.trim(),
              database: provider.database!,
              username: provider.emailController.text.trim(),
              password: provider.passwordController.text.trim(),
            ),
          ),
        );
        provider.errorMessage = 'Account protected by 2FA';
        return false;


      }
      log("sdss");
      provider.errorMessage = 'Failed to add account: ${e.toString()}';
      final biometricContext = BiometricContextService();
      biometricContext.endAccountOperation('add_account');

      return false;
    }
  }

  // Ensures the URL has a scheme (http/https). Defaults to https if missing.
  String _ensureScheme(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    final hasScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    return hasScheme ? trimmed : 'https://$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<LoginProvider>(
        builder: (context, provider, child) {
          // Sync inlineError with provider.errorMessage
          if (provider.errorMessage != inlineError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                inlineError = provider.errorMessage;
              });
            });
          }

          return LoginLayout(
            title: widget.isAddingAccount ? 'Add Account' : 'Sign In',
            subtitle: widget.isAddingAccount
                ? 'Enter credentials for the new account'
                : 'Enter your credentials to continue',
            backButton: Positioned(
              top: 24,
              left: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(32),
                  child: Container(
                    height: 64,
                    width: 64,
                    alignment: Alignment.center,
                    child: const HugeIcon(
                      icon:HugeIcons.strokeRoundedArrowLeft01,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            child: Form(
              key: provider.formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Email Field
                    LoginTextField(
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      controller: provider.emailController,
                      hint: 'Email',
                      prefixIcon: HugeIcon(icon: HugeIcons.strokeRoundedMail01,),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !provider.disableFields,
                      focusNode: _emailFocus,
                      textInputAction: TextInputAction.next,
                      hasError: emailHasError,
                      autovalidateMode: _shouldValidate
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      validator: (value) {
                        if (provider.isLoadingDatabases || !_shouldValidate) {
                          return null;
                        }
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        return null;
                      },
                      onChanged: (val) {
                        setState(() {
                          emailHasError = val.isEmpty;
                          if (inlineError != null) {
                            inlineError = null;
                          }
                        });
                      },
                      onFieldSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_passwordFocus);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    LoginTextField(
                      autofillHints: const [AutofillHints.password],
                      controller: provider.passwordController,
                      hint: 'Password',
                      prefixIcon:HugeIcon(icon: HugeIcons.strokeRoundedLockPassword,),
                      obscureText: provider.obscurePassword,
                      enabled: !provider.disableFields,
                      focusNode: _passwordFocus,
                      textInputAction: TextInputAction.done,
                      hasError: passwordHasError,
                      autovalidateMode: _shouldValidate
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      validator: (value) {
                        if (provider.isLoadingDatabases || !_shouldValidate) {
                          return null;
                        }
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.isEmpty) {
                          return 'Password must be at least 1 characters';
                        }
                        return null;
                      },
                      suffixIcon: IconButton(
                        icon: Icon(
                          provider.obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.black54,
                          size: 20,
                        ),
                        onPressed: provider.togglePasswordVisibility,
                      ),
                      onChanged: (val) {
                        setState(() {
                          passwordHasError = val.isEmpty || val.isEmpty;
                          if (inlineError != null) {
                            inlineError = null;
                          }
                        });
                      },
                      onFieldSubmitted: (_) async {
                        if (!(provider.isLoading ||
                            provider.isLoadingDatabases)) {
                          await _handleSubmit(provider);
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // Forgot Password Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          debugPrint(
                            '[CredentialsScreen] ===== FORGOT PASSWORD BUTTON TAPPED =====',
                          );
                          debugPrint('[CredentialsScreen] Navigation params:');
                          debugPrint('  • url:      ${widget.url}');
                          debugPrint('  • database: ${widget.database}');
                          debugPrint(
                            '[CredentialsScreen] Navigating to ResetPasswordScreen...',
                          );
                          // FastNavigation.navigateTo(
                          //   context,
                          //   ResetPasswordScreen(
                          //     url: widget.url,
                          //     database: widget.database,
                          //   ),
                          //   fromLeft: false,
                          Navigator.push(
                            context,
                            dynamicRoute(
                              context,
                              ResetPasswordScreen(
                                url: widget.url,
                                database: widget.database,
                              ),
                            ),
                          );
                          debugPrint(
                            '[CredentialsScreen] Navigation call completed',
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Error display
                    LoginErrorDisplay(error: inlineError),

                    // Sign In Button
                    LoginButton(
                      text: widget.isAddingAccount ? 'Add Account' : 'Sign In',
                      isLoading: provider.isLoading,
                      loadingWidget: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.isAddingAccount
                                ? 'Adding Account'
                                : 'Signing In',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 12),
                          LoadingWidget(
                            color: Colors.white,
                            size: 28,
                            variant: LoadingVariant.staggeredDots,
                          ),
                        ],
                      ),
                      onPressed:
                          provider.isLoading || provider.isLoadingDatabases
                          ? null
                          : () async {
                              await _handleSubmit(provider);
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
