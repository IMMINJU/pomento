# Spotify App Remote용 R8 규칙.
#
# 릴리스 빌드에서 R8이 "Missing class"로 멈춘다. App Remote aar이 잭슨과
# 여러 애노테이션 라이브러리를 선택적으로 참조하는데, 우리는 그중 gson만
# 넣었기 때문이다. 없는 쪽은 쓰지 않으니 경고를 끈다.
-dontwarn com.fasterxml.jackson.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn com.spotify.base.annotations.**
-dontwarn javax.annotation.**

# 프로토콜 모델은 필드 이름 그대로 직렬화해서 Spotify 앱과 주고받는다.
# 이름을 줄이면 통신이 깨진다.
-keep class com.spotify.protocol.** { *; }
-keep class com.spotify.android.appremote.** { *; }
-keep class com.spotify.sdk.android.auth.** { *; }

# gson이 제네릭 타입을 읽으려면 Signature가 남아 있어야 한다.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
