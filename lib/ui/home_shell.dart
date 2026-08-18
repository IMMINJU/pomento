import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../providers.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/mini_player.dart';

/// 지금 보고 있는 탭. 미니 플레이어를 눌러 플레이어로 건너뛰는 데 쓴다.
final shellTabProvider = StateProvider<int>((ref) => 0);

/// 플레이어 탭에 쌓인 화면 수. 첫 화면만 있으면 1이다.
///
/// 연습이나 음향 화면을 열면 재생 화면이 가려진다. 그때는 다른 탭에 있을
/// 때처럼 미니 플레이어를 띄워야 한다. Capriccio가 EQ를 만지는 동안에도
/// 곡을 넘길 수 있는 것이 이 구조 덕분이다.
final playerTabDepthProvider = StateProvider<int>((ref) => 1);

/// 탭바 높이(시스템 여백 제외).
const double kTabBarHeight = 58;

/// 미니 플레이어 높이. 화면 폭을 다 쓰므로 바깥 여백이 없다.
const double kMiniPlayerHeight = 68;

/// 탭바와 미니 플레이어가 가리는 만큼 목록 아래에 둘 여백.
///
/// 탭바가 유리라서 뒤로 내용이 지나가야 한다. 그래서 Scaffold가 자리를
/// 비워주지 않고, 화면마다 직접 여백을 잡는다.
double shellBottomInset(BuildContext context, WidgetRef ref) {
  return kTabBarHeight +
      MediaQuery.of(context).padding.bottom +
      (ref.watch(miniPlayerVisibleProvider) ? kMiniPlayerHeight : 0);
}

/// 미니 플레이어를 띄울지.
///
/// 재생 화면 자체를 보고 있을 때만 뺀다. 같은 내용을 두 번 그릴 이유가 없다.
final miniPlayerVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(nowPlayingExistsProvider)) return false;
  final onPlayerRoot = ref.watch(shellTabProvider) == 0 &&
      ref.watch(playerTabDepthProvider) <= 1;
  return !onPlayerRoot;
});

class _TabSpec {
  const _TabSpec(this.icon, this.activeIcon, this.label, this.build);

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final WidgetBuilder build;
}

