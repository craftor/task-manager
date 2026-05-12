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

subprojects {
    afterEvaluate {
        // Fix AGP 8.x compatibility for plugins that don't declare compileSdk/namespace
        if (hasProperty("android")) {
            try {
                val androidExt = extensions.getByName("android")
                val androidCls = androidExt.javaClass
                // Inject namespace if missing
                try {
                    val nsMethod = androidCls.getMethod("getNamespace")
                    val ns = nsMethod.invoke(androidExt) as? String
                    if (ns.isNullOrEmpty()) {
                        androidCls.getMethod("setNamespace", String::class.java)
                            .invoke(androidExt, project.group.toString())
                    }
                } catch (_: Exception) { /* ignore */ }
                // Inject compileSdk if missing (app_links 6.x compat)
                try {
                    val csdkField = androidCls.getDeclaredField("compileSdk")
                    csdkField.isAccessible = true
                    val csdk = csdkField.get(androidExt) as? String
                    if (csdk == null || csdk == "null") {
                        csdkField.set(androidExt, "android-34")
                    }
                } catch (_: Exception) { /* ignore */ }
            } catch (_: Exception) { /* ignore */ }
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
