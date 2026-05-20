package com.example.untitled

import io.flutter.embedding.android.FlutterActivity
import android.view.WindowManager

class MainActivity: FlutterActivity() {
    override fun onResume() {
        super.onResume()
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
