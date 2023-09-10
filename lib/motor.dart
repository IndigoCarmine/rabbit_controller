import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'mock_usbcan.dart';

enum MotorMode { stop, current, position, homing }

class Motor {
  final int canId;
  final String discription;

  final MotorMode mode;

  const Motor(this.canId, this.discription, {this.mode = MotorMode.stop});
}

class MotorButton extends StatelessWidget {
  const MotorButton(
      {super.key,
      required this.canSend,
      required this.mode,
      required this.motor});

  final MotorMode mode;
  final Motor motor;
  final void Function() canSend;
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: switch (mode) {
          MotorMode.stop => Colors.red,
          MotorMode.current => Colors.blue,
          MotorMode.position => Colors.green,
          MotorMode.homing => Colors.yellow,
        }),
        onPressed: canSend,
        child: Text(motor.discription));
  }
}

class MotorButtonBar extends StatefulWidget {
  const MotorButtonBar(
      {super.key,
      required this.canStream,
      required this.motors,
      required this.canSend});
  final Stream<CanFrame> canStream;
  final void Function(int id, List<int> data) canSend;
  final List<Motor> motors;

  @override
  State<MotorButtonBar> createState() => _MotorButtonBarState();
}

class _MotorButtonBarState extends State<MotorButtonBar> {
  late List<MotorButton> buttons;
  @override
  void initState() {
    buttons = widget.motors
        .map((motor) => MotorButton(
            canSend: () {
              widget.canSend(
                  motor.canId + 1,
                  Uint8List.fromList([
                    switch (motor.mode) {
                      MotorMode.stop => 0x00,
                      MotorMode.current => 0x01,
                      MotorMode.position => 0x02,
                      MotorMode.homing => 0x03,
                    }
                  ]));
            },
            motor: motor,
            mode: motor.mode))
        .toList();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: buttons);
  }
}
