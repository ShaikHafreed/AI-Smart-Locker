plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {

    namespace = "com.example.mobile_app"

    compileSdk = 36

    ndkVersion = "28.2.13676358"

    defaultConfig {

        applicationId = "com.example.mobile_app"

        minSdk = 24

        targetSdk = 36

        versionCode = flutter.versionCode

        versionName = flutter.versionName
    }

    compileOptions {

        sourceCompatibility =
            JavaVersion.VERSION_17

        targetCompatibility =
            JavaVersion.VERSION_17

        isCoreLibraryDesugaringEnabled =
            true
    }

    kotlinOptions {

        jvmTarget = "17"
    }

    buildTypes {

        release {

            signingConfig =
                signingConfigs.getByName(
                    "debug"
                )
        }
    }
}

dependencies {

    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.5"
    )
}

flutter {

    source = "../.."
}