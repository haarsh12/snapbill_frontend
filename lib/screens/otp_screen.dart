import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isLogin;
  // Optional data for Registration
  final String? shopName;
  final String? ownerName;
  final String? address;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.isLogin,
    this.shopName,
    this.ownerName,
    this.address,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  Timer? _timer;
  int _secondsRemaining = 45;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  void _resendOtp() async {
    try {
      await Provider.of<AuthProvider>(context, listen: false)
          .sendOtp(widget.phoneNumber, widget.isLogin);
      _startTimer();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("OTP Resent!")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Resend Failed: $e")));
    }
  }

  void _verifyAndLogin() async {
    String otp = _otpController.text.trim();
    if (otp.length != 6) return;

    setState(() => _isLoading = true);

    try {
      // NEW LOGIC: Call Backend to Verify
      await Provider.of<AuthProvider>(context, listen: false).verifyOtp(
          phone: widget.phoneNumber,
          otp: otp,
          shopName: widget.shopName,
          ownerName: widget.ownerName,
          address: widget.address);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Verification Failed: ${e.toString().replaceAll('Exception:', '')}")),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text("Welcome Back",
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack)),
            const SizedBox(height: 10),
            const Text("Login to access dashboard",
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 50),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: AppColors.lightGreenBg, shape: BoxShape.circle),
              child: const Icon(Icons.sms_rounded,
                  color: AppColors.primaryGreen, size: 30),
            ),
            const SizedBox(height: 20),
            Text("OTP Sent to ${widget.phoneNumber}",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 30),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                  fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: "000000",
                counterText: "",
                fillColor: Color(0xFFF5F5F5),
                filled: true,
                border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndLogin,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Verify"),
              ),
            ),
            const SizedBox(height: 20),
            if (_secondsRemaining > 0)
              Text(
                  "Resend OTP in 00:${_secondsRemaining.toString().padLeft(2, '0')}",
                  style: const TextStyle(color: Colors.grey))
            else
              TextButton(
                onPressed: _resendOtp,
                child: const Text("Resend OTP",
                    style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
