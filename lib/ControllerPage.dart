import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:usbcan_plugins/usbcan.dart';
import 'motor.dart';

class ControllerPage extends StatefulWidget {
  const ControllerPage({
    super.key,
    required this.usbCan,
  });

  final UsbCan usbCan;
  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> {
  List<MotorButton> buttons = [];
  Timer? carriageTimer;
  Timer? liftTimer;
  Point<double> carriageMove = const Point(0, 0);
  double carriageRotate = 0;
  double lastLifeHeight = 0;

  final List<Motor> motors = const [
    Motor(0x0 << 1, "Front Left", mode: MotorMode.current),
    Motor(0x01 << 1, "Front Right", mode: MotorMode.current),
    Motor(0x02 << 1, "Rear Left", mode: MotorMode.current),
    Motor(0x03 << 1, "Rear Right", mode: MotorMode.current),
    Motor(0x04 << 1, "Lift 1", mode: MotorMode.position),
    Motor(0x05 << 1, "Lift 2", mode: MotorMode.position),
  ];

  final double carriageSpeedScale = 0.5;
  final double carriageRotateScale = 0.5;

  @override
  void initState() {
    //freezed display rotation to portrait.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    carriageTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      //mecanum wheel calculation
      var x = carriageMove.x * carriageSpeedScale;
      var y = carriageMove.y * carriageSpeedScale;
      var r = carriageRotate * carriageRotateScale;
      //Front Left
      widget.usbCan.sendFrame(
          CANFrame.fromIdAndData(motors[0].canBaseId, _toUint8List(x + y + r)));
      //Front Right
      widget.usbCan.sendFrame(CANFrame.fromIdAndData(
          motors[1].canBaseId, _toUint8List(-x + y - r)));
      //Rear Left
      widget.usbCan.sendFrame(
          CANFrame.fromIdAndData(motors[2].canBaseId, _toUint8List(x - y + r)));
      //Rear Right
      widget.usbCan.sendFrame(CANFrame.fromIdAndData(
          motors[3].canBaseId, _toUint8List(-x - y - r)));
    });

    super.initState();
  }

  Uint8List _toUint8List(double value) {
    var buffer = Float32List(1);
    buffer[0] = value;
    return buffer.buffer.asUint8List(0, 4);
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);
    carriageTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Joystick(listener: (detail) {
              carriageMove = Point(detail.x, detail.y);
            }),
            Joystick(listener: (detail) {}, mode: JoystickMode.vertical),
            Joystick(
              listener: (detail) {
                carriageRotate = detail.x;
              },
              mode: JoystickMode.horizontal,
            ),
          ],
        ),
        const Spacer(),
        MotorButtonBar(
            canStream: widget.usbCan.stream,
            motors: motors,
            canSend: widget.usbCan.sendFrame),
        const Spacer(),
      ],
    );
  }
}
