import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../app/app_entry.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller =
        VideoPlayerController.asset('assets/splash/barcode.mp4')
          ..initialize().then((_) {
            setState(() {});
            _controller.play();
          });

    _controller.addListener(() {
      if (_controller.value.isInitialized &&
          _controller.value.position >= _controller.value.duration &&
          !_controller.value.isPlaying &&
          !_navigated) {
        _navigated = true;
        _goNext();
      }
    });
  }

  Future<void> _goNext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
     // final hasSeen = prefs.getBool('hasSeenGetStarted') ?? false;
      if (!mounted) return;

      // if (!hasSeen) {
      //   Navigator.pushAndRemoveUntil(
      //     context,
      //     MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      //     (route) => false,
      //   );
      // } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AppEntry()),
          (route) => false,
        );
     // }
    } catch (e) {
      log("erroor ocoourer ==>${e.toString()}");

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AppEntry()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     // backgroundColor: Colors.black,
      // body: SizedBox.expand(
      //   child: FittedBox(
      //     fit: BoxFit.cover,
      //     child: SizedBox(
      //       width: _controller.value.isInitialized
      //           ? _controller.value.size.width
      //           : 1,
      //       height: _controller.value.isInitialized
      //           ? _controller.value.size.height
      //           : 1,
      //       child: VideoPlayer(_controller),
      //     ),
      //   ),
      // ),
      body: Center(child: Text("Splash screen"),),
    );
  }
}
