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

enum HomingState {
  none,
  lift,
  liftDone,
  arm,
  armDone,
}

class _ControllerPageState extends State<ControllerPage> {
  List<MotorButton> buttons = [];
  late StreamSubscription<CANFrame> canSub;
  Point<double> carriageMove = const Point(0, 0);
  double carriageRotate = 0;
  final double carriageRotateScale = 5000;
  final double carriageSpeedScale = 5000;
  late Timer carriageTimer;
  HomingState homingState = HomingState.none;
  double lastLifeHeight = 0;
  Point<double> liftMove = const Point(0, 0);
  final double liftSpeedScale = 500000;
  late Timer liftTimer;
  List<double> motorPositions = List.filled(6, 0);
  final List<Motor> motors = const [
    Motor(0x01 << 2, "Front Left", mode: MotorMode.position),
    Motor(0x02 << 2, "Front Right", mode: MotorMode.position),
    Motor(0x03 << 2, "Rear Left", mode: MotorMode.position, direction: false),
    Motor(0x04 << 2, "Rear Right", mode: MotorMode.position, direction: false),
    Motor(
      0x05 << 2,
      "Lift 1",
      mode: MotorMode.interlockPosition,
      interlockGroupId: 1,
      direction: false,
    ),
    Motor(
      0x06 << 2,
      "Lift 2",
      mode: MotorMode.interlockPosition,
      interlockGroupId: 1,
      direction: false,
    ),
  ];

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);
    carriageTimer.cancel();
    liftTimer.cancel();
    canSub.cancel();
  }

  void _sendTaget(Motor motor, double target) {
    widget.usbCan.sendFrame(
        CANFrame.fromIdAndData(motor.canBaseId, _toUint8List(target)));
  }

  @override
  void initState() {
    super.initState();
    //freezed display rotation to portrait.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    //for checking lift and arm homing mode
    canSub = widget.usbCan.stream.listen((event) {
      print(event.canId.toString());
      if (event.canId == 0x01) {
        if (homingState == HomingState.lift) {
          homingState = HomingState.liftDone;
        }
        if (homingState == HomingState.arm) {
          homingState = HomingState.armDone;
        }
      }
      if (mounted) setState(() {});
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
      _sendTaget(motors[0], motorPositions[0]);
      //Front Right
      motorPositions[1] += x + y + r;
      _sendTaget(motors[1], motorPositions[1]);
      //Rear Left
      motorPositions[2] += x + y - r;
      _sendTaget(motors[2], motorPositions[2]);
      //Rear Right
      motorPositions[3] += x - y - r;
      _sendTaget(motors[3], motorPositions[3]);

      carriageMove = const Point(0, 0);
      carriageRotate = 0;
    });
    liftTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (liftMove.x == 0 && liftMove.y == 0) {
        return;
      }
      //mecanum wheel calculation
      var x = liftMove.x * liftSpeedScale;
      var y = -liftMove.y * liftSpeedScale;

      //Lift 1
      motorPositions[4] += x + y;
      _sendTaget(motors[4], motorPositions[4]);
      //Lift 2
      motorPositions[5] += x - y;
      _sendTaget(motors[5], motorPositions[5]);
      liftMove = const Point(0, 0);
    });
  }

  Uint8List _toUint8List(double value) {
    var buffer = Float32List(1);
    buffer[0] = value;
    return buffer.buffer.asUint8List(0, 4);
  }

  void _liftReset() {
    //stop lift
    widget.usbCan.sendFrame(CANFrame.fromIdAndData(
        motors[4].canBaseId + 1, Uint8List.fromList([0])));
    widget.usbCan.sendFrame(CANFrame.fromIdAndData(
        motors[5].canBaseId + 1, Uint8List.fromList([0])));

    //lift up
    motors[4].motorActivate(widget.usbCan);
    motors[5].motorActivate(widget.usbCan);
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
            Joystick(listener: (detail) {
              liftMove = Point(detail.x, detail.y);
            }),
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
                  homingState = HomingState.none;
                  setState(() {});
                },
                child: const Text("Reset")),
            TextButton(
                onPressed: () async {
                  if (homingState != HomingState.none) {
                    return;
                  }

                  _liftReset();

                  double liftDirection = 1;
                  double liftScale = 500;
                  double liftHeight = 0;
                  homingState = HomingState.lift;
                  while (homingState == HomingState.lift) {
                    await Future.delayed(const Duration(milliseconds: 10));
                    liftHeight += liftDirection * liftScale;
                    _sendTaget(motors[4], liftHeight);
                    _sendTaget(motors[5], -liftHeight);
                  }

                  _liftReset();

                  _sendTaget(motors[4], -10000 * liftDirection);
                  _sendTaget(motors[5], 10000 * liftDirection);

                  _liftReset();

                  double armDirection = 1;
                  double armScale = 500;
                  double armHeight = 0;
                  homingState = HomingState.arm;
                  while (homingState == HomingState.arm) {
                    await Future.delayed(const Duration(milliseconds: 100));
                    armHeight += armDirection * armScale;
                    widget.usbCan.sendFrame(CANFrame.fromIdAndData(
                        motors[4].canBaseId, _toUint8List(armHeight)));
                    widget.usbCan.sendFrame(CANFrame.fromIdAndData(
                        motors[5].canBaseId, _toUint8List(-armHeight)));
                  }

                  _liftReset();
                  widget.usbCan.sendFrame(CANFrame.fromIdAndData(
                      motors[4].canBaseId,
                      _toUint8List(-10000 * armDirection)));
                  widget.usbCan.sendFrame(CANFrame.fromIdAndData(
                      motors[5].canBaseId, _toUint8List(10000 * armDirection)));

                  _liftReset();

                  print("Homing Done");
                  homingState = HomingState.none;
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
