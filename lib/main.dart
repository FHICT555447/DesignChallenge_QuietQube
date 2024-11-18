import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
// import 'login.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

Future<Noise> fetchNoise(apiURI) async {
  final response = await http.get(Uri.parse(apiURI));

  if (response.statusCode == 200) {
    List<dynamic> jsonResponse = jsonDecode(response.body) as List<dynamic>;
    return Noise.fromJson(jsonResponse);
  } else {
    throw Exception('Failed to load noise data');
  }
}

Future<Noise> fetchLiveNoise(apiURI) async {
  final response = await http.get(Uri.parse(apiURI));

  if (response.statusCode == 200) {
    Map<String, dynamic> jsonResponse =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Noise.fromLiveJson(jsonResponse);
  } else {
    throw Exception('Failed to load live noise data');
  }
}

class Noise {
  final List<double> decibels;

  const Noise({
    required this.decibels,
  });

  factory Noise.fromJson(List<dynamic> json) {
    List<double> decibels = json.map((value) {
      double decibel;
      if (value is int) {
        decibel = value.toDouble();
      } else if (value is double) {
        decibel = value;
      } else {
        throw Exception('Unexpected value type');
      }
      return double.parse(decibel.toStringAsFixed(1));
    }).toList();

    return Noise(decibels: decibels);
  }

  factory Noise.fromLiveJson(Map<String, dynamic> json) {
    double decibel = json['avg_decibel'];
    return Noise(decibels: [double.parse(decibel.toStringAsFixed(1))]);
  }
}

Future<Status> fetchStatus() async {
  final response = await http
      .get(Uri.parse('http://192.168.156.10:4321/api/system-mode/class-1'));

  if (response.statusCode == 200) {
    print("Response: ${response.body}");
    return Status.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load status data');
  }
}

class Status {
  final bool toggle;

  const Status({
    required this.toggle,
  });

