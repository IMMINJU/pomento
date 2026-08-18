import 'package:flutter/material.dart';

import '../theme.dart';

/// 재생 화면 위에 쌓이는 화면의 머리.
///
/// 왼쪽에 뒤로, 제목, 오른쪽에 닫기. 닫기는 한 단계가 아니라 재생 화면까지
/// 되돌린다. EQ에서 나올 때 음향 화면을 거치지 않고 바로 곡으로 돌아가려는
/// 것이다.
///
/// 높이가 78이고 내용이 아래에 붙는다. 제목이 34px이라 위쪽에 여백이 있어야
/// 글자가 화면 가장자리에 붙지 않는다.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.showClose = true,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final bool showClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Padding(
        padding: const EdgeInsets.only(right: 10, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showBack)
              SizedBox(
                width: AppSpace.tap,
                height: AppSpace.tap,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.chevron_left,
                    size: 26,
                    color: AppColors.ink1,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              )
            else
              const SizedBox(width: AppSpace.gutter),
            // 제목과 부제를 한 덩어리로 묶어 남는 폭을 통째로 받는다.
            // 둘을 형제로 두고 각각 Flexible/Expanded를 주면 flex가 같아서
            // 폭을 반씩 나눠 가진다. 그러면 제목부터 잘린다
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 폭이 모자라면 부제부터 줄어야 한다
                  Flexible(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title,
                      ),
                    ),
                  ),
                  if (subtitle != null)
                    Flexible(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 9),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sub,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ...actions,
            if (showClose)
              SizedBox(
                width: AppSpace.tap,
                height: AppSpace.tap,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.close,
                    size: 22,
                    color: AppColors.ink2,
                  ),
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 머리에 들어가는 글자 버튼. `원래대로` 같은 자리.
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.paperLo,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: AppColors.ink2),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: AppText.body.copyWith(
                    fontSize: 13,
                    color: AppColors.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
