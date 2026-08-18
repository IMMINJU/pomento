import 'package:flutter/material.dart';

import '../theme.dart';

/// 플레이어 탭 위에 쌓이는 화면의 머리.
///
/// Capriccio의 Effects와 Parametric EQ가 쓰는 모양이다. 왼쪽에 뒤로, 가운데
/// 제목, 오른쪽에 닫기. 닫기는 한 단계가 아니라 재생 화면까지 되돌린다.
/// EQ에서 나올 때 음향 화면을 거치지 않고 바로 곡으로 돌아가려는 것이다.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 28,
                  color: AppColors.t1),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 20),
          Text(title, style: AppText.display),
          if (subtitle != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small,
              ),
            ),
          ] else
            const Spacer(),
          ...actions,
          IconButton(
            icon: const Icon(Icons.close, size: 22, color: AppColors.t2),
            onPressed: () =>
                Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// 머리에 들어가는 글자 버튼.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 15, color: AppColors.t2),
      label: Text(label,
          style: const TextStyle(fontSize: 13, color: AppColors.t2)),
    );
  }
}
