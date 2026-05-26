package com.example.velhodozap

import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "velhodozap/platform_intents"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openApp" -> {
                        val packageName = call.argument<String>("packageName")
                        val relaunch = call.argument<Boolean>("relaunch") ?: false
                        if (packageName.isNullOrBlank()) {
                            result.error("invalid_args", "packageName is required", null)
                            return@setMethodCallHandler
                        }

                        val ok = openApp(packageName, relaunch)
                        result.success(ok)
                    }

                    "openSystemSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "openVelhoDoZapSettings" -> {
                        try {
                            val intent =
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", packageName, null)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    "getBluetoothEnabled" -> {
                        result.success(getBluetoothEnabled())
                    }

                    "getBluetoothInfo" -> {
                        result.success(getBluetoothInfo())
                    }

                    "getCellSignalInfo" -> {
                        result.success(getCellSignalInfo())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun openApp(packageName: String, relaunch: Boolean): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (relaunch) {
                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
            } else {
                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun getBluetoothEnabled(): Boolean? {
        return try {
            val adapter = BluetoothAdapter.getDefaultAdapter() ?: return null
            adapter.isEnabled
        } catch (e: SecurityException) {
            null
        } catch (e: Exception) {
            null
        }
    }

    private fun getBluetoothInfo(): Map<String, Any?>? {
        return try {
            val adapter = BluetoothAdapter.getDefaultAdapter() ?: return null
            val enabled = adapter.isEnabled

            val connected =
                try {
                    val a2dp = adapter.getProfileConnectionState(android.bluetooth.BluetoothProfile.A2DP)
                    val headset = adapter.getProfileConnectionState(android.bluetooth.BluetoothProfile.HEADSET)
                    val gatt = adapter.getProfileConnectionState(android.bluetooth.BluetoothProfile.GATT)
                    a2dp == android.bluetooth.BluetoothProfile.STATE_CONNECTED ||
                        headset == android.bluetooth.BluetoothProfile.STATE_CONNECTED ||
                        gatt == android.bluetooth.BluetoothProfile.STATE_CONNECTED
                } catch (e: SecurityException) {
                    null
                } catch (e: Exception) {
                    null
                }

            mapOf(
                "enabled" to enabled,
                "connected" to connected,
            )
        } catch (e: SecurityException) {
            null
        } catch (e: Exception) {
            null
        }
    }

    private fun getCellSignalInfo(): Map<String, Any?>? {
        return try {
            val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return null
            val ss = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) telephony.signalStrength else null
            val best = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ss?.cellSignalStrengths?.maxByOrNull { it.level }
            } else {
                null
            }

            val level = best?.level ?: ss?.level
            val dbm = best?.dbm
            val netType =
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) telephony.dataNetworkType else telephony.networkType
                } catch (e: SecurityException) {
                    null
                } catch (e: Exception) {
                    null
                }

            mapOf(
                "level" to level,
                "dbm" to dbm,
                "networkType" to netType,
            )
        } catch (e: SecurityException) {
            null
        } catch (e: Exception) {
            null
        }
    }
}
