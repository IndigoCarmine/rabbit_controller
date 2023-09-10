import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rabbit_controller/controller_page.dart';
import 'package:usbcan_plugins/usbcan.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Material App',
      home: DefaultTabController(
        length: 1,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Material App Bar'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.contact_phone)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              const MainPage(),
            ],
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  UsbCan usbCan = UsbCan();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
            onPressed: () async {
              if (!await usbCan.connectUSB()) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("No USB"),
                    ),
                  );
                }
                return;
              }
              var startTime = DateTime.now();
              Uint8List data = const AsciiEncoder().convert("HelloUSBCAN");
              while (DateTime.now().difference(startTime).inSeconds < 5) {
                await usbCan.sendCommand(
                    Command.establishmentOfCommunication, data);
                await Future.delayed(const Duration(milliseconds: 100));

                if (usbCan.connectionEstablished) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Connected"),
                      ),
                    );
                  }
                  return;
                }
              }
              if (mounted && !usbCan.connectionEstablished) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Timeout"),
                  ),
                );
              }
            },
            child: const Text("Connect")),
        TextButton(
          child: const Text("Start"),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ControllerPage(usbCan: usbCan),
              ),
            );
          },
        ),
        StreamBuilder(
            stream: usbCan.stream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text(snapshot.data.toString());
              } else {
                return const Text("No Data");
              }
            }),
      ],
    );
  }
}