  factory Status.fromJson(Map<String, dynamic> json) {
    return Status(toggle: json['toggle']);
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuietQube Manager',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromRGBO(0, 210, 219, 85)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'QuietQube Manager'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isPowerOn = false;
  bool _isConnected = false;
  Color _buttonColor = Colors.grey;
  double _buttonOpacity = 0.5;
  double _boxShadowOpacity = 0.5;
  Timer? _statusTimer;
  double _currentDecibels = 0.0;
  List<FlSpot> _minuteNoiseDataSpots = [];
  List<FlSpot> _hourlyNoiseDataSpots = [];
  bool _showMinuteGraph = true;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _startStatusCheck();
    _getLiveNoise();
    _fetchMinuteNoiseData();
    _fetchHourlyNoiseData();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startStatusCheck() {
    _statusTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      print('Timer executed');
      _fetchStatus();
      _getLiveNoise();
      _fetchMinuteNoiseData();
      _fetchHourlyNoiseData();
    });
  }

  Future<void> _fetchStatus() async {
    try {
      Status status = await fetchStatus();
      setState(() {
        _isConnected = true;
        _isPowerOn = status.toggle;
        _buttonColor = _isPowerOn ? Colors.green : Colors.red;
        _buttonOpacity = 1.0;
        _boxShadowOpacity = 1.0;
      });
    } catch (e) {
      print('Error fetching status: $e');
      setState(() {
        _isConnected = false;
        _buttonColor = Colors.grey;
        _buttonOpacity = 0.5;
        _boxShadowOpacity = 0.5;
      });
    }
  }

  Future<void> _togglePower(bool powerOn) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.156.10:4321/api/system-mode/class-1'),
        body: jsonEncode({'toggle': !powerOn}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 201) {
        setState(() {
          _isPowerOn = !powerOn;
          _buttonColor = _isPowerOn ? Colors.green : Colors.red;
        });
      } else {
        throw Exception('Failed to toggle power ${response.statusCode}');
      }
    } catch (e) {
      print('Error toggling power: $e');
    }
  }

  Future<void> _getLiveNoise() async {
    try {
      Noise noise = await fetchLiveNoise(
          'http://192.168.156.10:4321/api/current/class-1');
      setState(() {
        _currentDecibels = noise.decibels.last;
      });
    } catch (e) {
      print('Error fetching live noise: $e');
      setState(() {
        _currentDecibels = 0.0;
      });
    }
  }

  Future<void> _fetchMinuteNoiseData() async {
    try {
      Noise noise = await fetchNoise(
          'http://192.168.156.10:4321/api/minute-noise-data/class-1');
      setState(() {
        List<double> last30Decibels = noise.decibels.length > 30
            ? noise.decibels.sublist(noise.decibels.length - 30)
            : noise.decibels;
        last30Decibels = last30Decibels.reversed.toList();
        _minuteNoiseDataSpots = last30Decibels
            .asMap()
            .entries
            .map((entry) => FlSpot(
                entry.key.toDouble() + 1, entry.value < 0 ? 0 : entry.value))
            .toList();
      });
    } catch (e) {
      print('Error fetching minute noise data: $e');
    }
  }

  Future<void> _fetchHourlyNoiseData() async {
    try {
      Noise noise = await fetchNoise(
          'http://192.168.156.10:4321/api/hourly-noise-data/class-1?hours=24');
      setState(() {
        _hourlyNoiseDataSpots = noise.decibels
            .asMap()
            .entries
            .map((entry) => FlSpot(
                entry.key.toDouble() + 1, entry.value < 0 ? 0 : entry.value))
            .toList();
      });
    } catch (e) {
      print('Error fetching hourly noise data: $e');
    }
  }

  void _toggleGraph(bool showMinuteGraph) {
    setState(() {
      _showMinuteGraph = showMinuteGraph;
    });
  }

  void _powerButtonPress() {
    if (_isConnected) {
      _togglePower(_isPowerOn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(85.0), // Set the desired height
          child: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            flexibleSpace: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                // Positioned(
                //   top: 40.0,
                //   right: 16.0,
                //   child: FloatingActionButton(
                //     heroTag: 'loginButton', // Add this line
                //     onPressed: () {
                //       print(context);
                //       Navigator.push(
                //         context,
                //         MaterialPageRoute(builder: (context) {
                //           return LoginPage(
                //             title: "Login Page",
                //           );
                //         }),
                //       );
                //       print(context);
                //     },
                //     tooltip: 'Login',
                //     mini: false, // Use mini to make the button smaller
                //     child: const Icon(Icons.account_box_rounded),
                //   ),
                // ),
              ],
            ),
          ),
        ),
        body: Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                    width: 350,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.secondary,
                          blurRadius: 10.0,
                          spreadRadius: 5.0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SingleChildScrollView(
                        child: Container(
                          width: 350,
                          height: 675,
                          decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            children: [
                              Padding(
                                  padding: const EdgeInsets.only(top: 20.0),
                                  child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Column(children: [
                                        Text('QuietQube #1',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium),
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                top: 20.0)),
                                      ]))),
                              Text(
                                  'Current dB Level: ${_currentDecibels.toStringAsFixed(1)}dB',
                                  style: Theme.of(context).textTheme.bodyLarge),
                              Text(
                                  _showMinuteGraph
                                      ? 'Minute Average:'
                                      : 'Hourly Average:',
                                  style: Theme.of(context).textTheme.bodyLarge),
                              Padding(
                                  padding: const EdgeInsets.only(right: 30.0),
                                  child: SizedBox(
                                      width: 400,
                                      height: 375,
                                      child: (_showMinuteGraph
                                                  ? _minuteNoiseDataSpots
                                                  : _hourlyNoiseDataSpots)
                                              .isEmpty
                                          ? CircularProgressIndicator()
                                          : LineChart(
                                              LineChartData(
                                                  minY: 0,
                                                  maxY: 100,
                                                  lineBarsData: [
                                                    LineChartBarData(
                                                      spots: _showMinuteGraph
                                                          ? _minuteNoiseDataSpots
                                                          : _hourlyNoiseDataSpots,
                                                      isCurved: true,
                                                      gradient:
                                                          const LinearGradient(
                                                              colors: [
                                                            Colors.lightBlue,
                                                            Colors.deepPurple,
                                                          ],
                                                              begin: Alignment
                                                                  .bottomCenter,
                                                              end: Alignment
                                                                  .topCenter),
                                                      preventCurveOverShooting:
                                                          true,
                                                    )
                                                  ],
                                                  titlesData: FlTitlesData(
                                                      show: true,
                                                      leftTitles: AxisTitles(
                                                          axisNameWidget: Text(
                                                              "Average Noise Levels (dB)"),
                                                          axisNameSize: 17,
                                                          sideTitles: SideTitles(
                                                              showTitles: true,
                                                              reservedSize:
                                                                  35)),
                                                      bottomTitles: AxisTitles(
                                                          axisNameWidget: Text(
                                                              _showMinuteGraph
                                                                  ? "Time Period (Minutes)"
                                                                  : "Time Period (Hours)"),
                                                          sideTitles:
                                                              SideTitles(
                                                                  showTitles:
                                                                      true,
                                                                  reservedSize:
                                                                      30)),
                                                      rightTitles: AxisTitles(
                                                          sideTitles:
                                                              SideTitles(
                                                                  showTitles:
                                                                      false)),
                                                      topTitles: AxisTitles(
                                                          sideTitles:
                                                              SideTitles(
                                                                  showTitles:
                                                                      false)))),
                                            ))),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _toggleGraph(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _showMinuteGraph
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : null,
                                      ),
                                      child: Text('Last 30 Minutes', style: TextStyle(color: _showMinuteGraph ? Colors.white : Colors.black)),
                                    ),
                                    SizedBox(width: 10),
                                    ElevatedButton(
                                      onPressed: () => _toggleGraph(false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: !_showMinuteGraph
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : null,
                                      ),
                                      child: Text('Last 24 Hours', style: TextStyle(color: !_showMinuteGraph ? Colors.white : Theme.of(context).colorScheme.primary)),
                                    ),
                                  ],
                              ),
                              Padding(
                                  padding: const EdgeInsets.only(top: 20.0)),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                            color: _buttonColor
                                                .withOpacity(_boxShadowOpacity),
                                            blurRadius: 20.0,
                                            spreadRadius: 0.2,
                                          ),
                                        ],
                                      ),
                                      child: Opacity(
                                        opacity: _buttonOpacity,
                                        child: FloatingActionButton.large(
                                          onPressed: _isConnected
                                              ? _powerButtonPress
                                              : null,
                                          child: Icon(
                                            Icons.power_settings_new,
                                            color: _buttonColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ])
                            ],
                          ),
                        ),
                      ),
                    )))));
  }
}
