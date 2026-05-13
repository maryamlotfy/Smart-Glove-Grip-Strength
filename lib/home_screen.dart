import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'; // المكتبة
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// اسم جهاز البلوتوث الخاص بالأردوينو (تأكدي منه)
const String arduinoBluetoothName = 'HC-05';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // متغيرات حالة البلوتوث
  BluetoothConnection? connection;
  bool isConnecting = false;
  bool isConnected = false;
  String connectionStatus = 'Not Connected';

  // متغيرات البيانات والرسم البياني
  double currentGripValue = 0.0;
  String gripMessage = 'Connecting...';
  List<FlSpot> chartData = [];
  final int maxChartPoints = 50;

  // المخزن المؤقت للبيانات المستلمة
  String _dataBuffer = "";

  @override
  void initState() {
    super.initState();
    _checkBluetoothStateAndConnect(); // make sour of bluetooth status and don't chang every time
  }

  @override
  void dispose() {
    // إغلاق الاتصال عند مغادرة الشاشة
    if (isConnected) {
      connection?.dispose();
      connection = null;
    }
    super.dispose();
  }

  // دالة للتحقق من حالة البلوتوث وبدء الاتصال
  void _checkBluetoothStateAndConnect() async {
    // التأكد من تفعيل البلوتوث
    BluetoothState bluetoothState = await FlutterBluetoothSerial.instance.state;
    if (bluetoothState == BluetoothState.STATE_OFF) {
      setState(() {
        connectionStatus = 'Bluetooth OFF. Please turn ON.';
        gripMessage = 'Bluetooth is OFF.';
      });
      // allow user to directly open settings
      await FlutterBluetoothSerial.instance.requestEnable();
    } else {
      _startConnectionProcess();
    }
    // bluetooth changing status updates
    FlutterBluetoothSerial.instance.onStateChanged().listen((BluetoothState state) {
      if (state == BluetoothState.STATE_ON) {
        _startConnectionProcess();
      } else {
        setState(() {
          isConnected = false;
          connectionStatus = 'Bluetooth OFF / Disconnected';
          gripMessage = 'Bluetooth is OFF.';
        });
      }
    });
  }

  // start connecting process
  void _startConnectionProcess() async {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Scanning for devices...';
      gripMessage = 'Scanning...';
    });

    // looking for paired devices
    List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
    BluetoothDevice? targetDevice = bondedDevices.firstWhereOrNull(
          (device) => device.name == arduinoBluetoothName,
    );

    if (targetDevice != null) {
      _connectToDevice(targetDevice);
    } else {
      setState(() {
        connectionStatus = 'Device not found among bonded. Please pair it manually.';
        gripMessage = 'Device not paired.';
      });
      // open bluetooth settings so user can connect manually
      await FlutterBluetoothSerial.instance.openSettings();
    }
  }

  // try directly connecting
  void _bondAndConnectDevice(BluetoothDevice device) async {
    _connectToDevice(device);
  }

  // connecting to bluetooth device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connecting to ${device.name}...';
      gripMessage = 'Connecting...';
    });
    try {
      connection = await BluetoothConnection.toAddress(device.address);
      setState(() {
        isConnected = true;
        isConnecting = false;
        connectionStatus = 'Connected to ${device.name}';
        gripMessage = 'Connected. Waiting for data...';
      });

      // start collecting data/values
      connection!.input?.listen(_onDataReceived).onDone(() {
        setState(() {
          isConnected = false;
          connectionStatus = 'Disconnected by remote device.';
          gripMessage = 'Disconnected.';
        });
        _startConnectionProcess(); // محاولة إعادة الاتصال تلقائيًا
      });
    } catch (e) {
      setState(() {
        isConnecting = false;
        isConnected = false;
        connectionStatus = 'Failed to connect: $e';
        gripMessage = 'Connection failed.';
      });
      print('Cannot connect, exception: $e');
      _startConnectionProcess(); // try reconnecting
    }
  }

  // دالة لمعالجة البيانات المستلمة
  void _onDataReceived(Uint8List data) {
    // تحويل البايتات إلى نص
    _dataBuffer += utf8.decode(data);

    // معالجة البيانات سطر بسطر (لأن الأردوينو بيبعت println)
    int newlineIndex = _dataBuffer.indexOf('\n');
    while (newlineIndex >= 0) {
      String fullLine = _dataBuffer.substring(0, newlineIndex).trim();
      _dataBuffer = _dataBuffer.substring(newlineIndex + 1);

      if (fullLine.isNotEmpty) {
        _processGripData(fullLine);
      }
      newlineIndex = _dataBuffer.indexOf('\n');
    }
  }

  // دالة لمعالجة قيم قوة القبضة المستلمة
  void _processGripData(String data) {
    try {
      final List<String> stringValues = data.split(',');
      if (stringValues.isNotEmpty) {
        // حاول التحويل إلى رقم، ولو فشل، استخدم القيمة 0.0
        double value = double.tryParse(stringValues[0].trim()) ?? 0.0;

        // التأكد من أن القيمة ضمن نطاق معقول قبل تحديث UI
        // بما أن الحساس بيطلع قيم لحد 1023، ونطاق بياناتك كان لحد 265،
        // هنستخدم 0-300 كحد أقصى للرسم البياني
        if (value < 0 || value > 1023) { // افترضي ان الـ raw value من 0 لـ 1023
          print('Received out of range value: $value');
          // لا تحدثي الـ UI بقيم غير صالحة
          return;
        }

        setState(() {
          currentGripValue = value;

          // ****** تم عكس المنطق هنا بناءً على ملاحظتك ******
          // لو القبضة الجيدة تعطي قيمة أقل من 50 (قيمة تجريبية بناءً على بياناتك 3,8,15)
          if (currentGripValue < 50 && currentGripValue > 0) { // أضفنا > 0 لتجنب القيم الصفرية غير المعبرة
            gripMessage = 'The hand grip is good';
          } else {
            gripMessage = 'The hand grip is not good';
          }

          if (chartData.length >= maxChartPoints) {
            chartData.removeAt(0);
          }
          chartData.add(FlSpot(chartData.length.toDouble(), currentGripValue));
        });
      }
    } catch (e) {
      // طباعة الخطأ بدل الانهيار
      print('Error parsing data in _processGripData: $e. Data was: "$data"');
      // يمكنك تحديث حالة الاتصال لإظهار مشكلة مؤقتة
      setState(() {
        connectionStatus = 'Data error: Check Arduino output.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SmartGlove',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // فصل الاتصال الحالي وإعادة بدء العملية
              connection?.dispose();
              connection = null;
              isConnected = false;
              isConnecting = false;
              _checkBluetoothStateAndConnect();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
            onPressed: () async {
              // فتح إعدادات البلوتوث للسماح للمستخدم بالاقتران يدويًا
              await FlutterBluetoothSerial.instance.openSettings();
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            // Header Section: Profile and Greeting
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.teal[200],
                    child: const Icon(Icons.person, size: 30, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Hi Ahmad,',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Icon(Icons.waving_hand, size: 30, color: Colors.amber[700]),
                ],
              ),
            ),

            // Connection Status Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green[400] : (isConnecting ? Colors.blue[400] : Colors.orange[400]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  connectionStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Grip Strength Message
            Text(
              gripMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: gripMessage.contains('not good')
                    ? Colors.red[700]
                    : (gripMessage.contains('good') ? Colors.green[700] : Colors.blueGrey[700]),
              ),
            ),

            const SizedBox(height: 30),

            // Chart Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (value) {
                          return const FlLine(
                            color: Color(0xff37434d),
                            strokeWidth: 0.8,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return const FlLine(
                            color: Color(0xff37434d),
                            strokeWidth: 0.8,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0: return const Text('نقطة 1', style: TextStyle(color: Colors.black, fontSize: 10));
                                case 10: return const Text('نقطة 2', style: TextStyle(color: Colors.black, fontSize: 10));
                                case 20: return const Text('نقطة 3', style: TextStyle(color: Colors.black, fontSize: 10));
                                case 30: return const Text('نقطة 4', style: TextStyle(color: Colors.black, fontSize: 10));
                                case 40: return const Text('نقطة 5', style: TextStyle(color: Colors.black, fontSize: 10));
                                default: return const Text('');
                              }
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: const Color(0xff37434d), width: 1),
                      ),
                      minX: 0,
                      maxX: maxChartPoints.toDouble() - 1,
                      minY: 0, // ****** تم التعديل هنا ******
                      maxY: 300, // ****** تم التعديل هنا بناءً على بياناتك ******
                      lineBarsData: [
                        LineChartBarData(
                          spots: chartData,
                          isCurved: true,
                          color: Colors.teal,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.teal.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (T element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
