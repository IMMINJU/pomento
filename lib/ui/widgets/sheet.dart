import 'package:flutter/material.dart';

import '../theme.dart';
import 'artwork_tone.dart';
import 'common.dart';
import 'paper.dart';

/// 아래에서 올라오는 시트의 종이 껍데기.
///
/// 위 모서리만 둥글다. 색면은 끈다. 시트가 화면의 일부만 덮으므로 색면을
/// 켜두면 그 안에서만 색이 돌아 뒤의 종이와 어긋난다.
class PaperSheet extends StatelessWidget {
  const PaperSheet({super.key, required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      child: SizedBox(
        height: height,
        child: PaperBackground(
          field: false,
          child: SafeArea(top: false, child: child),
        ),
      ),
    );
  }
}

/// 목록형 시트를 띄운다. 손잡이와 위아래 여백이 이미 들어 있다.
Future<T?> showPaperSheet<T>({
  required BuildContext context,
  required List<Widget> children,
  String? title,
  double? height,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: height != null,
    builder: (_) => PaperSheet(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const SheetHandle(),
          if (title != null) ...[
            const SizedBox(height: 18),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: Text(title, style: AppText.title),
            ),
          ],
          const SizedBox(height: 10),
          ...children,
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

/// 시트 안의 행 하나.
///
/// Material의 ListTile을 쓰지 않는다. 좌우 여백과 글자 크기가 이 화면과
/// 안 맞고, 아이콘 자리를 40px로 잡아버려서 목록 행과 어긋난다.
class SheetTile extends StatelessWidget {
  const SheetTile({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.leading,
    this.trailing,
    this.selected = false,
    this.danger = false,
    this.onTap,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;

  /// 지금 걸려 있는 것. 강조색으로 쓴다.
  final bool selected;

  /// 되돌리기 어려운 것. 지우기가 여기 온다.
  final bool danger;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = CoverScope.of(context);
    final color = danger
        ? AppColors.warn
        : (selected ? tone.accentInk : AppColors.ink1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.gutter, vertical: 16),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 14),
              ] else if (icon != null) ...[
                SizedBox(
                  width: 22,
                  child: Icon(icon, size: 20,
                      color: danger ? AppColors.warn : AppColors.ink2),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(
                        color: color,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(description!, style: AppText.sub),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 글자 하나를 받는 대화상자. 재생목록 이름 같은 자리.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String hint,
}) {
  final controller = TextEditingController();
  final tone = CoverScope.of(context);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        child: PaperBackground(
          field: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter, 26, AppSpace.gutter, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppText.title),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.paperLo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: AppText.body,
                    cursorColor: tone.accent,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: AppText.body.copyWith(color: AppColors.hair),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (v) => Navigator.pop(dialogContext, v),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text('취소',
                          style:
                              AppText.body.copyWith(color: AppColors.ink3)),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, controller.text),
                      child: Text('확인',
                          style: AppText.body.copyWith(
                              color: AppColors.ink1,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
