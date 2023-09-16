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
  Point<double> liftMove = const Point(0, 0);
  double carriageRotate = 0;
  double lastLifeHeight = 0;

  final List<Motor> motors = const [
    Motor(0x01 << 2, "Front Left", mode: MotorMode.position),
    Motor(0x02 << 2, "Front Right", mode: MotorMode.position),
    Motor(0x3F << 2, "Rear Left", mode: MotorMode.position),
    Motor(0x04 << 2, "Rear Right", mode: MotorMode.position),
    Motor(0x05 << 2, "Lift 1",
        mode: MotorMode.interlockPosition, interlockGroupId: 1),
    Motor(0x06 << 2, "Lift 2",
        mode: MotorMode.interlockPosition, interlockGroupId: 1),
  ];
  List<double> motorPositions = List.filled(6, 0);

  final double carriageSpeedScale = 5000;
  final double carriageRotateScale = 5000;

  int HomingState = 0;
  late StreamSubscription<CANFrame> canSub;
  @override
  void initState() {
    super.initState();
    //freezed display rotation to portrait.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    canSub = widget.usbCan.stream.listen((event) {
      print(event.canId.toString());
      if (event.canId == 0x01) {
        HomingState++;
      }
    });

    carriageTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (carriageMove.x == 0 && carriageMove.y == 0 && carriageRotate == 0) {
        return;
      }
      //mecanum wheel calculation
      var x = carriageMove.x * carriageSpeedScale;
      var y = carriageMove.y * carriageSpeedScale;
      var r = carriageRotate * carriageRotateScale;
      // print("$motorPositions[2]");
      //Front Left
      motorPositions[0] += x - y + r;
      widget.usbCan.sendFrame(CANFrame.fromIdAndData(
          motors[0].canBaseId, _toUint8List(motorPositions[0])));
      //Front Right
      motorPositions[1] += x + y + r;
      widget.usbCan.sendFrame(CANFrame.fromIdAndData(
          motors[1].canBaseId, _toUint8List(motorPositions[1])));
      //Rear Left
      motorPositions[2] += x + y - r;
      widget.usbCan.sendFrame(CANFrame.fromIdAndData(
          motors[2].canBaseId, _toUint8List(motorPositions[2])));
      //Rear Right
      motorPositions[3] += x - y - r;
      widget.usbCan.sendFrame(CANFrame.fromIdAndData(
          motors[3].canBaseId, _toUint8List(motorPositions[3])));

      carriageMove = const Point(0, 0);
      carriageRotate = 0;
    });
    // liftTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {});
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Joystick(listener: (detail) {
              carriageMove = Point(detail.x, detail.y);
            }),
            const Spacer(),
            Joystick(listener: (detail) {}),
            const Spacer(),
            Joystick(
              listener: (detail) {
                carriageRotate = detail.x;
              },
              mode: JoystickMode.horizontal,
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            TextButton(
                onPressed: () {
                  motorPositions = List.filled(6, 0);
                  HomingState = 0;
                  setState(() {});
                },
                child: const Text("Reset")),
            TextButton(
                onPressed: () async {
                  if (HomingState != 0) {
                    return;
                  }
                  double height = 1000000;
                  HomingState = 1;
                  while (HomingState == 1) {
                    await Future.delayed(const Duration(milliseconds: 100));
                    widget.usbCan.sendFrame(CANFrame.fromIdAndData(
                        motors[4].canBaseId, _toUint8List(height)));
                    widget.usbCan.sendFrame(CANFrame.fromIdAndData(
                        motors[5].canBaseId, _toUint8List(height)));
                  }
                  double width = 1000000;

                  while (HomingState == 2) {
                    await Future.delayed(const Duration(milliseconds: 100));
                    widget.usbCan.sendFrame(CANFrame.fromIdAndData(
                        motors[4].canBaseId, _toUint8List(width)));
                    widget.usbCan.sendFrame(CANFrame.fromIdAndData(
                        motors[5].canBaseId, _toUint8List(width)));
                  }
                  HomingState = 0;
                  print("Homing Done");
                },
                child: const Text("Homing")),
          ],
        ),
        MotorButtonBar(
            canStream: widget.usbCan.stream,
            motors: motors,
            canSend: widget.usbCan.sendFrame),
        const Spacer(),
      ],
    );
  }
}
