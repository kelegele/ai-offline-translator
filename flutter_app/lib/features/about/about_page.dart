import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/app_colors.dart';
import '../../design/app_spacing.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '关于',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),
              // App icon
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'AI离线翻译',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'v0.0.3',
                style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Description card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '一款开源的离线翻译工具',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '基于大语言模型 Hy-MT1.5 和 llama.cpp 推理引擎，在手机端本地完成翻译，无需网络。',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.steel,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Contact card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '联系方式',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    _ContactRow(
                      icon: Icons.chat_bubble_outline,
                      label: '微信',
                      value: 'Kelegele',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ContactRow(
                      icon: Icons.code,
                      label: 'GitHub',
                      value: 'kelegele/ai-offline-translator',
                      copyable: false,
                      onTap: () => launchUrl(Uri.parse('https://github.com/kelegele/ai-offline-translator')),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Community card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.groups_outlined, size: 20, color: AppColors.brandBlue),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '一起学 AI',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '如果你对 AI 感兴趣，想探讨技术、交流学习心得，欢迎加微信一起成长。',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.steel,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: 'Kelegele'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制：Kelegele'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            margin: EdgeInsets.only(bottom: 80, left: 40, right: 40),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.brandBlue),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '微信号：Kelegele',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandBlue,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.copy, size: 16, color: AppColors.muted),
                          ],
                        ),
                      ),
                    ),
                    // QR code placeholder (replace when ready)
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2, size: 48, color: AppColors.muted),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '微信二维码待补充',
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Footer
              Text(
                '开源许可 · MIT License',
                style: textTheme.labelSmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyable;
  final VoidCallback? onTap;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已复制：Kelegele'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 40, right: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final effectiveOnTap = onTap ?? (copyable ? () => _copy(context) : null);
    return GestureDetector(
      onTap: effectiveOnTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.steel),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(
                color: (copyable || onTap != null) ? AppColors.brandBlue : AppColors.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (copyable && onTap == null)
            Icon(Icons.copy, size: 14, color: AppColors.muted),
          if (onTap != null)
            Icon(Icons.open_in_new, size: 14, color: AppColors.muted),
        ],
      ),
    );
  }
}
