import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/theme.dart';
import '../core/master_list.dart'; // Ensure this file exists!
import '../models/shop_details.dart';
import '../models/item.dart';
import '../providers/inventory_provider.dart';
import '../providers/auth_provider.dart';

// Screens
import 'voice_assistant_screen.dart';
import 'inventory_screen.dart';
import 'frequent_billing_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // --- STATE 1: DATA ---
  final List<Map<String, dynamic>> _pastBills = [];

  // Initialize Frequent Items from Master List
  final List<Item> _frequentItems = List.from(masterFrequentList);

  // --- STATE 2: PRINTER ---
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _connectedDevice;
  bool _isPrinterConnected = false;

  @override
  void initState() {
    super.initState();
    _initPrinter();
  }

  void _initPrinter() {
    bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case BlueThermalPrinter.CONNECTED:
          setState(() => _isPrinterConnected = true);
          break;
        case BlueThermalPrinter.DISCONNECTED:
          setState(() {
            _isPrinterConnected = false;
            _connectedDevice = null;
          });
          break;
        default:
          break;
      }
    });
  }

  // --- FREQUENT ITEM MANAGEMENT ---
  void _addFrequentItem(Item item) {
    setState(() {
      _frequentItems.add(item);
    });
  }

  void _editFrequentItem(Item newItem) {
    setState(() {
      final index = _frequentItems.indexWhere((i) => i.id == newItem.id);
      if (index != -1) {
        _frequentItems[index] = newItem;
      }
    });
  }

  void _deleteFrequentItem(String id) {
    setState(() {
      _frequentItems.removeWhere((i) => i.id == id);
    });
  }

  // --- PRINTER LOGIC ---
  void _togglePrinter() async {
    if (_isPrinterConnected) {
      _showDisconnectDialog();
    } else {
      await _showConnectDialog();
    }
  }

  void _showDisconnectDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Printer Connected",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Connected to: ${_connectedDevice?.name ?? 'Unknown Device'}",
                style: const TextStyle(color: Colors.green)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  bluetooth.disconnect();
                  Navigator.pop(context);
                },
                child: const Text("Disconnect Printer",
                    style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _showConnectDialog() async {
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      setState(() => _devices = devices);
    } catch (e) {
      print("Error getting devices: $e");
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Printer",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text(
                  "Make sure printer is ON and Paired in Bluetooth Settings.",
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Expanded(
                child: _devices.isEmpty
                    ? const Center(
                        child: Text(
                            "No paired devices found.\nPlease pair in Android Settings."))
                    : ListView.separated(
                        itemCount: _devices.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          return ListTile(
                            leading: const Icon(Icons.print,
                                color: AppColors.primaryGreen),
                            title: Text(device.name ?? "Unknown Device"),
                            subtitle: Text(device.address ?? ""),
                            onTap: () {
                              Navigator.pop(context);
                              _connectToDevice(device);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _connectToDevice(BluetoothDevice device) async {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connecting to ${device.name}...")));
    try {
      await bluetooth.connect(device);
      setState(() => _connectedDevice = device);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to connect: $e")));
    }
  }

  // --- BILLING LOGIC ---
  void _printOrSaveBill(Map<String, dynamic> billData) async {
    setState(() {
      _pastBills.insert(0, billData);
    });

    if (_isPrinterConnected) {
      await _printThermal(billData);
    } else {
      await _printPdf(billData);
    }
  }

  Future<void> _printThermal(Map<String, dynamic> billData) async {
    if (!_isPrinterConnected) return;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.text(billData['shopName'] ?? "Shop",
          styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      bytes += generator.text("Ph: ${billData['shopPhone']}",
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

      // Items
      bytes += generator.row([
        PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'Qty',
            width: 2,
            styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(
            text: 'Amt',
            width: 4,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);

      List<dynamic> items = billData['items'];
      for (var item in items) {
        bytes += generator.row([
          PosColumn(text: item['en'] ?? item['name'], width: 6),
          PosColumn(
              text: item['qty'].toString(),
              width: 2,
              styles: const PosStyles(align: PosAlign.center)),
          PosColumn(
              text: item['total'].toInt().toString(),
              width: 4,
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr();
      bytes += generator.text("TOTAL: Rs ${billData['total'].toInt()}",
          styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2));
      bytes += generator.feed(1);
      bytes += generator.text("Thank You!",
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(2);
      bytes += generator.cut();

      await bluetooth.writeBytes(Uint8List.fromList(bytes));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Print Failed. Try reconnecting.")));
    }
  }

  Future<void> _printPdf(Map<String, dynamic> billData) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(billData['shopName'],
                style: pw.TextStyle(font: fontBold, fontSize: 18)),
            pw.Text("Ph: ${billData['shopPhone']}",
                style: pw.TextStyle(font: font, fontSize: 10)),
            pw.Divider(),
            pw.Text("TOTAL: Rs ${billData['total'].toInt()}",
                style: pw.TextStyle(font: fontBold, fontSize: 16)),
          ],
        );
      },
    ));

    await Printing.layoutPdf(
        onLayout: (format) async => doc.save(), name: 'Bill-${billData['id']}');
  }

  // --- SWIPE LOGIC ---
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final _shopDetails = Provider.of<AuthProvider>(context).shopDetails ??
        ShopDetails(
            shopName: "Loading...",
            ownerName: "",
            address: "",
            phone1: "",
            phone2: "");

    return Scaffold(
      body: PageView(
        controller: _pageController,
        // ENABLE SWIPING
        onPageChanged: _onPageChanged,
        children: [
          // 1. VOICE
          // FIXED: Removed 'inventory' parameter.
          // Ensure your VoiceAssistantScreen uses Provider.of<InventoryProvider>(context).items internally if needed.
          VoiceAssistantScreen(
            shopDetails: _shopDetails,
            onBillFinalized: _printOrSaveBill,
            isPrinterConnected: _isPrinterConnected,
            togglePrinter: _togglePrinter,
          ),

          // 2. INVENTORY
          const InventoryScreen(),

          // 3. FREQUENT
          FrequentBillingScreen(
            shopDetails: _shopDetails,
            frequentItems: _frequentItems,
            onBillFinalized: _printOrSaveBill,
            isPrinterConnected: _isPrinterConnected,
            togglePrinter: _togglePrinter,
            onAdd: _addFrequentItem,
            onEdit: _editFrequentItem,
            onDelete: _deleteFrequentItem,
          ),

          // 4. HISTORY
          HistoryScreen(shopDetails: _shopDetails, pastBills: _pastBills),

          // 5. PROFILE
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primaryGreen,
          unselectedItemColor: Colors.grey[400],
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.mic_rounded), label: 'Voice'),
            BottomNavigationBarItem(
                icon: Icon(Icons.store_rounded), label: 'Dukan'),
            BottomNavigationBarItem(
                icon: Icon(Icons.flash_on_rounded), label: 'Frequent'),
            BottomNavigationBarItem(
                icon: Icon(Icons.history_rounded), label: 'History'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
