package id.kakzaki.liveness_cam

import android.app.Activity
import android.content.Intent
import androidx.annotation.NonNull
import id.kakzaki.face_detection.Identifier
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry


/** LivenessCamPlugin */
class LivenessCamPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var activity : Activity
//  private lateinit var context : Context
 private var pluginBinding: FlutterPluginBinding? = null
  private lateinit var result : Result
  private var livenessDetectionCode = 101

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "liveness_cam")
    channel.setMethodCallHandler(this)
   // context = flutterPluginBinding.applicationContext
    pluginBinding = flutterPluginBinding
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    this.result = result
    if (call.method == "start") {
     // activity.startActivityForResult(Identifier.getLivenessIntent(context), livenessDetectionCode)
      activity.startActivityForResult(Identifier.getLivenessIntent(activity), livenessDetectionCode)
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    channel.setMethodCallHandler(null)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivity() {
    channel.setMethodCallHandler(null)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (resultCode == Activity.RESULT_OK) {
      when (requestCode) {
        livenessDetectionCode -> {
          val livenessResult = Identifier.getLivenessResult(data)
          livenessResult?.let { res ->
            if (res.isSuccess) {
              result.success("${res.detectionResult?.get(0)?.image}")
            } else {
              result.success(null)
            }
          }
        }

      }
      return true
    }else{
      return false
    }
  }

}
