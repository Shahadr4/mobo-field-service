import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';
import 'credentials_screen.dart';
import '../../../core/routing/page_transition.dart';
import 'login_layout.dart';

class ServerSetupScreen extends StatefulWidget {
  final bool isAddingAccount;

  const ServerSetupScreen({super.key, this.isAddingAccount = false});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _databaseFadeController;
  late Animation<double> _databaseFadeAnimation;

  // Control when to show validation messages
  bool _shouldValidate = false;

  // Track field-level errors
  bool urlHasError = false;
  bool dbHasError = false;

  // General/inline error shown under fields
  String? inlineError;

  // Debounce timer for auto-fetching databases on URL change
  Timer? _urlDebounce;
  // Suppress auto-fetch while waiting for explicit suggestion selection
  bool _awaitingSuggestionSelection = false;

  @override
  void initState() {
    super.initState();
    _databaseFadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _databaseFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _databaseFadeController,
      curve: Curves.easeInOut,
    ));


  }

  @override
  void dispose() {
    _urlDebounce?.cancel();
    _databaseFadeController.dispose();
    super.dispose();
  }

  // Handle database field animation when databases are fetched
  void _handleDatabaseFetch(LoginProvider provider) {
    if (provider.urlCheck && provider.dropdownItems.isNotEmpty) {

      _databaseFadeController.forward();
    } else if (!provider.urlCheck || provider.dropdownItems.isEmpty) {
      _databaseFadeController.reverse();
    }
  }

  // Navigate to credentials screen
  void _goToCredentials(LoginProvider provider) {
    // FastNavigation.navigateTo(
    //   context,
    //   CredentialsScreen(
    Navigator.push(
      context,
      dynamicRoute(
        context,
        CredentialsScreen(
          url: provider.getFullUrl(),
          database: provider.database!,
          isAddingAccount: widget.isAddingAccount,
        ),
      ),
    );
  }

  // Check if user can proceed to credentials
  bool _canProceedToCredentials(LoginProvider provider) {
    return provider.urlController.text.trim().isNotEmpty &&
        provider.database != null &&
        provider.database!.isNotEmpty &&
        !provider.isLoadingDatabases &&
        provider.urlCheck;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginProvider(),
      child: Consumer<LoginProvider>(
        builder: (context, provider, child) {
          // Handle database field animation
          _handleDatabaseFetch(provider);

          // Sync inlineError with provider.errorMessage
          if (!provider.isLoadingDatabases &&
              provider.errorMessage != inlineError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                inlineError = provider.errorMessage;
              });
            });
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();   // removes focus from text fields
            },
            child: LoginLayout(
              title: 'Sign In',
              subtitle: 'Configure your server connection',
              child: Form(
                key: provider.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Server URL field with custom autocomplete
                    _CustomAutocompleteField(
                      controller: provider.urlController,
                      suggestions: provider.previousUrls,
                      enableSuggestions: !provider.isLoadingDatabases &&
                          !(provider.urlCheck && provider.dropdownItems.isNotEmpty),
                      onSuggestionSelected: (String selection) {
                        // Use the new helper method to separate protocol and domain
                        provider.setUrlFromFullUrl(selection);
            
                        // Immediately seed this URL into history so it persists for future launches
                        provider.seedUrlToHistory(selection);
            
                        // Get the domain part for validation
                        final domain = provider.extractDomain(selection);
            
                        setState(() {
                          urlHasError = domain.isEmpty;
                          // Resume auto-fetching now that user explicitly selected a suggestion
                          _awaitingSuggestionSelection = false;
                        });
            
                        if (domain.trim().isNotEmpty) {
                          _urlDebounce?.cancel();
                          if (!provider.isLoadingDatabases &&
                              provider.isValidUrl(domain)) {
                            setState(() {
                              dbHasError = false;
                              inlineError = null;
                              _shouldValidate = false;
                            });
                            provider.formKey.currentState?.validate();
                            provider.fetchDatabaseList();
                          }
                        }
                      },
                      child: LoginUrlTextField(
                        controller: provider.urlController,
                        hint: 'Enter Server Address',
                        prefixIcon: Icons.dns,
                        enabled: !provider.disableFields,
                        hasError: urlHasError,
                        selectedProtocol: provider.selectedProtocol,
                        isLoading: provider.isLoadingDatabases,
                        onProtocolAutoDetected: () {
                          // A full URL with protocol was typed/pasted; trigger immediate DB fetch
                          // Normalize current field state and run fetch without requiring suggestion selection
                          setState(() {
                            _awaitingSuggestionSelection = false;
                            inlineError = null;
                            dbHasError = false;
                            _shouldValidate = false;
                          });
                          _urlDebounce?.cancel();
                          final trimmed = provider.urlController.text.trim();
                          if (trimmed.isNotEmpty && provider.isValidUrl(trimmed)) {
                            provider.formKey.currentState?.validate();
                            provider.fetchDatabaseList();
                          }
                        },
                        autovalidateMode: _shouldValidate
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        validator: (value) {
                          if (provider.isLoadingDatabases || !_shouldValidate) {
                            return null;
                          }
                          if (value == null || value.isEmpty) {
                            return 'Server URL is required';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          // Don't set controller.text here as it causes cursor to jump
                          // The controller already has the correct value from user input
            
                          final newUrlHasError = val.isEmpty;
                          if (urlHasError != newUrlHasError ||
                              dbHasError ||
                              inlineError != null ||
                              _shouldValidate) {
                            setState(() {
                              urlHasError = newUrlHasError;
                              dbHasError = false;
                              inlineError = null;
                              _shouldValidate = false;
                            });
                            provider.formKey.currentState?.validate();
                          }
            
                          // Debounced auto-fetch of databases
                          _urlDebounce?.cancel();
                          final trimmed = val.trim();
                          if (trimmed.isEmpty) {
                            provider.fetchDatabaseList();
                          } else {
                            _urlDebounce =
                                Timer(const Duration(milliseconds: 700), () {
                              if (!mounted) return;
                              if (_awaitingSuggestionSelection) {
                                // Wait for suggestion selection before fetching
                                return;
                              }
                              if (provider.isValidUrl(trimmed)) {
                                if (dbHasError || inlineError != null) {
                                  setState(() {
                                    dbHasError = false;
                                    inlineError = null;
                                  });
                                  provider.formKey.currentState?.validate();
                                }
                                provider.fetchDatabaseList();
                              }
                            });
                          }
                        },
                        onProtocolChanged: (protocol) {
                          provider.setProtocol(protocol);
                          // Re-fetch databases when protocol changes if URL is valid
                          final trimmed = provider.urlController.text.trim();
                          if (trimmed.isNotEmpty &&
                              provider.isValidUrl(trimmed)) {
                            _urlDebounce?.cancel();
                            _urlDebounce =
                                Timer(const Duration(milliseconds: 300), () {
                              if (!mounted) return;
                              if (_awaitingSuggestionSelection) {
                                // Do not fetch while waiting for suggestion selection
                                return;
                              }
                              provider.fetchDatabaseList();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
            
                    // Animated Database dropdown
                    AnimatedBuilder(
                      animation: _databaseFadeAnimation,
                      builder: (context, child) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _databaseFadeAnimation.value > 0 ? null : 0,
                          child: Opacity(
                            opacity: _databaseFadeAnimation.value,
                            child: Transform.translate(
                              offset: Offset(
                                  0, (1 - _databaseFadeAnimation.value) * -20),
                              child: Column(
                                children: [
                                  LoginDropdownField(
                                    hint: provider.isLoadingDatabases
                                        ? 'Loading...'
                                        : provider.errorMessage != null
                                            ? 'Unable to load'
                                            : 'Database',
                                    value: provider.database,
                                    items: provider.urlCheck &&
                                            provider.dropdownItems.isNotEmpty
                                        ? provider.dropdownItems
                                        : [],
                                    onChanged: (provider.disableFields ||
                                            provider.isLoadingDatabases)
                                        ? null
                                        : (val) {
                                            provider.setDatabase(val);
                                            setState(() {
                                              dbHasError =
                                                  (val == null || val.isEmpty);
                                              inlineError = null;
                                            });
                                            provider.formKey.currentState
                                                ?.validate();
                                          },
                                    validator: (value) {
                                      if (provider.isLoadingDatabases ||
                                          !_shouldValidate) {
                                        return null;
                                      }
                                      if (value == null || value.isEmpty) {
                                        return 'Database is required';
                                      }
                                      return null;
                                    },
                                    hasError: dbHasError,
                                    autovalidateMode: _shouldValidate
                                        ? AutovalidateMode.onUserInteraction
                                        : AutovalidateMode.disabled,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            
                    // Error display
                    LoginErrorDisplay(error: inlineError),
            
                    // Next Button
                    LoginButton(
                      text: 'Next',
                      onPressed: _canProceedToCredentials(provider)
                          ? () => _goToCredentials(provider)
                          : null,
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

class _CustomAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final Function(String) onSuggestionSelected;
  final Widget child;
  final bool enableSuggestions;

  const _CustomAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.onSuggestionSelected,
    required this.child,
    this.enableSuggestions = true,
  });

  @override
  State<_CustomAutocompleteField> createState() =>
      _CustomAutocompleteFieldState();
}

class _CustomAutocompleteFieldState extends State<_CustomAutocompleteField> {
  bool _showSuggestions = false;
  List<String> _filteredSuggestions = [];
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;
  // True only after the entry has been physically inserted into the Overlay tree.
  bool _overlayInserted = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_CustomAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update suggestions when the suggestions list changes
    if (oldWidget.suggestions != widget.suggestions) {
      debugPrint('[AutocompleteField] Suggestions updated: ${widget.suggestions.length} items');
      if (_focusNode.hasFocus) {
        // Defer updates to after the current frame to avoid modifying the tree during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!widget.enableSuggestions) {
            _hideSuggestions();
            return;
          }
          _updateSuggestions();
          if (_filteredSuggestions.isNotEmpty && _overlayEntry == null) {
            _showSuggestionsOverlay();
          } else if (_overlayEntry != null) {
            // Safely request overlay rebuild after frame
            try {
              _overlayEntry!.markNeedsBuild();
            } catch (_) {}
          }
        });
      }
    }

    // If suggestions were enabled and now disabled, hide overlay immediately
    if (oldWidget.enableSuggestions && !widget.enableSuggestions) {
      _hideSuggestions();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      if (!widget.enableSuggestions) return;
      _updateSuggestions();
      if (_filteredSuggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      }
    } else {
      _hideSuggestions();
    }
  }


  void _onTextChanged() {
    if (_focusNode.hasFocus) {
      if (!widget.enableSuggestions) {
        _hideSuggestions();
        return;
      }
      _updateSuggestions();
      if (_overlayEntry != null) {
        if (_showSuggestions && _filteredSuggestions.isNotEmpty) {
          _overlayEntry!.markNeedsBuild();
        } else {
          // Hide overlay if no suggestions
          _removeOverlay();
        }
      }
    }
  }

  void _updateSuggestions() {
    final text = widget.controller.text.toLowerCase().trim();
    debugPrint('[AutocompleteField] Updating suggestions. Text: "$text", Available: ${widget.suggestions.length}');

    if (!widget.enableSuggestions) {
      _filteredSuggestions = [];
      if (!mounted) return;
      setState(() {
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    if (text.isEmpty) {
      _filteredSuggestions = List.from(widget.suggestions);
      debugPrint('[AutocompleteField] Text empty, showing all ${_filteredSuggestions.length} suggestions');
    } else {
      _filteredSuggestions = widget.suggestions.where((suggestion) {
        final suggestionLower = suggestion.toLowerCase();

        // If user typed a protocol, use startsWith on full string
        if (text.startsWith('http://') || text.startsWith('https://')) {
          return suggestionLower.startsWith(text);
        }

        // Otherwise, compare by domain portion (ignore protocol), startsWith
        final textDomain = _extractDomainFromUrl(text);
        final suggestionDomain = _extractDomainFromUrl(suggestionLower);
        if (suggestionDomain.startsWith(textDomain)) {
          return true;
        }

        // As a fallback, do a contains match on full suggestion
        return suggestionLower.contains(textDomain);
      }).toList();
    }


    for (int i = 0; i < _filteredSuggestions.length; i++) {

    }

    debugPrint('[AutocompleteField] Final filtered count: ${_filteredSuggestions.length}');

    if (!mounted) return;
    setState(() {
      _showSuggestions = _filteredSuggestions.isNotEmpty;
    });

    // Force overlay rebuild or hide it
    if (_overlayEntry != null) {
      if (_filteredSuggestions.isEmpty) {
        debugPrint('[AutocompleteField] Removing overlay - no suggestions');
        _removeOverlay();
      } else {
        debugPrint('[AutocompleteField] Rebuilding overlay');
        try {
          _overlayEntry!.markNeedsBuild();
        } catch (_) {}
      }
    } else if (_filteredSuggestions.isNotEmpty) {
      debugPrint('[AutocompleteField] Creating new overlay');
      _showSuggestionsOverlay();
    }
  }

  String _extractDomainFromUrl(String url) {
    if (url.startsWith('https://')) {
      return url.substring(8);
    } else if (url.startsWith('http://')) {
      return url.substring(7);
    }
    return url;
  }

  void _showSuggestionsOverlay() {
    debugPrint('[AutocompleteField] _showSuggestionsOverlay called');
    if (_filteredSuggestions.isEmpty || !widget.enableSuggestions) {
      debugPrint('[AutocompleteField] Cannot show overlay - no suggestions');
      return;
    }

    if (_overlayEntry != null) {
      debugPrint('[AutocompleteField] Overlay already exists');
      return;
    }

    debugPrint('[AutocompleteField] Creating overlay with ${_filteredSuggestions.length} suggestions');

    // ── Snapshot everything from context/state NOW, BEFORE creating the
    // OverlayEntry.  The builder must NOT close over live references to this
    // state or its BuildContext; otherwise deactivated InheritedElements keep
    // _dependents alive and Flutter throws '_dependents.isEmpty'.
    final renderBox = context.findRenderObject() as RenderBox?;
    final double fieldWidth =
        renderBox?.size.width ?? (MediaQuery.of(context).size.width - 48);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color hoverColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
    final Color borderColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);

    // Snapshot the list so the builder never reads live mutable state.
    final List<String> snapshotSuggestions = List.unmodifiable(_filteredSuggestions);

    // Snapshot plain Dart references (no BuildContext dependency).
    final onSelected = widget.onSuggestionSelected;
    final hideFn = _hideSuggestions;
    final focusNode = _focusNode;
    final layerLink = _layerLink;

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        width: fieldWidth,
        child: CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 12.0,
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black.withOpacity(0.2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: snapshotSuggestions.length,
                  itemBuilder: (_, index) {
                    final suggestion = snapshotSuggestions[index];
                    return InkWell(
                      onTap: () {
                        onSelected(suggestion);
                        hideFn();
                        focusNode.unfocus();
                      },
                      hoverColor: hoverColor,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                suggestion,
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    debugPrint('[AutocompleteField] Inserting overlay into Overlay');
    // Defer insertion to post-frame to avoid build-time modifications.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _overlayEntry == null) return;
      // If _hideSuggestions was called before this post-frame ran, bail out.
      if (_overlayInserted) return;
      final overlayState = Overlay.maybeOf(context);
      if (overlayState != null && overlayState.mounted) {
        overlayState.insert(_overlayEntry!);
        _overlayInserted = true;
        debugPrint('[AutocompleteField] Overlay inserted successfully');
      } else {
        // Insertion skipped — discard so _removeOverlay won't try to remove it.
        _overlayEntry = null;
        debugPrint('[AutocompleteField] Overlay insertion skipped - overlay not available');
      }
    });
  }

  void _hideSuggestions() {
    debugPrint('[AutocompleteField] Hiding suggestions');
    _removeOverlay();
    if (mounted) {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  void _removeOverlay() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    if (entry != null && _overlayInserted) {
      debugPrint('[AutocompleteField] Removing overlay');
      try {
        entry.remove();
      } catch (e) {
        debugPrint('[AutocompleteField] Overlay remove error (safe-ignored): $e');
      }
    } else if (entry != null) {
      // Entry was created but never inserted — just dispose it.
      debugPrint('[AutocompleteField] Overlay discarded (never inserted)');
      try {
        entry.dispose();
      } catch (_) {}
    }
    _overlayInserted = false;
  }

  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        focusNode: _focusNode,
        child: widget.child,
      ),
    );
  }
}
