plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pomento.app"
    // permission_handler_android가 37 이상을 요구한다. Flutter 기본값은
    // 아직 36이라 직접 올린다.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pomento.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Spotify 인증이 돌아올 주소. Spotify 대시보드의 Redirect URI를
        // pomento://auth 로 등록해야 짝이 맞는다.
        manifestPlaceholders["redirectSchemeName"] = "pomento"
        manifestPlaceholders["redirectHostName"] = "auth"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Spotify App Remote aar이 없는 라이브러리를 참조해서 R8이 멈춘다.
            // proguard-rules.pro에서 그 경고를 끄고 프로토콜 모델을 지킨다.
            // AGP가 이 파일을 알아서 읽기도 하지만, 빌드가 무엇에 기대는지
            // 파일에 드러나 있어야 한다.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
