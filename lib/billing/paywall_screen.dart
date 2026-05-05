import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme.dart';
import 'billing_providers.dart';
import 'gate_helper.dart';

/// Pro description / paywall screen that accepts a feature context.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key, required this.feature});

  final PaywallFeature feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureTitle = _featureTitle(feature);
    final featureDescription = _featureDescription(feature);
    final packageState = ref.watch(proPackageProvider);
    final billingState = ref.watch(billingProvider);
    final billingData = billingState.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final isBusy = billingData?.isBusy ?? billingState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              // Pro badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentOlive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.crown(),
                          size: 14,
                          color: AppColors.accentOlive,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pro',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentOlive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                featureTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                featureDescription,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.mutedInk,
                  height: 1.7,
                ),
              ),
              const Spacer(),
              // Pro features list
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Proで使える機能',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FeatureRow(
                      icon: PhosphorIcons.calendarBlank(),
                      text: 'タイムラインを無制限に保存',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FeatureRow(
                      icon: PhosphorIcons.cards(),
                      text: 'テンプレートの作成・保存・適用',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _FeatureRow(icon: PhosphorIcons.image(), text: '共有用画像の生成'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              packageState.when(
                loading: () => const _PurchaseButton(
                  label: '商品情報を読み込み中',
                  isEnabled: false,
                  isLoading: true,
                ),
                error: (_, _) => const _UnavailablePackageNotice(
                  text: '商品情報を取得できませんでした。通信状態を確認して再試行してください。',
                ),
                data: (package) {
                  if (package == null) {
                    return const _UnavailablePackageNotice(
                      text: '現在購入できるPro商品が設定されていません。購入済みの場合は復元できます。',
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PackageSummary(package: package),
                      const SizedBox(height: AppSpacing.md),
                      _PurchaseButton(
                        label: isBusy ? '処理中' : 'Proにアップグレード',
                        isEnabled: !isBusy,
                        isLoading: isBusy,
                        onTap: () => ref
                            .read(billingProvider.notifier)
                            .purchaseProPackage(package.package),
                      ),
                    ],
                  );
                },
              ),
              if (billingData?.purchaseMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _PurchaseMessage(state: billingData!),
              ],
              const SizedBox(height: AppSpacing.md),
              Pressable(
                onTap: isBusy
                    ? null
                    : () =>
                          ref.read(billingProvider.notifier).restorePurchases(),
                scale: 0.98,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.softGray, width: 1),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIcons.arrowCounterClockwise(),
                        size: 18,
                        color: AppColors.mutedInk,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '購入を復元',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isBusy
                              ? AppColors.softGray
                              : AppColors.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  String _featureTitle(PaywallFeature feature) {
    switch (feature) {
      case PaywallFeature.templates:
        return 'テンプレートはPro機能です';
      case PaywallFeature.timelineCount:
        return 'タイムラインの保存上限に達しました';
      case PaywallFeature.imageExport:
        return '画像での共有はPro機能です';
    }
  }

  String _featureDescription(PaywallFeature feature) {
    switch (feature) {
      case PaywallFeature.templates:
        return 'テンプレートを使うと、よく使うタイムラインを保存して何度でも適用できます。Proにアップグレードして、作業の効率化を図りましょう。';
      case PaywallFeature.timelineCount:
        return 'Freeプランではタイムラインを2つまで保存できます。Proにアップグレードすると、無制限に保存・切り替えが可能になります。';
      case PaywallFeature.imageExport:
        return 'タイムラインを美しい画像として生成し、SNSやメッセージで共有できます。Proにアップグレードして、シェアの質を高めましょう。';
    }
  }
}

class _PackageSummary extends StatelessWidget {
  const _PackageSummary({required this.package});

  final ProPackageState package;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentOlive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.accentOlive.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.sealCheck(),
            size: 22,
            color: AppColors.accentOlive,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.productTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${package.displayPrice} / ${package.periodLabel}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedInk,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseButton extends StatelessWidget {
  const _PurchaseButton({
    required this.label,
    required this.isEnabled,
    this.isLoading = false,
    this.onTap,
  });

  final String label;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: isEnabled ? onTap : null,
      scale: 0.98,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isEnabled ? AppColors.darkSurface : AppColors.softGray,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: isEnabled ? AppShadows.card : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              Icon(PhosphorIcons.circleNotch(), size: 18, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
            ] else ...[
              Icon(PhosphorIcons.shoppingBag(), size: 18, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailablePackageNotice extends StatelessWidget {
  const _UnavailablePackageNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.softGray, width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.mutedInk,
          height: 1.5,
        ),
      ),
    );
  }
}

class _PurchaseMessage extends StatelessWidget {
  const _PurchaseMessage({required this.state});

  final BillingState state;

  @override
  Widget build(BuildContext context) {
    final isFailure = state.purchaseStatus == BillingPurchaseStatus.failed;
    return Text(
      state.purchaseMessage!,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: isFailure ? Colors.red.shade700 : AppColors.mutedInk,
        height: 1.5,
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accentOlive),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.ink,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
