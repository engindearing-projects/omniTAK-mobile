import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    kotlin("plugin.serialization") version "2.0.21"
}

android {
    namespace = "soy.engindearing.omnitak.mobile"
    compileSdk = 35

    defaultConfig {
        applicationId = "soy.engindearing.omnitak.mobile"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables { useSupportLibrary = true }
    }

    // Upload keystore lives outside source control. Set the four props in
    // ~/.gradle/gradle.properties (user-global) OR keystore.properties next
    // to this file (gitignored). Release build falls back to the debug
    // signing config if no real keystore is configured, so local builds
    // keep working without secrets on disk.
    val keystoreProps = Properties().apply {
        val f = rootProject.file("keystore.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }

    signingConfigs {
        create("release") {
            val ksPath = keystoreProps.getProperty("storeFile")
                ?: providers.gradleProperty("OMNITAK_KEYSTORE").orNull
            if (ksPath != null) {
                storeFile = rootProject.file(ksPath)
                storePassword = keystoreProps.getProperty("storePassword")
                    ?: providers.gradleProperty("OMNITAK_KEYSTORE_PW").orNull
                keyAlias = keystoreProps.getProperty("keyAlias")
                    ?: providers.gradleProperty("OMNITAK_KEY_ALIAS").orNull
                keyPassword = keystoreProps.getProperty("keyPassword")
                    ?: providers.gradleProperty("OMNITAK_KEY_PW").orNull
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (signingConfigs.getByName("release").storeFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }

    buildFeatures { compose = true }

    // Pull in the existing icon/color/theme resources that already live under
    // app_assets/android/ so we don't duplicate them.
    sourceSets {
        getByName("main").res.srcDirs("src/main/res", "../app_assets/android")
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "/META-INF/{AL2.0,LGPL2.1}"
            )
        }
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.3")

    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")

    implementation("androidx.navigation:navigation-compose:2.8.4")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")

    implementation("androidx.datastore:datastore-preferences:1.1.1")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    // MapLibre Android (open-source fork of Mapbox) — parallel to iOS
    implementation("org.maplibre.gl:android-sdk:11.8.0")

    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
