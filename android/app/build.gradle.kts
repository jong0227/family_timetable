plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.family.family_timetable"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // ota_update(앱 안 업데이트)가 요구하는 Java 새 API 지원
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // 스토어 게시 후엔 바꿀 수 없다. Firebase 콘솔에 이 이름으로 앱을 등록한다(docs/FIREBASE_SETUP.md).
        applicationId = "com.family.timetable"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// google-services.json이 있을 때만 Firebase 플러그인을 건다. 없으면(콘솔 등록 전)
// 플러그인이 빌드를 실패시키므로, 그동안은 로컬 모드 앱으로 빌드된다.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