/// 하단 탭 셸.
///
/// 플레이어를 화면 위에 쌓지 않고 탭 하나로 상주시킨다. 배속과 음향을 만지러
/// 갔다가 목록으로 돌아오는 일이 잦은 앱이라, 열고 닫는 동작이 끼면 그때마다
/// 재생 화면이 사라진다.
///
/// 탭마다 Navigator를 따로 둔다. 폴더나 플레이리스트로 들어가도 탭바와 미니
/// 플레이어가 남아 있어야 한다.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _tabs = <_TabSpec>[
    _TabSpec(
      Icons.play_circle_outline,
      Icons.play_circle_filled,
      '플레이어',
      _buildPlayer,
    ),
    _TabSpec(
      Icons.library_music_outlined,
      Icons.library_music,
      '라이브러리',
      _buildLibrary,
    ),
    _TabSpec(
      Icons.search,
      Icons.search,
      '검색',
      _buildSearch,
    ),
    _TabSpec(
      Icons.settings_outlined,
      Icons.settings,
      '설정',
      _buildSettings,
    ),
  ];

  static Widget _buildPlayer(BuildContext _) => const PlayerScreen();
  static Widget _buildLibrary(BuildContext _) => const LibraryScreen();
  static Widget _buildSearch(BuildContext _) => const SearchScreen();
  static Widget _buildSettings(BuildContext _) => const SettingsScreen();

  late final List<GlobalKey<NavigatorState>> _navKeys =
      List.generate(_tabs.length, (_) => GlobalKey<NavigatorState>());

  late final _playerStack = _StackDepthObserver((depth) {
    if (mounted) ref.read(playerTabDepthProvider.notifier).state = depth;
  });

  @override
  void initState() {
    super.initState();
    // 저장된 값은 조금 늦게 올라온다. 첫 프레임 뒤에 한 번 맞춘다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WakelockPlus.toggle(enable: ref.read(settingsProvider).keepScreenOn);
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  void _select(int i) {
    final current = ref.read(shellTabProvider);
    // 이미 보고 있는 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
    if (i == current) {
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    ref.read(shellTabProvider.notifier).state = i;
  }

  @override
  Widget build(BuildContext context) {
    // 설정이 바뀔 때만 시스템에 알린다. 매 프레임 부르면 안 된다.
    ref.listen<bool>(
      settingsProvider.select((s) => s.keepScreenOn),
      (_, on) => WakelockPlus.toggle(enable: on),
    );

    final index = ref.watch(shellTabProvider);
    final showMini = ref.watch(miniPlayerVisibleProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 탭 안에 쌓인 화면부터 벗긴다. 그다음 플레이어 탭으로 돌아가고,
        // 거기서 또 누르면 앱을 나간다. 마지막 단계가 없으면 뒤로 가기로
        // 앱을 못 닫는다.
        final nav = _navKeys[index].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (index != 0) {
          ref.read(shellTabProvider.notifier).state = 0;
        } else if (Platform.isAndroid) {
          // 안드로이드는 첫 화면에서 한 번 더 누르면 앱을 나가는 것이
          // 관례다. iOS에는 뒤로 가기 버튼이 없고, 앱이 스스로 종료하는
          // 것을 애플이 막는다. 그쪽에서는 아무것도 하지 않는다.
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        // 탭바가 유리라서 뒤로 내용이 지나가야 한다. 화면을 잘라내면 안 된다.
        extendBody: true,
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Navigator(
                key: _navKeys[i],
                observers: i == 0 ? [_playerStack] : const [],
                onGenerateRoute: (settings) => MaterialPageRoute(
                  settings: settings,
                  builder: _tabs[i].build,
                ),
              ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 재생 화면을 보고 있을 때만 뺀다. 연습이나 음향 화면이 위에
            // 쌓여 있으면 여기서 곡을 넘길 수 있어야 한다.
            if (showMini)
              MiniPlayer(
                onTap: () {
                  _navKeys[0].currentState?.popUntil((r) => r.isFirst);
                  ref.read(shellTabProvider.notifier).state = 0;
                },
              ),
            _TabBar(index: index, tabs: _tabs, onSelect: _select),
          ],
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.index,
    required this.tabs,
    required this.onSelect,
  });

  final int index;
  final List<_TabSpec> tabs;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppBlur.sheet, sigmaY: AppBlur.sheet),
        child: Container(
          padding: EdgeInsets.only(bottom: bottom, top: 6),
          decoration: const BoxDecoration(
            color: Color(0xB30B0B0F),
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _TabItem(
                    spec: tabs[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.t3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? spec.activeIcon : spec.icon, size: 24,
                color: color),
            const SizedBox(height: 2),
            Text(
              spec.label,
              style: TextStyle(
                fontSize: 11,
                height: 14 / 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 탭 하나에 쌓인 화면 수를 알려주는 관찰자.
class _StackDepthObserver extends NavigatorObserver {
  _StackDepthObserver(this.onChanged);

  final ValueChanged<int> onChanged;
  int _depth = 0;

  void _set(int next) {
    if (next == _depth) return;
    _depth = next;
    // 라우트 전환은 빌드 도중에 일어난다. 그 자리에서 provider를 건드리면
    // 빌드 중 상태 변경으로 예외가 난다.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(next));
  }

  // 시트와 대화상자는 세지 않는다. 재생 목록 시트를 열었다고 미니 플레이어가
  // 나타나면 같은 곡이 두 번 보인다.
  bool _counts(Route<dynamic> route) => route is PageRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_counts(route)) _set(_depth + 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_counts(route)) _set(_depth - 1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_counts(route)) _set(_depth - 1);
  }
}
