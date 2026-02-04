import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import '../core/theme.dart';
import '../models/shop_details.dart';
import '../services/api_client.dart';

class VoiceAssistantScreen extends StatefulWidget {
  final ShopDetails shopDetails;
  final Function(Map<String, dynamic>) onBillFinalized;
  final bool isPrinterConnected;
  final VoidCallback togglePrinter;

  const VoiceAssistantScreen({
    super.key,
    required this.shopDetails,
    required this.onBillFinalized,
    required this.isPrinterConnected,
    required this.togglePrinter,
  });

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  late AnimationController _pulseController;

  bool _isListening = false;
  String _currentSpeechChunk = "";
  String _aiResponseText = "Tap to Speak";
  final List<Map<String, dynamic>> _currentBill = [];
  Timer? _silenceTimer;
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _setupAnimation();
    _initTts();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _silenceTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  // --- RESTORED: Exact TTS Settings from your previous version ---
  void _initTts() async {
    await _flutterTts.setLanguage("hi-IN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5); // Slower rate for clarity
    await _flutterTts.awaitSpeakCompletion(
        true); // CRITICAL: Ensures full sentence is spoken
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
        lowerBound: 0.8,
        upperBound: 1.2)
      ..repeat(reverse: true);
  }

  void _toggleListening() async {
    if (_isListening) {
      _stopListening();
    } else {
      _pulseController.forward();
      setState(() {
        _isListening = true;
        _aiResponseText = "Listening...";
      });
      _startListening();
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize(
        onError: (val) => debugPrint('STT Error: $val'),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            // Only restart if we are supposed to be listening and AI is NOT speaking
            if (_isListening) {
              _startListening();
            }
          }
        });

    if (available) {
      _speech.listen(
        onResult: (val) {
          setState(() => _currentSpeechChunk = val.recognizedWords);
          _silenceTimer?.cancel();
          _silenceTimer = Timer(const Duration(seconds: 2), () {
            if (_currentSpeechChunk.trim().isNotEmpty) {
              // Stop listening immediately to prevent interruption
              _speech.stop();
              _processAiRequest(_currentSpeechChunk);
              setState(() => _currentSpeechChunk = "");
            }
          });
        },
        localeId: 'en_IN',
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    _silenceTimer?.cancel();
    _pulseController.stop();
    setState(() => _isListening = false);
  }

  Future<void> _processAiRequest(String text) async {
    try {
      setState(() => _aiResponseText = "Processing...");

      // 1. Call API
      final data = await _apiClient.post('/voice/process', {"text": text});

      // 2. Handle Text Response (Voice)
      String? msg = data['msg'];
      if (msg != null && msg.isNotEmpty) {
        setState(() => _aiResponseText = msg);

        // CRITICAL FIX: await ensures the UI doesn't refresh/interrupt while speaking
        await _flutterTts.speak(msg);
      }

      // 3. Update Bill (Only AFTER voice finishes)
      if (data['type'] == 'BILL') {
        List<dynamic> newItems = data['items'] ?? [];
        setState(() {
          for (var i in newItems) {
            _currentBill.add(i);
          }
        });
      }

      // 4. Resume Listening (Optional - makes it conversational)
      // Uncomment the line below if you want it to auto-listen after speaking
      // _toggleListening();
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _aiResponseText = "Server Error");
    }
  }

  void _finalizeBill() {
    if (_currentBill.isEmpty) return;

    if (!widget.isPrinterConnected) {
      _flutterTts.speak("Printer connected nahi hai"); // Speak warning
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Connect Printer First!"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      widget.togglePrinter();
      return;
    }

    // Speak confirmation
    _flutterTts.speak("Bill print ho raha hai");

    final billData = {
      'id':
          'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      'date':
          "${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}",
      'time': "${DateTime.now().hour}:${DateTime.now().minute}",
      'total': _currentBill.fold<double>(
          0, (sum, item) => sum + (item['total'] as num).toDouble()),
      'shopName': widget.shopDetails.shopName,
      'shopAddress': widget.shopDetails.address,
      'shopPhone': widget.shopDetails.phone1,
      'items': _currentBill,
    };

    widget.onBillFinalized(billData);

    setState(() {
      _currentBill.clear();
      _aiResponseText = "Bill Printed!";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    Text(widget.shopDetails.shopName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: Icon(Icons.print,
                            color: widget.isPrinterConnected
                                ? AppColors.printerConnected
                                : AppColors.printerDisconnected),
                        onPressed: widget.togglePrinter),
                  ]),
            ),

