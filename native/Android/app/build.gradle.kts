import java.io.File
import java.nio.file.Files
import java.nio.file.attribute.PosixFilePermission
import java.security.KeyStore
import java.security.MessageDigest
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

val releaseApplicationId = providers.environmentVariable("ANDROID_RELEASE_APPLICATION_ID").orElse("com.john.bible").get()
val releaseVersionCode = providers.environmentVariable("ANDROID_RELEASE_VERSION_CODE").orElse("1").get().toInt()
val releaseVersionName = providers.environmentVariable("ANDROID_RELEASE_VERSION_NAME").orElse("1.0.0").get()
require(releaseApplicationId.matches(Regex("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+"))) { "Invalid ANDROID_RELEASE_APPLICATION_ID." }
require(releaseVersionCode in 1..2100000000) { "ANDROID_RELEASE_VERSION_CODE must be between 1 and 2100000000." }
require(releaseVersionName.matches(Regex("[A-Za-z0-9][A-Za-z0-9.+_-]{0,99}"))) { "Invalid ANDROID_RELEASE_VERSION_NAME." }

val releasePropertiesFile = file(providers.environmentVariable("ANDROID_RELEASE_PROPERTIES_FILE")
    .orElse("${System.getProperty("user.home")}/.local/share/john-android/release.properties").get())
val uploadProperties = Properties().apply {
    if (releasePropertiesFile.isFile) releasePropertiesFile.inputStream().use { load(it) }
}
fun uploadInput(environmentName: String, propertyName: String): String? =
    providers.environmentVariable(environmentName).orNull ?: uploadProperties.getProperty(propertyName)
val uploadStorePath = uploadInput("ANDROID_UPLOAD_KEYSTORE", "storeFile")
val uploadStorePassword = uploadInput("ANDROID_UPLOAD_STORE_PASSWORD", "storePassword")
val uploadKeyAlias = uploadInput("ANDROID_UPLOAD_KEY_ALIAS", "keyAlias")
val uploadKeyPassword = uploadInput("ANDROID_UPLOAD_KEY_PASSWORD", "keyPassword")
val hasUploadSigning = listOf(uploadStorePath, uploadStorePassword, uploadKeyAlias, uploadKeyPassword).all { !it.isNullOrEmpty() }
val allowUnsignedRelease = providers.environmentVariable("ANDROID_ALLOW_UNSIGNED_RELEASE").orNull == "true"

