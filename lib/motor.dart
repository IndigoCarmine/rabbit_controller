import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usbcan_plugins/usbcan.dart';

enum MotorMode {
  stop,
  pwm,
  current,
  position,
  interlockPosition,
  interlockWaiting,
  interlockStop,
}

class Motor {
  final int canBaseId;
  final String discription;
  final int interlockGroupId;
  // true = same direction motor and encoder, false = opposite
  final bool direction;

  final MotorMode mode;

  const Motor(this.canBaseId, this.discription,
      {this.interlockGroupId = 0,
      this.mode = MotorMode.stop,
      this.direction = true});

  void motorActivate(UsbCan usbCan) {
    usbCan.sendFrame(CANFrame.fromIdAndData(
        canBaseId + 1,
        Uint8List.fromList([
          switch (mode) {
            MotorMode.stop => 0x00,
            MotorMode.pwm => 0x01,
            MotorMode.current => 0x02,
            MotorMode.position => 0x03,
            MotorMode.interlockPosition => 0x04,
            MotorMode.interlockWaiting => 0x05,
            MotorMode.interlockStop => 0x06,
          }
        ])));
    if (mode == MotorMode.interlockPosition) {
      usbCan.sendFrame(CANFrame.fromIdAndData(
          canBaseId + 2, Uint8List.fromList([8, interlockGroupId])));
      if (!direction) {
        usbCan.sendFrame(CANFrame.fromIdAndData(
            canBaseId + 2, Uint8List.fromList([9, 0x01])));
      } else {
        usbCan.sendFrame(CANFrame.fromIdAndData(
            canBaseId + 2, Uint8List.fromList([9, 0x00])));
      }
    }
  }
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
          MotorMode.interlockPosition => Colors.yellow,
          MotorMode.interlockWaiting => Colors.orange,
          MotorMode.interlockStop => Colors.red,
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
                  MotorMode.interlockPosition => 0x04,
                  MotorMode.interlockWaiting => 0x05,
                  MotorMode.interlockStop => 0x06,
                }
              ])));
          if (motor.mode == MotorMode.interlockPosition) {
            canSend(CANFrame.fromIdAndData(motor.canBaseId + 2,
                Uint8List.fromList([8, motor.interlockGroupId])));
          }
          if (motor.direction) {
            canSend(CANFrame.fromIdAndData(
                motor.canBaseId + 2, Uint8List.fromList([9, 0x01])));
          } else {
            canSend(CANFrame.fromIdAndData(
                motor.canBaseId + 2, Uint8List.fromList([9, 0x00])));
          }
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
  late StreamSubscription<CANFrame> canSub;
  @override
  void initState() {
    super.initState();
    modes = List.filled(widget.motors.length, MotorMode.stop);
    canSub = widget.canStream.listen((frame) {
      for (var i = 0; i < widget.motors.length; i++) {
        if (frame.canId == widget.motors[i].canBaseId + 2) {
          modes[i] = switch (frame.data[0]) {
            0x00 => MotorMode.stop,
            0x01 => MotorMode.pwm,
            0x02 => MotorMode.current,
            0x03 => MotorMode.position,
            0x04 => MotorMode.interlockPosition,
            0x05 => MotorMode.interlockWaiting,
            0x06 => MotorMode.interlockStop,
            _ => modes[i],
          };
        }
      }

      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Expanded(
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
          ),
          TextButton(
              onPressed: () {
                widget.canSend(
                    CANFrame.fromIdAndData(0x0, Uint8List.fromList([0x0])));
              },
              child: const Text("All Stop"))
        ],
      ),
    );
  }

  @override
  void dispose() {
    canSub.cancel();
    super.dispose();
  }
}
