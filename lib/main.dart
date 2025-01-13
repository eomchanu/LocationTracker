import 'dart:convert';
import 'dart:ffi';
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

class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  @override
  String toString() {
    String res = "Lat: $latitude, Lng: $longitude${accuracy != null ? ", Accuracy: $accuracy meters" : ""}";
    return res;
  }
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
  LocationData? _currentLocation;
  LocationData? _gpsLocation;
  LocationData? _wifiEstimatedLocation;
  LocationData? _cellTowerEstimatedLocation;

  double? _distanceFromGPS;
  double? _distanceFromWiFi;
  double? _distanceFromCellTower;

  Set<Circle> _circles = {};

  String _wifiInfo = "Fetching...";
  String _registeredCellInfo = "Fetching...";
  String _neighboringCellInfo = "Fetching...";

  static const platform_gps = MethodChannel('com.eomchanu.location_tracker/gps');
  static const platform_cell = MethodChannel('com.eomchanu.location_tracker/cell');

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

  // 거리차 계산 함수
  double calculateDistance(LocationData from, LocationData to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  void _updateCircles() {
    setState(() {
      _circles.clear(); // 기존 원형 제거
      if (_gpsLocation != null) {
        _circles.add(
          Circle(
            circleId: CircleId("gpsCircle"),
            center: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
            radius: _distanceFromGPS ?? 0, // 정확도 반영
            strokeWidth: 2,
            // fillColor: Colors.green.withOpacity(0.3),
            strokeColor: Colors.green,
          ),
        );
      }
      if (_wifiEstimatedLocation != null) {
        _circles.add(
          Circle(
            circleId: CircleId("wifiCircle"),
            center: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
            radius: _distanceFromWiFi ?? 0,
            strokeWidth: 2,
            // fillColor: Colors.blue.withOpacity(0.3),
            strokeColor: Colors.blue,
          ),
        );
      }
      if (_cellTowerEstimatedLocation != null) {
        _circles.add(
          Circle(
            circleId: CircleId("cellTowerCircle"),
            center: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
            radius: _distanceFromCellTower ?? 0,
            strokeWidth: 2,
            // fillColor: Colors.orange.withOpacity(0.3),
            strokeColor: Colors.orange,
          ),
        );
      }
    });
  }


  // 각각의 거리차 계산 함수
  void _calculateDistances() {
    if (_currentLocation != null) {
      setState(() {
        _distanceFromGPS = _gpsLocation != null
            ? calculateDistance(_currentLocation!, _gpsLocation!)
            : null;

        _distanceFromWiFi = _wifiEstimatedLocation != null
            ? calculateDistance(_currentLocation!, _wifiEstimatedLocation!)
            : null;

        _distanceFromCellTower = _cellTowerEstimatedLocation != null
            ? calculateDistance(_currentLocation!, _cellTowerEstimatedLocation!)
            : null;
      });
    }
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
    _calculateDistances();
    _updateCircles();
  }

  // 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: null
        );
        _initialPosition = LatLng(position.latitude, position.longitude);
      });

      _markers.add(
        Marker(
          markerId: MarkerId("current"),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(title: "Current Location"),
        ),
      );
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_initialPosition),
      );
    } catch (e) {
      setState(() {
        _currentLocation = null;
      });
    }
  }

  // GPS 위치 가져오기
  Future<void> _getGPSLocation() async {
    try {
      final Map<dynamic, dynamic> gpsData =
          await platform_gps.invokeMethod('getGPSLocation');

      setState(() {
        _gpsLocation = LocationData(
          latitude: gpsData['latitude'],
          longitude: gpsData['longitude'],
          accuracy: gpsData['accuracy'],
        );
      });
      
      _markers.add(
        Marker(
          markerId: MarkerId("gps"),
          position: LatLng(gpsData['latitude'], gpsData['longitude']),
          infoWindow: InfoWindow(title: "GPS Location"),
        ),
      );
    } on PlatformException {
      setState(() {
        _gpsLocation = null;
      });
    }
  }

  // Wi-Fi 기반 위치 추정
  Future<void> _getWiFiEstimatedLocation() async {
    try {
      String? wifiBSSID = await _networkInfo.getWifiBSSID();
      if (wifiBSSID == null || wifiBSSID.isEmpty) return;

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
        final data = jsonDecode(response.body);
        _wifiEstimatedLocation = LocationData(
          latitude: data['location']['lat'],
          longitude: data['location']['lng'],
          accuracy: data['accuracy'],
        );

        _markers.add(
          Marker(
            markerId: MarkerId("wifi"),
            position: LatLng(data['location']['lat'], data['location']['lng']),
            infoWindow: InfoWindow(title: "Wi-Fi Estimated Location"),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _wifiEstimatedLocation = null;
      });
    }
  }

  // 기지국 기반 위치 추정
  Future<void> _getCellTowerEstimatedLocation() async {
    try {
      final Map<dynamic, dynamic> cellInfo = await platform_cell.invokeMethod('getCellInfo');
      final List<dynamic> registered = cellInfo['registered'];
      if (registered.isEmpty) return;

      final Map<String, dynamic> registeredCellTower = Map<String, dynamic>.from(registered.first);

      final url = "https://opencellid.org/cell/get";
      final queryParams = {
        "format": "json",
        "key": openCellIdAPIKey,
        "mcc": registeredCellTower['mcc'].toString(),
        "mnc": registeredCellTower['mnc'].toString(),
        "lac": registeredCellTower[registeredCellTower['type'] == "LTE" ? 'tac' : 'lac'].toString(),
        "cellid": registeredCellTower['cid'].toString(),
        "radio": registeredCellTower['type'].toString(),
      };
      
      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cellTowerEstimatedLocation = LocationData(
          latitude: data['lat'],
          longitude: data['lon'],
          accuracy: (data['range'] as num).toDouble(),
        );

        _markers.add(
          Marker(
            markerId: MarkerId("cellTower"),
            position: LatLng(data['lat'], data['lon']),
            infoWindow: InfoWindow(title: "Cell Tower Estimated Location"),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _cellTowerEstimatedLocation = null;
        print(e);
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
      final Map<dynamic, dynamic> cellInfo = await platform_cell.invokeMethod('getCellInfo');
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

  // MARK: UI
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
                  circles: _circles,
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
                        Text(_currentLocation != null ? _currentLocation.toString() : "fetching..."),
                        SizedBox(height: 10),
                        Text("Distances from Current Location", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("GPS: ${_distanceFromGPS != null ? "${_distanceFromGPS!.toStringAsFixed(2)} meters" : "Not available"}", style: TextStyle(color: Colors.green)),
                        Text("Wi-Fi: ${_distanceFromWiFi != null ? "${_distanceFromWiFi!.toStringAsFixed(2)} meters" : "Not available"}", style: TextStyle(color: Colors.blue)),
                        Text("Cell Tower: ${_distanceFromCellTower != null ? "${_distanceFromCellTower!.toStringAsFixed(2)} meters" : "Not available"}", style: TextStyle(color: Colors.orange)),
                        SizedBox(height: 10),
                        Text("GPS Location", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_gpsLocation != null ? _gpsLocation.toString() : "fetching..."),
                        SizedBox(height: 10),
                        Text("Wi-Fi Estimated Location", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_wifiEstimatedLocation != null ? _wifiEstimatedLocation.toString() : "fetching..."),
                        SizedBox(height: 10),
                        Text("Cell Tower Estimated Location", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_cellTowerEstimatedLocation != null ? _cellTowerEstimatedLocation.toString() : "fetching..."),
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
