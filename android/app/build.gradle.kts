import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val hasKeystoreProperties = keystorePropertiesFile.exists()

android {

    namespace = "com.yusufnaser.customsbroker"

    // مطلوب لـ file_picker و flutter_plugin_android_lifecycle
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    defaultConfig {

        applicationId = "com.yusufnaser.customsbroker"

        minSdk = flutter.minSdkVersion

        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }


    compileOptions {

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }


    signingConfigs {

        if (hasKeystoreProperties) {

            create("release") {

                keyAlias = keystoreProperties["keyAlias"] as String

                keyPassword = keystoreProperties["keyPassword"] as String

                storePassword = keystoreProperties["storePassword"] as String

                storeFile =
                    file(keystoreProperties["storeFile"] as String)
            }
        }
    }


    buildTypes {

        release {

            signingConfig =
                if (hasKeystoreProperties) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }


            isMinifyEnabled = false

            isShrinkResources = false
        }
    }
}


kotlin {

    compilerOptions {

        jvmTarget =
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}


flutter {

    source = "../.."
}
