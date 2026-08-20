allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 플러그인마다 compileSdk를 자기 값으로 박아두는데, 그중 낮은 것이 있으면
// 최신 androidx 의존성과 충돌해 빌드가 멈춘다. 여기서
// 한 번에 맞춰준다. compileSdk는 어떤 API로 컴파일하느냐일 뿐이라 앱이
// 설치되는 기기 범위(minSdk)에는 영향이 없다.
//
// 이 블록은 아래 evaluationDependsOn보다 먼저 와야 한다. 그쪽이 :app을
// 평가해버리면 afterEvaluate를 더 걸 수 없다.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            if (ext is com.android.build.gradle.BaseExtension) {
                ext.compileSdkVersion(37)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
