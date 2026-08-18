
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../providers.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/mini_player.dart';

/// 재생 화면 위에 쌓인 화면 수. 재생 화면만 있으면 1이다.
final navDepthProvider = StateProvider<int>((ref) => 1);

/// 미니 플레이어 높이. 화면 폭을 다 쓰므로 바깥 여백이 없다.
const double kMiniPlayerHeight = 68;

/// 미니 플레이어가 가리는 만큼 목록 아래에 둘 여백.
double shellBottomInset(BuildContext context, WidgetRef ref) {
  return MediaQuery.of(context).padding.bottom +
      (ref.watch(miniPlayerVisibleProvider) ? kMiniPlayerHeight : 0);
}

/// 미니 플레이어를 띄울지.
///
/// 재생 화면 자체를 보고 있을 때만 뺀다. 같은 내용을 두 번 그릴 이유가 없다.
final miniPlayerVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(nowPlayingExistsProvider)) return false;
  return ref.watch(navDepthProvider) > 1;
});

void openLibraryScreen(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const LibraryScreen()));

void openSearchScreen(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const SearchScreen()));

void openSettingsScreen(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

/// 곡을 고르고 나면 재생 화면으로 돌아온다.
void backToPlayer(BuildContext context) =>
    Navigator.of(context).popUntil((r) => r.isFirst);

/// 앱의 뼈대.
///
/// 하단 탭바를 두지 않는다. 재생 화면이 곧 첫 화면이고 라이브러리, 검색,
/// 설정은 그 위에 쌓는다. 손이 자주 가는 것은 재생 조작이라 화면 아래쪽을
/// 그쪽에 내주려는 배치다. 설정은 자주 쓰지 않으니 위로 올렸다.
///
/// 미니 플레이어는 위에 화면이 쌓였을 때만 나온다.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _navKey = GlobalKey<NavigatorState>();

  /// 마지막으로 뒤로 가기를 누른 시각.
  ///
  /// 재생 화면에서 한 번 눌렀다고 앱이 그냥 꺼지면 놀란다. 음악이 나오는
  /// 중이라면 더 그렇다. 두 번 눌러야 나가게 한다.

  late final _observer = _StackDepthObserver((depth) {
    if (mounted) ref.read(navDepthProvider.notifier).state = depth;
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

  @override
  Widget build(BuildContext context) {
    // 두 재생이 겹치지 않게 하는 심판. 한 번은 watch해야 고리가 걸린다
    ref.watch(playbackRefereeProvider);

    // 설정이 바뀔 때만 시스템에 알린다. 매 프레임 부르면 안 된다.
    ref.listen<bool>(
      settingsProvider.select((s) => s.keepScreenOn),
      (_, on) => WakelockPlus.toggle(enable: on),
    );

    final showMini = ref.watch(miniPlayerVisibleProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
          return;
        }
        // 재생 화면이 첫 화면이라 뒤로 갈 곳이 없다. 여기서 앱을 닫으면
        // 듣다가 뒤로를 눌렀을 때 소리가 끊긴다. 대신 라이브러리를 연다.
        // 곡을 고르러 가는 길이 뒤로 가기와 같은 방향이라 손에 맞는다.
        //
        // 나가려면 홈이나 최근 앱을 쓴다. 뒤로로 나가던 동작은 뺐다.
        openLibraryScreen(_navKey.currentContext ?? context);
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        // 미니 플레이어 뒤로 내용이 지나가야 한다.
        extendBody: true,
        body: Navigator(
          key: _navKey,
          observers: [_observer],
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (_) => const PlayerScreen(),
          ),
        ),
        // 여기서 backToPlayer(context)를 부르면 안 된다. HomeShell의
        // context로 Navigator.of를 부르면 안쪽 _navKey가 아니라 바깥 루트
        // 네비게이터가 잡혀서 아무 일도 안 일어난다
        bottomNavigationBar: showMini
            ? MiniPlayer(
                onTap: () => _navKey.currentState?.popUntil((r) => r.isFirst),
              )
            : null,
      ),
    );
  }
}

/// 쌓인 화면 수를 알려주는 관찰자.
class _StackDepthObserver extends NavigatorObserver {
  _StackDepthObserver(this.onChanged);

  final ValueChanged<int> onChanged;
  int _depth = 0;

  // 시트와 대화상자는 세지 않는다. 재생 목록 시트를 열었다고 미니 플레이어가
  // 나타나면 같은 곡이 두 번 보인다.
  bool _counts(Route<dynamic> route) => route is PageRoute;

  void _set(int next) {
    if (next == _depth) return;
    _depth = next;
    // 라우트 전환은 빌드 도중에 일어난다. 그 자리에서 provider를 건드리면
    // 빌드 중 상태 변경으로 예외가 난다.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(next));
  }

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
