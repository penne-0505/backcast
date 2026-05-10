import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_providers.dart';
import '../billing/billing_providers.dart';
import '../billing/gate_helper.dart';
import '../billing/paywall_screen.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isOpeningSubscriptionManagement = false;

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('アカウントを削除しますか？'),
        content: const Text(
          'Supabase上のアカウント情報と課金状態を削除します。ストアのサブスクリプション解約はGoogle PlayまたはApp Storeで別途行ってください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(authProvider.notifier).deleteAccount();
  }

  Future<void> _handlePlanTap(BuildContext context, bool isPro) async {
    if (!isPro) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const PaywallScreen(feature: PaywallFeature.timelineCount),
        ),
      );
      return;
    }

    if (_isOpeningSubscriptionManagement) return;
    setState(() => _isOpeningSubscriptionManagement = true);

    try {
      final url = await ref.read(subscriptionManagementUrlProvider.future);
      if (!context.mounted) return;
      if (url == null) {
        _showSubscriptionMessage(
          context,
          '購読管理画面を開けませんでした。購入を復元するか、Google Play / App Store のサブスクリプション管理を確認してください。',
        );
        return;
      }

      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showSubscriptionMessage(
          context,
          '購読管理画面を開けませんでした。Google Play / App Store のサブスクリプション管理を確認してください。',
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      _showSubscriptionMessage(context, '購読管理画面を開けませんでした。時間をおいて再試行してください。');
    } finally {
      if (mounted) {
        setState(() => _isOpeningSubscriptionManagement = false);
      }
    }
  }

  void _showSubscriptionMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final isPro = ref.watch(effectiveIsProProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          '設定',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeft(), color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: authAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accentOlive),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'エラーが発生しました:\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedInk),
              ),
            ),
          ),
          data: (authState) => ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            children: [
              _SectionHeader(title: 'アカウント'),
              const SizedBox(height: AppSpacing.md),
              if (authState.isAuthenticated) ...[
                _UserInfoCard(authState: authState),
                const SizedBox(height: AppSpacing.lg),
                _SignOutButton(
                  onTap: () => ref.read(authProvider.notifier).signOut(),
                ),
                const SizedBox(height: AppSpacing.md),
                _DeleteAccountButton(
                  onTap: () => _confirmDeleteAccount(context, ref),
                ),
              ] else ...[
                _SignInInfoText(),
                const SizedBox(height: AppSpacing.lg),
                _OAuthButton(
                  label: 'Google でログイン',
                  icon: PhosphorIcons.googleLogo(),
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                  borderColor: AppColors.softGray,
                  onTap: () =>
                      ref.read(authProvider.notifier).signInWithGoogle(),
                ),
                if (Platform.isIOS || Platform.isMacOS) ...[
                  const SizedBox(height: AppSpacing.md),
                  _OAuthButton(
                    label: 'Apple でログイン',
                    icon: PhosphorIcons.appleLogo(),
                    backgroundColor: AppColors.darkSurface,
                    foregroundColor: Colors.white,
                    borderColor: AppColors.darkSurface,
                    onTap: () =>
                        ref.read(authProvider.notifier).signInWithApple(),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.xxl),
              _SectionHeader(title: 'サブスクリプション'),
              const SizedBox(height: AppSpacing.md),
              _ProStatusCard(
                isPro: isPro,
                isBusy: _isOpeningSubscriptionManagement,
                onTap: () => _handlePlanTap(context, isPro),
              ),
              const SizedBox(height: AppSpacing.md),
              _RestorePurchasesButton(
                onTap: () =>
                    ref.read(billingProvider.notifier).restorePurchases(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.softGray, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.trash(), size: 20, color: AppColors.mutedInk),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'アカウントを削除',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.label.copyWith(
        color: AppColors.mutedInk,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SignInInfoText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIcons.info(), size: 18, color: AppColors.accentOlive),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Pro機能の購入やライセンスのクロスプラットフォーム紐付けにはログインが必要です。データの同期には使用しません。',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.mutedInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({required this.authState});

  final AppAuthState authState;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.selectionFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.user(),
              size: 20,
              color: AppColors.accentOlive,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ログイン中',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.accentOlive,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  authState.displayIdentifier ?? '不明なユーザー',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (authState.userId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'ID: ${authState.userId}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedInk,
                        fontFamily: 'monospace',
                      ),
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

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: foregroundColor),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
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
            Icon(PhosphorIcons.signOut(), size: 20, color: AppColors.mutedInk),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'ログアウト',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProStatusCard extends StatelessWidget {
  const _ProStatusCard({
    required this.isPro,
    required this.isBusy,
    required this.onTap,
  });

  final bool isPro;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isPro ? AppColors.selectionFill : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isPro
                ? AppColors.accentOlive.withValues(alpha: 0.3)
                : AppColors.softGray,
            width: 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPro
                    ? AppColors.accentOlive.withValues(alpha: 0.1)
                    : AppColors.selectionFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPro ? PhosphorIcons.crown() : PhosphorIcons.crownSimple(),
                size: 20,
                color: AppColors.accentOlive,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPro ? 'Proプラン利用中' : 'Freeプラン',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPro
                        ? (isBusy ? '購読管理を開いています' : 'ストアで購読を管理')
                        : 'タップしてPro機能を確認',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isBusy ? PhosphorIcons.circleNotch() : PhosphorIcons.caretRight(),
              size: 16,
              color: AppColors.mutedInk,
            ),
          ],
        ),
      ),
    );
  }
}

class _RestorePurchasesButton extends StatelessWidget {
  const _RestorePurchasesButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
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
              size: 20,
              color: AppColors.mutedInk,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '購入を復元',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
