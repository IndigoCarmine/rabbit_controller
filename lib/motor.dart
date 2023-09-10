import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usbcan_plugins/usbcan.dart';

enum MotorMode { stop, pwm, current, position, homing }

class Motor {
  final int canBaseId;
  final String discription;

  final MotorMode mode;

  const Motor(this.canBaseId, this.discription, {this.mode = MotorMode.stop});
}

class MotorButton extends StatelessWidget {
  const MotorButton(
      {super.key,
      required this.canSend,
      required this.mode,
      required this.motor});

  final MotorMode mode;
  final Motor motor;
  final void Function(CANFrame) canSend;
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: switch (mode) {
          MotorMode.stop => Colors.red,
          MotorMode.pwm => Colors.grey,
          MotorMode.current => Colors.blue,
          MotorMode.position => Colors.green,
          MotorMode.homing => Colors.yellow,
        }),
        onPressed: () {
          canSend(CANFrame.fromIdAndData(
              motor.canBaseId + 1,
              Uint8List.fromList([
                switch (motor.mode) {
                  MotorMode.stop => 0x00,
                  MotorMode.pwm => 0x01,
                  MotorMode.current => 0x02,
                  MotorMode.position => 0x03,
                  MotorMode.homing => 0x04,
                }
              ])));
        },
        child: Text(motor.discription));
  }
}

class MotorButtonBar extends StatefulWidget {
  const MotorButtonBar(
      {super.key,
      required this.canStream,
      required this.motors,
      required this.canSend});
  final Stream<CANFrame> canStream;
  final void Function(CANFrame) canSend;
  final List<Motor> motors;

  @override
  State<MotorButtonBar> createState() => _MotorButtonBarState();
}

class _MotorButtonBarState extends State<MotorButtonBar> {
  late List<MotorMode> modes;
  @override
  void initState() {
    super.initState();
    modes = List.filled(widget.motors.length, MotorMode.stop);
    widget.canStream.listen((frame) {
      for (var i = 0; i < widget.motors.length; i++) {
        if (frame.canId == widget.motors[i].canBaseId + 2) {
          modes[i] = switch (frame.data[0]) {
            0x00 => MotorMode.stop,
            0x01 => MotorMode.pwm,
            0x02 => MotorMode.current,
            0x03 => MotorMode.position,
            0x04 => MotorMode.homing,
            _ => modes[i],
          };
        }
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        itemBuilder: (context, index) {
          return MotorButton(
              canSend: widget.canSend,
              motor: widget.motors[index],
              mode: modes[index]);
        },
        itemCount: widget.motors.length,
        scrollDirection: Axis.horizontal,
      ),
    );
  }
}