            // 2. Mic Animation
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                            scale: _isListening ? _pulseController.value : 1.0,
                            child: Container(
                                height: 120,
                                width: 120,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isListening
                                        ? AppColors.primaryGreen
                                        : Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                          color: _isListening
                                              ? AppColors.primaryGreen
                                                  .withOpacity(0.5)
                                              : Colors.black12,
                                          blurRadius: 30,
                                          spreadRadius: 5)
                                    ],
                                    border: Border.all(
                                        color: _isListening
                                            ? Colors.transparent
                                            : Colors.grey.shade300,
                                        width: 2)),
                                child: Icon(
                                    _isListening
                                        ? Icons.graphic_eq
                                        : Icons.mic_none_rounded,
                                    size: 50,
                                    color: _isListening
                                        ? Colors.white
                                        : Colors.black)));
                      })),
              const SizedBox(height: 15),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                      _isListening
                          ? (_currentSpeechChunk.isEmpty
                              ? "Listening..."
                              : _currentSpeechChunk)
                          : "Tap to Speak",
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.grey))),
              const SizedBox(height: 10),

              // Response Text
              Text(_aiResponseText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ]),

            // 3. Live Bill Container
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      const BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, -5))
                    ]),
                child: Column(
                  children: [
                    // Bill Header
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Live Bill",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _currentBill.clear()),
                                  icon: const Icon(Icons.cancel_outlined,
                                      size: 18, color: Colors.red),
                                  label: const Text("Cancel Bill",
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold))),
                            ])),

                    // Column Headers
                    const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        child: Row(children: [
                          Expanded(
                              flex: 4,
                              child: Text("Item",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey))),
                          Expanded(
                              flex: 1,
                              child: Text("Qty",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey))),
                          Expanded(
                              flex: 2,
                              child: Text("Price",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey))),
                          Expanded(
                              flex: 2,
                              child: Text("Total",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey))),
                        ])),
                    const Divider(height: 1),

                    // List Items
                    Expanded(
                        child: _currentBill.isEmpty
                            ? const Center(
                                child: Text("Say 'Chawal 1kg' to add items",
                                    style: TextStyle(color: Colors.grey)))
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                itemCount: _currentBill.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 16),
                                itemBuilder: (context, index) {
                                  final item = _currentBill[index];
                                  return Row(children: [
                                    GestureDetector(
                                        onTap: () => setState(
                                            () => _currentBill.removeAt(index)),
                                        child: Container(
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                shape: BoxShape.circle),
                                            child: const Icon(Icons.remove,
                                                size: 16, color: Colors.red))),
                                    Expanded(
                                        flex: 4,
                                        child: Text(item['name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14))),
                                    Expanded(
                                        flex: 1,
                                        child: Text(item['qty_display'],
                                            textAlign: TextAlign.center,
                                            style:
                                                const TextStyle(fontSize: 13))),
                                    Expanded(
                                        flex: 2,
                                        child: Text("₹${item['rate']}",
                                            textAlign: TextAlign.right,
                                            style:
                                                const TextStyle(fontSize: 12))),
                                    Expanded(
                                        flex: 2,
                                        child: Text("₹${item['total']}",
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14))),
                                  ]);
                                })),

                    // Footer Total
                    Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(25))),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                  onPressed: _finalizeBill,
                                  icon: const Icon(Icons.print,
                                      color: Colors.white, size: 20),
                                  label: const Text("PRINT",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      minimumSize: const Size(140, 48))),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text("TOTAL",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        "₹${_currentBill.fold<double>(0, (sum, item) => sum + (item['total'] as num).toDouble()).toInt()}",
                                        style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textBlack)),
                                  ]),
                            ])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
