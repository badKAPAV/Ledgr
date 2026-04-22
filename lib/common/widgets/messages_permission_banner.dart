import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

class MessagesPermissionBanner extends StatefulWidget {
  final VoidCallback? onPermissionGranted;
  final bool debugForceShow;
  final bool isSmall;

  const MessagesPermissionBanner({
    super.key,
    this.onPermissionGranted,
    this.debugForceShow = false,
    this.isSmall = false,
  });

  static const _platform = MethodChannel('com.kapav.wallzy/sms');

  static Future<bool> checkPermission() async {
    try {
      return await _platform.invokeMethod('isNotificationListenerEnabled');
    } catch (e) {
      debugPrint("Error checking notification listener status static: $e");
      return false;
    }
  }

  @override
  State<MessagesPermissionBanner> createState() =>
      _MessagesPermissionBannerState();
}

class _MessagesPermissionBannerState extends State<MessagesPermissionBanner>
    with WidgetsBindingObserver {
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    try {
      final bool realStatus = await MessagesPermissionBanner.checkPermission();
      final bool effectiveStatus = widget.debugForceShow ? false : realStatus;

      if (mounted) {
        setState(() {
          _hasPermission = effectiveStatus;
        });
        if (effectiveStatus) {
          widget.onPermissionGranted?.call();
        }
      }
    } catch (e) {
      debugPrint("Error checking status: $e");
    }
  }

  Future<void> _openListenerSettings() async {
    try {
      Navigator.of(context).pop();
      await MessagesPermissionBanner._platform.invokeMethod(
        'openNotificationListenerSettings',
      );
    } catch (e) {
      debugPrint("Error opening settings: $e");
    }
  }

  Future<void> _openAppInfo() async {
    try {
      Navigator.of(context).pop();
      await MessagesPermissionBanner._platform.invokeMethod('openAppInfo');
    } catch (e) {
      debugPrint("Error opening app info: $e");
    }
  }

  void _showInstructionDialog() {
    showDialog(
      context: context,
      builder: (context) => _PremiumInstructionDialog(
        onOpenSettings: _openListenerSettings,
        onOpenAppInfo: _openAppInfo,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPermission) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- Small Version (e.g. for Settings Page) ---
    if (widget.isSmall) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showInstructionDialog,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 16.0,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "AutoLog is disabled",
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight02,
                    color: theme.colorScheme.primary,
                    strokeWidth: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // --- Main Premium Banner (e.g. Home Screen) ---
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        // A subtle gradient to make it stand out from standard cards
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showInstructionDialog,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Attention Grabbing Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMagicWand01,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Automate tracking transactions",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      softWrap: true,
                      maxLines: 2,
                      "Sync transactions directly from SMS alerts",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight02,
                  color: theme.colorScheme.primary,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      )
    );
  }
}

// --- REDESIGNED DIALOG ---

class _PremiumInstructionDialog extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAppInfo;

  const _PremiumInstructionDialog({
    required this.onOpenSettings,
    required this.onOpenAppInfo,
  });

  @override
  State<_PremiumInstructionDialog> createState() =>
      _PremiumInstructionDialogState();
}

class _PremiumInstructionDialogState extends State<_PremiumInstructionDialog> {
  bool _showTroubleshooting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Trust Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSecurityCheck,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "ENABLE AUTO-LOG",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ledgr uses secure on-device processing to read transaction notifications. No personal data ever leaves your phone.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // 2. Simple Steps
            _StepRow(
              number: "1",
              text: "Tap the button below to open Settings.",
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _StepRow(
              number: "2",
              text: "Find 'Ledgr' and toggle the switch ON.",
              colorScheme: colorScheme,
            ),

            // 3. Troubleshooting Expander
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showTroubleshooting = !_showTroubleshooting;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _showTroubleshooting
                      ? colorScheme.errorContainer.withValues(alpha: 0.2)
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                  borderRadius: BorderRadius.circular(12),
                  border: _showTroubleshooting
                      ? Border.all(
                          color: colorScheme.error.withValues(alpha: 0.2),
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _showTroubleshooting
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.help_outline_rounded,
                          size: 16,
                          color: _showTroubleshooting
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Switch greyed out? / Can't enable?",
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _showTroubleshooting
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_showTroubleshooting) ...[
                      const SizedBox(height: 12),
                      Text(
                        "Android restricts this setting for some downloaded apps. To unlock it:",
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      _SubStep(text: "1. Tap 'Open App Info' below"),
                      _SubStep(
                        text:
                            "2. Tap the 3 dots (top-right) → 'Allow Restricted Settings'",
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: widget.onOpenAppInfo,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(
                              color: colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text("Open App Info"),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 4. Main Action
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: widget.onOpenSettings,
                style: FilledButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  "Go to Settings",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      )
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  final ColorScheme colorScheme;

  const _StepRow({
    required this.number,
    required this.text,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ]
    );
  }
}

class _SubStep extends StatelessWidget {
  final String text;
  const _SubStep({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      )
    );
  }
}
