import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(LocationApp());
}

class LocationApp extends StatelessWidget {
  const LocationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Tracker',
      home: LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  String _gpsLocation = "Fetching...";
  String _wifiInfo = "Fetching...";
  String _registeredCellInfo = "Fetching...";
  String _neighboringCellInfo = "Fetching...";
  static const platform = MethodChannel('com.eomchanu.location_tracker/cell');
  final NetworkInfo _networkInfo = NetworkInfo();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getGPSLocation();
    _getWiFiInfo();
    _getCellInfo();
  }
  
  // 위치 권한 요청
  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      _getLocation();
    } else if (status.isDenied) {
      openAppSettings();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  // 위치 정보 가져오기
  Future<void> _getLocation() async {
    _getGPSLocation();
    // TODO: 위치 정보 가져오는 함수로 변경
    _getWiFiInfo();
    _getCellInfo();
  }

  // GPS 정보 가져오기
  Future<void> _getGPSLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
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

  // 기지국 정보 가져오기
  Future<void> _getCellInfo() async {
    try {
      final Map<dynamic, dynamic> cellInfo = await platform.invokeMethod('getCellInfo');
      final List<dynamic> registered = cellInfo['registered'];
      final List<dynamic> neighboring = cellInfo['neighboring'];

      final registeredText = registered.map((info) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(info);
        return "Type: ${data['type']}, CID: ${data['cid'] ?? 'N/A'}, LAC: ${data['lac'] ?? 'N/A'}, TAC: ${data['tac'] ?? 'N/A'}, MCC: ${data['mcc'] ?? 'N/A'}, MNC: ${data['mnc'] ?? 'N/A'}";
      }).join("\n");

      final neighboringText = neighboring.map((info) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(info);
        return "Type: ${data['type']}, CID: ${data['cid'] ?? 'N/A'}, LAC: ${data['lac'] ?? 'N/A'}, TAC: ${data['tac'] ?? 'N/A'}, MCC: ${data['mcc'] ?? 'N/A'}, MNC: ${data['mnc'] ?? 'N/A'}";
      }).join("\n");

      setState(() {
        _registeredCellInfo = registeredText;
        _neighboringCellInfo = neighboringText;
      });
    } catch (e) {
      setState(() {
        _registeredCellInfo = "Failed to fetch registered cell info: $e";
        _neighboringCellInfo = "Failed to fetch neighboring cell info: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Location Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "GPS Location",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_gpsLocation),
              SizedBox(height: 10),
              Text(
                "Wi-Fi Info",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_wifiInfo),
              SizedBox(height: 10),
              Text(
                "Registered Cell Tower Info",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_registeredCellInfo),
              SizedBox(height: 10),
              Text(
                "Neighboring Cell Tower Info",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_neighboringCellInfo),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: _getLocation,
                child: Text(
                  "Refresh",
                  style: const TextStyle(
                    color: Color.fromARGB(255, 0, 0, 0),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
