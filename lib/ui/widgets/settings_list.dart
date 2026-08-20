import 'package:flutter/material.dart';

import '../theme.dart';
import 'paper.dart';

/// 설정 화면의 목록 문법. 추가 효과 탭도 같은 것을 쓴다.
///
/// 행 사이에 선을 긋지 않는다. 위아래 여백 18과 좌우 26이 행을 가른다.
/// 선을 그으면 화면이 칸으로 잘려 보인다.
///
/// 섹션 라벨도 강조색을 쓰지 않는다. 색은 재생 상태를 말하는 데 이미
/// 쓰고 있어서, 목차 노릇까지 색으로 시키면 둘이 섞인다. 자간과 크기로
/// 구분한다.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            28,
            AppSpace.gutter,
            10,
          ),
          child: Text(title, style: AppText.label),
        ),
        ...children,
      ],
    );
  }
}

/// 행 하나의 뼈대. 제목과 설명은 왼쪽, 오른쪽에 무엇이든 온다.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.trailing,
    this.description,
    this.onTap,
  });

  final String title;
  final String? description;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.gutter,
        vertical: 18,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description!, style: AppText.sub),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: body),
    );
  }
}

/// 읽기만 하는 행. 누를 수 없으니 화살표도 밑줄도 없다.
class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    required this.title,
    required this.value,
    this.description,
  });

  final String title;
  final String value;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return _Row(
      title: title,
      description: description,
      trailing: Text(
        value,
        style: AppText.num.copyWith(fontSize: 14, color: AppColors.ink3),
      ),
    );
  }
}

/// 값 하나를 고르는 행. 누르면 목록 대화상자가 뜬다.
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
    return _Row(
      title: title,
      description: description,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppText.num.copyWith(color: AppColors.ink3)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.hair),
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
    this.value,
  });

  final String title;
  final String? description;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Row(
      title: title,
      description: description,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Text(value!, style: AppText.num.copyWith(color: AppColors.ink3)),
            const SizedBox(width: 6),
          ],
          const Icon(Icons.chevron_right, size: 20, color: AppColors.hair),
        ],
      ),
    );
  }
}

/// 켜고 끄는 행.
///
/// Material의 Switch를 쓰지 않는다. 색과 크기가 이 화면과 안 맞고,
/// 켜진 상태를 강조색으로 칠해버려서 "색이 있으면 재생 중"이라는 규칙을
/// 깬다. 켜짐은 잉크로 채운다.
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
    return _Row(
      title: title,
      description: description,
      onTap: () => onChanged(!value),
      trailing: _InkSwitch(value: value),
    );
  }
}

class _InkSwitch extends StatelessWidget {
  const _InkSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 46,
      height: 28,
      decoration: BoxDecoration(
        color: value ? AppColors.ink1 : AppColors.paperLo,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(3),
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.paperHi,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x33232620),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 값을 고르는 대화상자.
///
/// 종이 한 장이다. 고른 것만 강조색으로 쓰고 체크 표시를 따로 두지 않는다.
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
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        child: PaperBackground(
          field: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 26, 0, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.gutter,
                  ),
                  child: Text(title, style: AppText.title),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final c in choices)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(dialogContext, c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.gutter,
                                  vertical: 15,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  label(c),
                                  style: AppText.body.copyWith(
                                    fontWeight: c == selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: c == selected
                                        ? AppColors.accent
                                        : AppColors.ink1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        '취소',
                        style: AppText.body.copyWith(color: AppColors.ink3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
