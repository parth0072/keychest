plugins {
    alias(libs.plugins.android.application) apply false
    // The generated keychest-keys module applies kotlin("jvm") without a version, so declare it once here.
    alias(libs.plugins.kotlin.jvm) apply false
}
