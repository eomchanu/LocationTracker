import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location_tracker/secrets.dart';

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
  String _currentLocation = "Fetching...";
  String _gpsLocation = "Fetching...";
  String _wifiEstimatedLocation = "Fetching...";
  String _cellTowerEstimatedLocation = "Fetching...";
  String _wifiInfo = "Fetching...";
  String _registeredCellInfo = "Fetching...";
  String _neighboringCellInfo = "Fetching...";
  static const platform = MethodChannel('com.eomchanu.location_tracker/cell');
  final NetworkInfo _networkInfo = NetworkInfo();

  LatLng _initialPosition = const LatLng(37.7749, -122.4194); // Default: San Francisco
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getWiFiInfo();
    _getCellInfo();
    _getLocation();
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
    _getCurrentLocation();
    _getGPSLocation();
    _getWiFiEstimatedLocation();
    _getCellTowerEstimatedLocation();
  }

  // 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = "Lat: ${position.latitude}, Lng: ${position.longitude}";
        _initialPosition = LatLng(position.latitude, position.longitude);
      });
      _updateMarkers();
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_initialPosition),
      );
    } catch (e) {
      setState(() {
        _currentLocation = "Failed to get current location: $e";
      });
    }
  }

  // GPS 위치 가져오기
  Future<void> _getGPSLocation() async {
    try {
      final response = await http.post(
        Uri.parse("https://www.googleapis.com/geolocation/v1/geolocate?key=$googleGeoLocationAPIKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({}), // body를 비워도 기기의 기본 네트워크 정보를 기반으로 계산..
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final double lat = data['location']['lat'];
        final double lng = data['location']['lng'];

        setState(() {
          _gpsLocation = "Lat: $lat, Lng: $lng, Accuracy: ${data['accuracy']} meters";
          _markers.add(
            Marker(
              markerId: MarkerId("GPS"),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(title: "GPS Location"),
            ),
          );
        });
      } else {
        setState(() {
          _currentLocation = "Failed to get Google GPS location: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _currentLocation = "Error fetching Google GPS location: $e";
      });
    }
  }


  Future<void> _getWiFiEstimatedLocation() async {
    try {
      // TODO: wifiInfo에서 사용
      String? wifiBSSID = await _networkInfo.getWifiBSSID();
      if (wifiBSSID == null || wifiBSSID.isEmpty) {
        setState(() {
          _wifiEstimatedLocation = "No Wi-Fi info available for estimation.";
        });
        return;
      }

      final requestData = {
        "wifiAccessPoints": [
          {"macAddress": wifiBSSID}
        ]
      };

      final response = await http.post(
        Uri.parse("https://www.googleapis.com/geolocation/v1/geolocate?key=$googleGeoLocationAPIKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _wifiEstimatedLocation =
              "Lat: ${data['location']['lat']}, Lng: ${data['location']['lng']}, Accuracy: ${data['accuracy']} meters";
        });
        _markers.add(
          Marker(
            markerId: MarkerId("wifi"),
            position: LatLng(data['location']['lat'], data['location']['lng']),
            infoWindow: InfoWindow(title: "Wi-Fi Estimated Location"),
          ),
        );
      } else {
        setState(() {
          _wifiEstimatedLocation = "Failed to estimate Wi-Fi location: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _wifiEstimatedLocation = "Error estimating Wi-Fi location: $e";
      });
    }
  }

  Future<void> _getCellTowerEstimatedLocation() async {
    try {
      final Map<dynamic, dynamic> cellInfo = await platform.invokeMethod('getCellInfo');
      final List<dynamic> registered = cellInfo['registered'];

      if (registered.isEmpty) {
        setState(() {
          _cellTowerEstimatedLocation = "No cell tower info available for estimation.";
        });
        return;
      }

      final Map<String, dynamic> firstCell = Map<String, dynamic>.from(registered.first);

      final requestData = {
        "cellTowers": [
          {
            "cellId": firstCell['cid'],
            "locationAreaCode": firstCell['type'] == "LTE" ? firstCell['tac'] : firstCell['lac'],
            "mobileCountryCode": firstCell['mcc'],
            "mobileNetworkCode": firstCell['mnc']
          }
        ]
      };

      final response = await http.post(
        Uri.parse("https://www.googleapis.com/geolocation/v1/geolocate?key=$googleGeoLocationAPIKey"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _cellTowerEstimatedLocation =
              "Lat: ${data['location']['lat']}, Lng: ${data['location']['lng']}, Accuracy: ${data['accuracy']} meters";
            _markers.add(
              Marker(
                markerId: MarkerId("cellTower"),
                position: LatLng(data['location']['lat'], data['location']['lng']),
                infoWindow: InfoWindow(title: "Cell Tower Estimated Location"),
              ),
            );
        });
      } else {
        setState(() {
          _cellTowerEstimatedLocation = "Failed to estimate cell tower location: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _cellTowerEstimatedLocation = "Error estimating cell tower location: $e";
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

  void _updateMarkers() {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId("current"),
          position: _initialPosition,
          infoWindow: InfoWindow(title: "Current Location"),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Location Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 400,
                width: double.infinity,
                child: GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: _initialPosition,
                    zoom: 14.0,
                  ),
                  markers: _markers,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _getLocation,
                child: Text("Refresh"),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Current Location", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_currentLocation),
                        SizedBox(height: 10),
                        Text("GPS Location", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_gpsLocation),
                        SizedBox(height: 10),
                        Text("Wi-Fi Estimated Location", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_wifiEstimatedLocation),
                        SizedBox(height: 10),
                        Text("Cell Tower Estimated Location", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_cellTowerEstimatedLocation),
                        SizedBox(height: 10),
                        Text("Wi-Fi Info", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_wifiInfo),
                        SizedBox(height: 10),
                        Text("Registered Cell Tower Info", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_registeredCellInfo),
                        SizedBox(height: 10),
                        Text("Neighboring Cell Tower Info", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_neighboringCellInfo),
                        SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          ),
      ),
    );
  }
}
