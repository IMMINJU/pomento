import 'package:flutter/material.dart';

import '../theme.dart';

/// Capriccio 설정 화면의 목록 문법.
///
/// 섹션 라벨은 accent에 밑줄, 행은 굵은 제목과 회색 설명, 오른쪽에 accent
/// 값과 꺾쇠. 값을 누르면 목록 대화상자가 뜬다. 슬라이더나 알약을 쓰지
/// 않으므로 항목이 늘어도 화면이 흐트러지지 않는다.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: AppColors.accent,
        ),
        ...children,
      ],
    );
  }
}

/// 값 하나를 고르는 행.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
    this.description,
  });

  final String title;
  final String value;
  final String? description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.t1,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(description!, style: AppText.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
                fontFeatures: tabularFigures,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// 켜고 끄는 행.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.t1,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description!, style: AppText.caption),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

/// 다른 화면으로 넘어가는 행.
class SettingsLinkRow extends StatelessWidget {
  const SettingsLinkRow({
    super.key,
    required this.title,
    required this.onTap,
    this.description,
  });

  final String title;
  final String? description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.t1,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(description!, style: AppText.caption),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

/// 값을 고르는 대화상자.
///
/// 둥근 카드에 제목과 목록, 고른 것은 accent에 체크, 오른쪽 아래에 취소.
Future<T?> showChoiceDialog<T>({
  required BuildContext context,
  required String title,
  required List<T> choices,
  required T selected,
  required String Function(T) label,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: const Color(0xFF25252D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Text(title, style: AppText.display),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in choices)
                      InkWell(
                        onTap: () => Navigator.pop(dialogContext, c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label(c),
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: c == selected
                                        ? AppColors.accent
                                        : AppColors.t1,
                                    fontFeatures: tabularFigures,
                                  ),
                                ),
                              ),
                              if (c == selected)
                                const Icon(Icons.check,
                                    size: 20, color: AppColors.accent),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소',
                    style: TextStyle(fontSize: 16, color: AppColors.accent)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
