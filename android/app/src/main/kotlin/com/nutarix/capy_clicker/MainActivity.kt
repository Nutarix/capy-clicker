package com.nutarix.capy_clicker

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    /**
     * SurfaceView (the opaque default) punches a hole. On Samsung, a late frame
     * after setState shows SurfaceFlinger's undefined buffer — a full-screen
     * gray — and the cream windowBackground behind the hole never wins.
     * TextureView keeps the previous frame instead of clearing to gray.
     */
    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.parseColor("#FFF8EC")
        if (Build.VERSION.SDK_INT >= 29) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
    }
}
