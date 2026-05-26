package com.example.velhodozap

import android.bluetooth.BluetoothAdapter
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.Log
import android.net.wifi.WifiManager
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

                    "openSettingsAction" -> {
                        val action = call.argument<String>("action") ?: Settings.ACTION_SETTINGS
                        try {
                            startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
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

                    "getWifiInfo" -> {
                        result.success(getWifiInfo())
                    }

                    "startWhatsAppCall" -> {
                        val phoneRaw = call.argument<String>("phoneRaw")
                        val isVideo = call.argument<Boolean>("isVideo") ?: false
                        if (phoneRaw.isNullOrBlank()) {
                            result.error("invalid_args", "phoneRaw is required", null)
                            return@setMethodCallHandler
                        }

                        result.success(startWhatsAppCall(phoneRaw, isVideo))
                    }

                    "openWhatsAppChat" -> {
                        val phoneRaw = call.argument<String>("phoneRaw")
                        if (phoneRaw.isNullOrBlank()) {
                            result.error("invalid_args", "phoneRaw is required", null)
                            return@setMethodCallHandler
                        }

                        result.success(openWhatsAppChat(phoneRaw))
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

            val connectedName =
                try {
                    if (!enabled) {
                        null
                    } else {
                        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
                        val devices = mutableListOf<android.bluetooth.BluetoothDevice>()
                        if (manager != null) {
                            devices.addAll(manager.getConnectedDevices(android.bluetooth.BluetoothProfile.A2DP))
                            devices.addAll(manager.getConnectedDevices(android.bluetooth.BluetoothProfile.HEADSET))
                            devices.addAll(manager.getConnectedDevices(android.bluetooth.BluetoothProfile.GATT))
                        }
                        devices.firstOrNull()?.name
                    }
                } catch (e: SecurityException) {
                    null
                } catch (e: Exception) {
                    null
                }

            mapOf(
                "enabled" to enabled,
                "connected" to connected,
                "connectedName" to connectedName,
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

    private fun getWifiInfo(): Map<String, Any?>? {
        return try {
            val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return null
            val enabled = wifi.isWifiEnabled
            val info = wifi.connectionInfo
            var connected = false
            var ssid = ""
            if (enabled && info != null) {
                connected = info.networkId != -1
                ssid = info.ssid ?: ""
                if (ssid.startsWith("\"") && ssid.endsWith("\"") && ssid.length >= 2) {
                    ssid = ssid.substring(1, ssid.length - 1)
                }
            }
            if (ssid == "<unknown ssid>") {
                ssid = ""
            }
            mapOf(
                "enabled" to enabled,
                "connected" to connected,
                "ssid" to ssid,
            )
        } catch (e: SecurityException) {
            null
        } catch (e: Exception) {
            null
        }
    }

    private fun startWhatsAppCall(phoneRaw: String, isVideo: Boolean): Boolean {
        return try {
            val mime =
                if (isVideo) {
                    "vnd.android.cursor.item/vnd.com.whatsapp.video.call"
                } else {
                    "vnd.android.cursor.item/vnd.com.whatsapp.voip.call"
                }

            val e164Candidates = whatsappE164Candidates(phoneRaw)
            if (e164Candidates.isEmpty()) return false
            val jidCandidates = e164Candidates.map { "$it@s.whatsapp.net" }

            val dataId = findWhatsAppCallDataId(mime, jidCandidates) ?: run {
                Log.d("VelhoDoZap", "WhatsApp call not found. mime=$mime candidates=$jidCandidates raw=$phoneRaw")
                return false
            }
            val uri = ContentUris.withAppendedId(ContactsContract.Data.CONTENT_URI, dataId)

            val intent =
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mime)
                    setPackage("com.whatsapp")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }

            Log.d("VelhoDoZap", "WhatsApp call start. mime=$mime dataId=$dataId uri=$uri raw=$phoneRaw")
            startActivity(intent)
            true
        } catch (e: SecurityException) {
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun openWhatsAppChat(phoneRaw: String): Boolean {
        return try {
            val dataId = findWhatsAppProfileDataId(phoneRaw) ?: return false
            val uri = ContentUris.withAppendedId(ContactsContract.Data.CONTENT_URI, dataId)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "vnd.android.cursor.item/vnd.com.whatsapp.profile")
                setPackage("com.whatsapp")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
            true
        } catch (e: SecurityException) {
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun digitsOnly(input: String): String {
        return input.replace(Regex("\\D"), "")
    }

    private fun normalizeBrDddAndNumberWithNine(input: String): String {
        var digits = digitsOnly(input)
        if (digits.startsWith("55")) digits = digits.substring(2)
        digits = digits.replaceFirst(Regex("^0+"), "")

        if (digits.length == 10) {
            val ddd = digits.substring(0, 2)
            val rest = digits.substring(2)
            return ddd + "9" + rest
        }

        if (digits.length == 11) return digits
        return digits
    }

    private fun whatsappE164Candidates(phoneRaw: String): List<String> {
        var digits = digitsOnly(phoneRaw)
        if (digits.isEmpty()) return emptyList()

        if (digits.startsWith("55")) digits = digits.substring(2)
        digits = digits.replaceFirst(Regex("^0+"), "")

        val candidatesLocal = linkedSetOf<String>()
        candidatesLocal.add(digits)

        if (digits.length == 10) {
            val ddd = digits.substring(0, 2)
            val rest = digits.substring(2)
            candidatesLocal.add(ddd + "9" + rest)
        } else if (digits.length == 11) {
            val ddd = digits.substring(0, 2)
            val first = digits.substring(2, 3)
            val rest = digits.substring(3)
            if (first == "9") {
                candidatesLocal.add(ddd + rest)
            }
        }

        return candidatesLocal
            .map { local ->
                val d = digitsOnly(local)
                if (d.startsWith("55")) d else "55$d"
            }.distinct()
    }

    private fun findWhatsAppProfileDataId(phoneRaw: String): Long? {
        val target = normalizeBrDddAndNumberWithNine(phoneRaw)
        if (target.isEmpty()) return null

        val resolver = contentResolver
        val projection =
            arrayOf(
                ContactsContract.Data._ID,
                ContactsContract.Data.DATA1,
                ContactsContract.Data.DATA3,
            )

        val selection = "${ContactsContract.Data.MIMETYPE} = ?"
        val args = arrayOf("vnd.android.cursor.item/vnd.com.whatsapp.profile")

        val cursor =
            resolver.query(
                ContactsContract.Data.CONTENT_URI,
                projection,
                selection,
                args,
                null,
            ) ?: return null

        cursor.use { c ->
            val idxId = c.getColumnIndex(ContactsContract.Data._ID)
            val idxData1 = c.getColumnIndex(ContactsContract.Data.DATA1)
            val idxData3 = c.getColumnIndex(ContactsContract.Data.DATA3)

            while (c.moveToNext()) {
                val id = c.getLong(idxId)
                val data1 = if (idxData1 >= 0) (c.getString(idxData1) ?: "") else ""
                val data3 = if (idxData3 >= 0) (c.getString(idxData3) ?: "") else ""

                val candFromData1 =
                    if (data1.contains("@s.whatsapp.net")) {
                        normalizeBrDddAndNumberWithNine(data1)
                    } else {
                        ""
                    }

                val cleanedData3 = data3.replace("Message", "").trim()
                val candFromData3 = normalizeBrDddAndNumberWithNine(cleanedData3)

                if (candFromData1 == target || candFromData3 == target) {
                    return id
                }
            }
        }

        return null
    }

    private fun findWhatsAppCallDataId(mimeType: String, jids: List<String>): Long? {
        if (jids.isEmpty()) return null
        val resolver = contentResolver
        val projection = arrayOf(ContactsContract.Data._ID, ContactsContract.Data.DATA1)
        val placeholders = jids.joinToString(",") { "?" }
        val selection = "${ContactsContract.Data.MIMETYPE} = ? AND ${ContactsContract.Data.DATA1} IN ($placeholders)"
        val args = arrayOf(mimeType, *jids.toTypedArray())
        val cursor =
            resolver.query(
                ContactsContract.Data.CONTENT_URI,
                projection,
                selection,
                args,
                null,
            ) ?: return null

        cursor.use { c ->
            val idxId = c.getColumnIndex(ContactsContract.Data._ID)
            return if (c.moveToFirst()) {
                c.getLong(idxId)
            } else {
                null
            }
        }
    }
}
