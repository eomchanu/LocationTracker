package com.eomchanu.location_tracker

import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import androidx.core.app.ActivityCompat
import android.telephony.CellInfo
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoCdma
import android.telephony.CellInfoWcdma
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val GPS_CHANNEL = "com.eomchanu.location_tracker/gps"
    private val CELL_CHANNEL = "com.eomchanu.location_tracker/cell"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CELL_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getCellInfo") {
                val cellInfoList = getCellInfo()
                if (cellInfoList != null) {
                    result.success(cellInfoList)
                } else {
                    result.error("UNAVAILABLE", "No cell tower information available.", null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GPS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getGPSLocation") {
                val location = getGPSLocation()
                if (location != null) {
                    val locationData = mapOf(
                        "latitude" to location.latitude,
                        "longitude" to location.longitude,
                        "accuracy" to location.getAccuracy()
                    )
                    result.success(locationData)
                } else {
                    result.error("LOCATION_ERROR", "Failed to retrieve GPS location", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getGPSLocation(): Location? {
        val locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), 1)
            return null
        }
        return locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
    }
    
    private fun getCellInfo(): Map<String, Any>? {
        val telephonyManager = getSystemService(TELEPHONY_SERVICE) as? TelephonyManager
        if (telephonyManager == null) {
            throw Exception("TelephonyManager is not available.")
        }

        val registeredCellTower = mutableListOf<Map<String, Any>>()
        val neighboringCellTowers = mutableListOf<Map<String, Any>>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            val allCellInfo = telephonyManager.allCellInfo
            if (allCellInfo != null && allCellInfo.isNotEmpty()) {
                for (cellInfo in allCellInfo) {
                    val isRegistered = when (cellInfo) {
                        is CellInfoGsm -> cellInfo.isRegistered
                        is CellInfoLte -> cellInfo.isRegistered
                        is CellInfoCdma -> cellInfo.isRegistered
                        is CellInfoWcdma -> cellInfo.isRegistered
                        else -> false
                    }

                    val cellData = when (cellInfo) {
                        is CellInfoLte -> {
                            val cellIdentity = cellInfo.cellIdentity
                            mapOf(
                                "type" to "LTE",
                                "cid" to cellIdentity.ci,
                                "tac" to cellIdentity.tac,
                                "mcc" to cellIdentity.mcc,
                                "mnc" to cellIdentity.mnc
                            )
                        }
                        is CellInfoGsm -> {
                            val cellIdentity = cellInfo.cellIdentity
                            mapOf(
                                "type" to "GSM",
                                "cid" to cellIdentity.cid,
                                "lac" to cellIdentity.lac,
                                "mcc" to cellIdentity.mcc,
                                "mnc" to cellIdentity.mnc
                            )
                        }
                        is CellInfoWcdma -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                                val cellIdentity = cellInfo.cellIdentity
                                mapOf(
                                    "type" to "WCDMA",
                                    "cid" to cellIdentity.cid,
                                    "lac" to cellIdentity.lac,
                                    "mcc" to cellIdentity.mcc,
                                    "mnc" to cellIdentity.mnc
                                )
                            } else null
                        }
                        else -> null
                    }

                    if (cellData != null) {
                        if (isRegistered) {
                            registeredCellTower.add(cellData)
                        } else {
                            neighboringCellTowers.add(cellData)
                        }
                    }
                }
            }
        }

        return if (registeredCellTower.isNotEmpty() || neighboringCellTowers.isNotEmpty()) {
            mapOf(
                "registered" to registeredCellTower,
                "neighboring" to neighboringCellTowers
            )
        } else null
    }
}