android {
    namespace = "com.john.bible"
    compileSdk = 36
    defaultConfig {
        applicationId = releaseApplicationId
        minSdk = 26
        targetSdk = 36
        versionCode = releaseVersionCode
        versionName = releaseVersionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    buildFeatures { compose = true; buildConfig = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    sourceSets["main"].assets.srcDir(layout.buildDirectory.dir("generated/john/assets"))
    sourceSets["main"].res.srcDir(layout.buildDirectory.dir("generated/john/res"))
    signingConfigs {
        if (hasUploadSigning) create("upload") {
            storeFile = file(uploadStorePath!!)
            storePassword = uploadStorePassword
            keyAlias = uploadKeyAlias
            keyPassword = uploadKeyPassword
        }
    }
    buildTypes {
        release {
            if (hasUploadSigning) signingConfig = signingConfigs.getByName("upload")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    packaging { resources.excludes += setOf("META-INF/AL2.0", "META-INF/LGPL2.1") }
    testOptions { unitTests.isReturnDefaultValues = true }
}

val validateReleaseInputs by tasks.registering {
    group = "verification"
    description = "Check release signing inputs and write public release metadata."
    doLast {
        fun checkPrivateFile(secretFile: File, description: String) {
            require(secretFile.isFile) { "$description does not exist." }
            val repoPath = rootProject.projectDir.parentFile.parentFile.canonicalFile.toPath()
            require(!secretFile.canonicalFile.toPath().startsWith(repoPath)) { "$description must be outside the repository." }
            if (Files.getFileStore(secretFile.toPath()).supportsFileAttributeView("posix")) {
                val permissions = Files.getPosixFilePermissions(secretFile.toPath())
                val publicPermissions = setOf(PosixFilePermission.GROUP_READ, PosixFilePermission.GROUP_WRITE,
                    PosixFilePermission.GROUP_EXECUTE, PosixFilePermission.OTHERS_READ,
                    PosixFilePermission.OTHERS_WRITE, PosixFilePermission.OTHERS_EXECUTE)
                require(permissions.intersect(publicPermissions).isEmpty()) { "$description must have private permissions (chmod 600)." }
            }
        }
        if (releasePropertiesFile.isFile) checkPrivateFile(releasePropertiesFile, "Release properties file")
        require(hasUploadSigning || allowUnsignedRelease) {
            "Release signing inputs are missing. See native/Android/RELEASE.md. Unsigned bundles are permitted only with ANDROID_ALLOW_UNSIGNED_RELEASE=true for CI validation."
        }
        var certificateSha256 = ""
        if (hasUploadSigning) {
            val uploadStore = file(uploadStorePath!!)
            checkPrivateFile(uploadStore, "Upload keystore")
            require(uploadKeyAlias != "androiddebugkey") { "The Android debug key cannot sign a release." }
            val store = KeyStore.getInstance(uploadStore, uploadStorePassword!!.toCharArray())
            val certificate = store.getCertificate(uploadKeyAlias) ?: error("Upload key alias has no certificate.")
            require(store.isKeyEntry(uploadKeyAlias)) { "Upload key alias is not a private key entry." }
            if (certificate is java.security.cert.X509Certificate) {
                require(!certificate.subjectX500Principal.name.contains("CN=Android Debug", ignoreCase = true)) { "The Android debug certificate cannot sign a release." }
                certificate.checkValidity()
            }
            require(store.getKey(uploadKeyAlias, uploadKeyPassword!!.toCharArray()) != null) { "Cannot open upload key." }
            certificateSha256 = MessageDigest.getInstance("SHA-256").digest(certificate.encoded).joinToString("") { "%02x".format(it) }
        }
        val report = layout.buildDirectory.file("reports/release/release-inputs.properties").get().asFile
        report.parentFile.mkdirs()
        Properties().apply {
            setProperty("applicationId", releaseApplicationId)
            setProperty("versionCode", releaseVersionCode.toString())
            setProperty("versionName", releaseVersionName)
            setProperty("minSdk", "26")
            setProperty("targetSdk", "36")
            setProperty("certificateSha256", certificateSha256)
            setProperty("signed", hasUploadSigning.toString())
        }.also { publicMetadata -> report.outputStream().use { publicMetadata.store(it, "Public release metadata; no signing secrets") } }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach { dependsOn(validateReleaseInputs) }

val stageJohnAssets by tasks.registering(Exec::class) {
    workingDir(rootProject.projectDir.parentFile.parentFile)
    commandLine("python3", "scripts/android/stage-assets.py", "--output", layout.buildDirectory.dir("generated/john").get().asFile.absolutePath)
    inputs.files(fileTree("${rootProject.projectDir}/content"), fileTree("${rootProject.projectDir}/../../src/services"), fileTree("${rootProject.projectDir}/../../assets"), fileTree("${rootProject.projectDir}/../../scripts/android"))
    outputs.dir(layout.buildDirectory.dir("generated/john"))
}
tasks.named("preBuild") { dependsOn(stageJohnAssets) }
dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.09.00"))
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.3")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.media:media:1.7.0")
    // 2.1.0 parity (Android 1.1.0): the Fathers and Doctors purchase and the in-app rating sheet.
    implementation("com.android.billingclient:billing-ktx:8.3.0")
    implementation("com.google.android.play:review-ktx:2.0.2")
    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
    androidTestImplementation(platform("androidx.compose:compose-bom:2025.09.00"))
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
