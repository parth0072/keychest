plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "dev.keychest.sample"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.keychest.sample"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    // The sample reads BuildConfig.DEBUG to choose between Secrets.Debug and Secrets.Release.
    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            // Sample only: sign with the debug key so the release build can be installed.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(project(":keychest-keys"))
}
