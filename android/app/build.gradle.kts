plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.social_login_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.social_login_app"
        // You can update the following values to match your application needs.
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
//    signingConfigs {
//        getByName("debug") {
//            keyAlias = "androiddebugkey"
//            storePassword = "123456"
//            storeFile = file("mykey.jks")
//            keyPassword = "123456"
//        }
//    }
    signingConfigs {
        getByName("debug") {
            // Comment out your custom keystore temporarily
             keyAlias = "androiddebugkey"
             storePassword = "123456"
             storeFile = file("mykey.jks")
             keyPassword = "123456"
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug") // Only for testing
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    dependencies {
        // ...
        implementation("com.facebook.android:facebook-android-sdk:[8,9)")
        implementation ("com.google.android.gms:play-services-auth:20.7.0")

    }
}

flutter {
    source = "../.."
}
