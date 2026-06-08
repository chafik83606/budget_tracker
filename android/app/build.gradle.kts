import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

fun requireKeystoreProperty(name: String): String {
    if (!keystorePropertiesFile.exists()) {
        error("Fichier key.properties introuvable : ${keystorePropertiesFile.absolutePath}")
    }
    return keystoreProperties.getProperty(name)
        ?: error("Propriété '$name' manquante dans key.properties")
}

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.readLines(Charsets.UTF_8).forEach { line ->
        if (line.isBlank() || line.startsWith("#")) return@forEach
        val idx = line.indexOf('=')
        if (idx > 0) {
            val key = line.substring(0, idx).trim().removePrefix("\uFEFF")
            val value = line.substring(idx + 1).trim()
            keystoreProperties.setProperty(key, value)
        }
    }
}

android {
    namespace = "com.ctre2.budgettracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = requireKeystoreProperty("keyAlias")
            keyPassword = requireKeystoreProperty("keyPassword")
            storePassword = requireKeystoreProperty("storePassword")
            storeFile = rootProject.file(requireKeystoreProperty("storeFile"))
        }
    }

    defaultConfig {
        applicationId = "com.ctre2.budgettracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
