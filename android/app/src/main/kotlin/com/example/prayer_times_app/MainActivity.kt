package com.wisam.salatTime

import android.hardware.GeomagneticField
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val CHANNEL = "qibla/declination"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      if (call.method == "getDeclination") {
        val lat = (call.argument<Double>("lat") ?: 0.0).toFloat()
        val lon = (call.argument<Double>("lon") ?: 0.0).toFloat()
        val alt = (call.argument<Double>("alt") ?: 0.0).toFloat()
        val time = call.argument<Long>("time") ?: System.currentTimeMillis()

        val geo = GeomagneticField(lat, lon, alt, time)
        result.success(geo.declination.toDouble()) 
      } else {
        result.notImplemented()
      }
    }
  }
}
