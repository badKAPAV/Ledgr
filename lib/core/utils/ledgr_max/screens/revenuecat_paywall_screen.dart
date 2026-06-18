import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:wallzy/core/utils/ledgr_max/entitlements/entitlements_provider.dart';
import 'package:wallzy/core/utils/ledgr_max/provider/revenuecat_provider.dart';
import 'package:wallzy/common/snackbar/ledgr_snackbar.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({Key? key}) : super(key: key);

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isProcessing = false;

  // Trial Eligibility States
  bool _isEligibleForTrial = false;
  bool _isLoadingEligibility = true;

  // Plan toggle: 0 = Monthly, 1 = Lifetime
  int _selectedPlan = 1;

  @override
  void initState() {
    super.initState();
    _checkTrialEligibility();
  }

  // ── All original logic methods preserved exactly ──────────────────────────

  Future<void> _checkTrialEligibility() async {
    try {
      final offerings = await Purchases.getOfferings();
      final monthlyPackage = offerings.current?.monthly;

      if (monthlyPackage != null) {
        final eligibilityData =
            await Purchases.checkTrialOrIntroductoryPriceEligibility([
              monthlyPackage.storeProduct.identifier,
            ]);

        final eligibility =
            eligibilityData[monthlyPackage.storeProduct.identifier];

        if (mounted) {
          setState(() {
            _isEligibleForTrial =
                eligibility?.status ==
                IntroEligibilityStatus.introEligibilityStatusEligible;
            _isLoadingEligibility = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingEligibility = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingEligibility = false);
    }
  }

  Future<void> _handlePurchase(Package package) async {
    setState(() => _isProcessing = true);

    final rcProvider = context.read<RevenueCatProvider>();
    final success = await rcProvider.purchasePackage(package);

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        LedgrSnackbar.show(
          context: context,
          content: const Text("Welcome to the max experience"),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isProcessing = true);

    final rcProvider = context.read<RevenueCatProvider>();
    final success = await rcProvider.restorePurchases();

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        LedgrSnackbar.show(
          context: context,
          content: const Text("Purchases Restored!"),
        );
        Navigator.of(context).pop();
      } else {
        LedgrSnackbar.show(
          context: context,
          content: const Text("No previous purchases found"),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final rcProvider = context.watch<RevenueCatProvider>();
    final entProvider = context.watch<EntitlementsProvider>();

    final free = entProvider.freeLimits;
    final pro = entProvider.proLimits;

    final monthlyPackage = rcProvider.offerings?.current?.monthly;
    final lifetimePackage = rcProvider.offerings?.current?.lifetime;

    final monthlyPrice = monthlyPackage?.storeProduct.priceString ?? "₹49.00";
    final lifetimePrice =
        lifetimePackage?.storeProduct.priceString ?? "₹999.00";

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Hero / Header ───────────────────────────────────
                        _buildHeroSection(colorScheme, theme),

                        // ── Plan toggle ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildPlanToggle(colorScheme),
                        ),

                        const SizedBox(height: 16),

                        // ── CTA card (switches based on toggle) ─────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _selectedPlan == 1
                              ? _buildLifetimeCta(
                                  colorScheme,
                                  lifetimePackage,
                                  lifetimePrice,
                                  theme,
                                )
                              : _buildMonthlyCta(
                                  colorScheme,
                                  monthlyPackage,
                                  monthlyPrice,
                                  theme,
                                ),
                        ),

                        // ── Secondary option hint ────────────────────────────
                        if (_selectedPlan == 1 && monthlyPackage != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                            child: _buildSecondaryMonthlyHint(
                              colorScheme,
                              monthlyPackage,
                              monthlyPrice,
                            ),
                          ),
                        if (_selectedPlan == 0 && lifetimePackage != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                            child: _buildSecondaryLifetimeHint(
                              colorScheme,
                              lifetimePackage,
                              lifetimePrice,
                            ),
                          ),

                        const SizedBox(height: 28),

                        // ── Feature list ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildFeatureList(
                            colorScheme,
                            theme,
                            free,
                            pro,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Social proof strip ───────────────────────────────
                        _buildSocialProof(colorScheme),

                        // ── Footer ───────────────────────────────────────────
                        _buildFooter(colorScheme),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Section builders ──────────────────────────────────────────────────────

  Widget _buildHeroSection(ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Icon + Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'unlock',
                style: GoogleFonts.kodeMono(
                  fontSize: 40,
                  fontWeight: .w500,
                  letterSpacing: -1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 0),
              SvgPicture.asset(
                'assets/vectors/ledgr_max_logo.svg',
                width: 120,
                color: theme.colorScheme.onSurface,
              ),
            ],
          ),

          const SizedBox(height: 0),

          Text(
            "Your money, truly mastered.",
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanToggle(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          _buildToggleTab(
            colorScheme,
            label: "Monthly",
            trailingBadge: _isLoadingEligibility
                ? null
                : _isEligibleForTrial
                ? "30-day trial"
                : null,
            selected: _selectedPlan == 0,
            onTap: () => setState(() => _selectedPlan = 0),
          ),
          _buildToggleTab(
            colorScheme,
            label: "Lifetime",
            trailingBadge: "best value",
            selected: _selectedPlan == 1,
            onTap: () => setState(() => _selectedPlan = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTab(
    ColorScheme colorScheme, {
    required String label,
    String? trailingBadge,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected
                ? Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              if (trailingBadge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trailingBadge,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLifetimeCta(
    ColorScheme colorScheme,
    Package? package,
    String price,
    ThemeData theme,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          borderRadius: .circular(20),
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: package != null ? () => _handlePurchase(package) : null,
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD700), // Gold
                    Color(0xFFFFA500), // Orange
                    Color(0xFFFF8C00), // Dark Orange
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8C00).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 22,
                  horizontal: 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ONE-TIME",
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Lifetime Access",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Pay once, yours forever.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              // currency symbol
                              TextSpan(
                                text: price.isNotEmpty ? price[0] : '',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black.withValues(alpha: 0.4),
                                  letterSpacing: 3,
                                ),
                              ),
                              // actual price value
                              TextSpan(
                                text: price.length > 1
                                    ? price.substring(1)
                                    : '',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "one-time",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // "Best value" badge
        Positioned(
          top: -10,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.tertiary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "BEST VALUE",
              style: TextStyle(
                color: colorScheme.onTertiary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyCta(
    ColorScheme colorScheme,
    Package? package,
    String price,
    ThemeData theme,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: package != null ? () => _handlePurchase(package) : null,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF6366F1), // Indigo
                Color(0xFF8B5CF6), // Violet
                Color(0xFFD946EF), // Fuchsia
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MONTHLY",
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isEligibleForTrial ? "Free for 30 days" : "Monthly Plan",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isEligibleForTrial
                          ? "Then $price/month, cancel anytime."
                          : "Cancel anytime.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                _isLoadingEligibility
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _isEligibleForTrial
                              ? const Text(
                                  "FREE",
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                )
                              : Text.rich(
                                  TextSpan(
                                    children: [
                                      // currency symbol
                                      TextSpan(
                                        text: price.isNotEmpty ? price[0] : '',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                              letterSpacing: 3,
                                            ),
                                      ),
                                      // actual price value
                                      TextSpan(
                                        text: price.length > 1
                                            ? price.substring(1)
                                            : '',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontSize: 34,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: -1,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                          Text(
                            _isEligibleForTrial ? "then $price/mo" : "/ month",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryMonthlyHint(
    ColorScheme colorScheme,
    Package package,
    String price,
  ) {
    return GestureDetector(
      onTap: () => _handlePurchase(package),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLoadingEligibility
                  ? "Or go monthly"
                  : _isEligibleForTrial
                  ? "Or start a 30-day free trial"
                  : "Or pay $price / month",
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryLifetimeHint(
    ColorScheme colorScheme,
    Package package,
    String price,
  ) {
    return GestureDetector(
      onTap: () => _handlePurchase(package),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Or get lifetime access for $price",
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureList(
    ColorScheme colorScheme,
    ThemeData theme,
    dynamic free,
    dynamic pro,
  ) {
    final features = [
      _FeatureData(
        icon: Icons.people_outline_rounded,
        iconColor: colorScheme.primary,
        iconBg: colorScheme.primary.withValues(alpha: 0.10),
        name: "Accounts & Wallets",
        description: "Track all your accounts in one place",
        freeVal: free.userAccountsQuantity.toString(),
        proVal: pro.userAccountsQuantity == 99
            ? "∞"
            : pro.userAccountsQuantity.toString(),
        isBool: false,
        freeEnabled: true,
        proEnabled: true,
      ),
      _FeatureData(
        icon: Icons.history_rounded,
        iconColor: Colors.teal,
        iconBg: Colors.teal.withValues(alpha: 0.10),
        name: "Transaction history",
        description: "Scroll back as far as you need",
        freeVal: "${free.transactionHistoryLimitMonths}mo",
        proVal: pro.transactionHistoryLimitMonths == 999
            ? "∞"
            : "${pro.transactionHistoryLimitMonths}mo",
        isBool: false,
        freeEnabled: true,
        proEnabled: true,
      ),
      _FeatureData(
        icon: Icons.category_outlined,
        iconColor: Colors.orange,
        iconBg: Colors.orange.withValues(alpha: 0.10),
        name: "Custom categories & budgets",
        description: "Organize your spending your way",
        freeVal: "",
        proVal: "",
        isBool: true,
        freeEnabled: free.customCategories,
        proEnabled: pro.customCategories,
      ),
      _FeatureData(
        icon: Icons.bolt_outlined,
        iconColor: colorScheme.primary,
        iconBg: colorScheme.primary.withValues(alpha: 0.10),
        name: "Quick save & autosave",
        description: "Capture expenses in seconds",
        freeVal: "",
        proVal: "",
        isBool: true,
        freeEnabled: free.quickSave,
        proEnabled: pro.quickSave,
      ),
      _FeatureData(
        icon: Icons.cloud_upload_outlined,
        iconColor: Colors.teal,
        iconBg: Colors.teal.withValues(alpha: 0.10),
        name: "Cloud backup & sync",
        description: "Your data, safe across devices",
        freeVal: "",
        proVal: "",
        isBool: true,
        freeEnabled: free.dataSyncToCloud,
        proEnabled: pro.dataSyncToCloud,
      ),
      _FeatureData(
        icon: Icons.download_outlined,
        iconColor: Colors.orange,
        iconBg: Colors.orange.withValues(alpha: 0.10),
        name: "CSV export",
        description: "Take your data anywhere",
        freeVal: "",
        proVal: "",
        isBool: true,
        freeEnabled: free.dataExport,
        proEnabled: pro.dataExport,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            "WHAT YOU UNLOCK",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),

        // Feature rows
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: features.asMap().entries.map((entry) {
                final i = entry.key;
                final f = entry.value;
                return _buildFeatureRow(
                  colorScheme,
                  f,
                  isLast: i == features.length - 1,
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 10),
        Center(
          child: Text(
            "And many other features...",
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(
    ColorScheme colorScheme,
    _FeatureData feature, {
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        child: Row(
          children: [
            // Icon
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: feature.iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(feature.icon, size: 16, color: feature.iconColor),
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    feature.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Free → Pro chips
            Row(
              children: [
                _buildChip(
                  colorScheme,
                  feature.isBool
                      ? (feature.freeEnabled ? "✓" : "𐄂")
                      : feature.freeVal,
                  isPro: false,
                  isEnabled: feature.freeEnabled,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 10,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ),
                _buildChip(
                  colorScheme,
                  feature.isBool
                      ? (feature.proEnabled ? "✓" : "—")
                      : feature.proVal,
                  isPro: true,
                  isEnabled: feature.proEnabled,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
    ColorScheme colorScheme,
    String label, {
    required bool isPro,
    required bool isEnabled,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isPro && isEnabled
            ? colorScheme.primary.withValues(alpha: 0.10)
            : colorScheme.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPro && isEnabled
              ? colorScheme.primary.withValues(alpha: 0.2)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isPro ? FontWeight.w600 : FontWeight.w400,
          color: isPro && isEnabled
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildSocialProof(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Avatar stack
          SizedBox(
            width: 52,
            height: 28,
            child: Stack(
              children: [
                _buildAvatar(
                  "RK",
                  colorScheme.primary,
                  colorScheme.onPrimary,
                  0,
                  colorScheme,
                ),
                _buildAvatar("SM", Colors.teal, Colors.black, 18, colorScheme),
                _buildAvatar(
                  "AP",
                  Colors.orange,
                  Colors.black,
                  36,
                  colorScheme,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                children: [
                  TextSpan(
                    text: "Thousands of people ",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const TextSpan(
                    text: "already track their finances with Ledgr Max.",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    String initials,
    Color bg,
    Color fg,
    double left,
    ColorScheme theme,
  ) {
    return Positioned(
      left: left,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: theme.surfaceContainer, width: 2),
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextButton(
            onPressed: _handleRestore,
            child: Text(
              "Restore Purchases",
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period.",
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {},
                child: Text(
                  "Terms",
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                "•",
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  "Privacy",
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Data model for feature rows ───────────────────────────────────────────────

class _FeatureData {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String name;
  final String description;
  final String freeVal;
  final String proVal;
  final bool isBool;
  final bool freeEnabled;
  final bool proEnabled;

  const _FeatureData({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.name,
    required this.description,
    required this.freeVal,
    required this.proVal,
    required this.isBool,
    required this.freeEnabled,
    required this.proEnabled,
  });
}
