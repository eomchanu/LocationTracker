import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> _requestLocationPermission() async {
  var status = await Permission.location.request();
  if (status.isGranted) {
    print("Location permission granted");
  } else {
    print("Location permission denied");
  }
}

void main() {
  runApp(LocationApp());
}

class LocationApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location App',
      home: LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String _gpsLocation = "Fetching...";
  String _wifiInfo = "Fetching...";
  String _gsmInfo = "Fetching...";
  static const platform = MethodChannel('com.eomchanu.location_tracker/gsm');
  final NetworkInfo _networkInfo = NetworkInfo();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getGPSLocation();
    _getWiFiInfo();
    _getGSMInfo();
  }

  // GPS 정보 가져오기
  Future<void> _getGPSLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _gpsLocation = "Lat: ${position.latitude}, Lng: ${position.longitude}";
      });
    } catch (e) {
      setState(() {
        _gpsLocation = "Failed to get GPS location: $e";
      });
    }
  }

  // Wi-Fi 정보 가져오기
  Future<void> _getWiFiInfo() async {
    try {
      String? wifiName = await _networkInfo.getWifiName();
      String? wifiBSSID = await _networkInfo.getWifiBSSID();
      setState(() {
        _wifiInfo = "SSID: ${wifiName ?? "Unknown"}, BSSID: ${wifiBSSID ?? "Unknown"}";
      });
    } catch (e) {
      setState(() {
        _wifiInfo = "Failed to get Wi-Fi info: $e";
      });
    }
  }

  // GSM 정보 가져오기
  Future<void> _getGSMInfo() async {
    try {
      final gsmInfo = await platform.invokeMethod<Map>('getGsmInfo');
      setState(() {
        _gsmInfo = "CID: ${gsmInfo?['cid']}, LAC: ${gsmInfo?['lac']}, MCC: ${gsmInfo?['mcc']}, MNC: ${gsmInfo?['mnc']}";
      });
    } catch (e) {
      setState(() {
        _gsmInfo = "Failed to get GSM info: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Location App')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("GPS Location: $_gpsLocation"),
            SizedBox(height: 10),
            Text("Wi-Fi Info: $_wifiInfo"),
            SizedBox(height: 10),
            Text("GSM Info: $_gsmInfo"),
          ],
        ),
      ),
    );
  }
}
