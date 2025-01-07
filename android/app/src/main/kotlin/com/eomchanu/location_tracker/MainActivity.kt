package com.eomchanu.location_tracker

import android.os.Build
import android.telephony.CellInfo
import android.telephony.CellInfoGsm
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.eomchanu.location_tracker/gsm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getGsmInfo") {
                val gsmInfo = getGsmInfo()
                if (gsmInfo != null) {
                    result.success(gsmInfo)
                } else {
                    result.error("UNAVAILABLE", "GSM info not available.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getGsmInfo(): Map<String, Any>? {
        val telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
        val gsmData = mutableMapOf<String, Any>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            for (cellInfo in telephonyManager.allCellInfo) {
                if (cellInfo is CellInfoGsm) {
                    val cellIdentity = cellInfo.cellIdentity
                    gsmData["cid"] = cellIdentity.cid
                    gsmData["lac"] = cellIdentity.lac
                    gsmData["mcc"] = cellIdentity.mcc
                    gsmData["mnc"] = cellIdentity.mnc
                    return gsmData
                }
            }
        }
        return null
    }
}
