import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/shop_details.dart';
import '../providers/auth_provider.dart';
import '../widgets/bill_receipt_widget.dart';
import 'auth_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  // We remove the passed variable to rely on Provider for the source of truth
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controllers for Shop Details
  late TextEditingController _shopNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phone1Ctrl;
  late TextEditingController _phone2Ctrl;

  // Edit State Triggers
  final Map<String, bool> _isEditing = {
    'shop': false,
    'owner': false,
    'address': false,
    'ph1': false,
    'ph2': false
  };

  // Settings State
  String _selectedTemplate = 'en';
  String _appLanguage = 'en';
  bool _isQrEnabled = false;
  String? _uploadedQrPath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Load initial data from Provider
    final details =
        Provider.of<AuthProvider>(context, listen: false).shopDetails ??
            ShopDetails(
                shopName: "My Shop",
                ownerName: "Owner",
                address: "Address",
                phone1: "",
                phone2: "");

    _shopNameCtrl = TextEditingController(text: details.shopName);
    _ownerNameCtrl = TextEditingController(text: details.ownerName);
    _addressCtrl = TextEditingController(text: details.address);
    _phone1Ctrl = TextEditingController(text: details.phone1);
    _phone2Ctrl = TextEditingController(text: details.phone2);
  }

  // --- LOGIC: UPDATE DETAILS & SYNC ---
  void _toggleEdit(String key) {
    setState(() {
      _isEditing[key] = !_isEditing[key]!;

      // If we just finished editing (saved), update the global provider
      if (!_isEditing[key]!) {
        final provider = Provider.of<AuthProvider>(context, listen: false);
        final current = provider.shopDetails!;

        // Update specific field based on key
        if (key == 'shop') current.shopName = _shopNameCtrl.text;
        if (key == 'owner') current.ownerName = _ownerNameCtrl.text;
        if (key == 'address') current.address = _addressCtrl.text;
        if (key == 'ph1') current.phone1 = _phone1Ctrl.text;
        if (key == 'ph2') current.phone2 = _phone2Ctrl.text;

        // Force UI rebuild to reflect changes in Preview
        setState(() {});
      }
    });
  }

  Future<void> _uploadQr() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _uploadedQrPath = image.path);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("QR Code Uploaded!")));
      }
    } catch (e) {/* Error */}
  }

  void _confirmLogout() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text("Confirm Logout"),
                content: const Text("Are you sure you want to log out?"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel")),
                  ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await Provider.of<AuthProvider>(context, listen: false)
                            .logout();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const AuthSelectionScreen()),
                              (route) => false);
                        }
                      },
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Logout",
                          style: TextStyle(color: Colors.white))),
                ]));
  }

  @override
  Widget build(BuildContext context) {
    // Get Real-time Data for Preview
    final details = Provider.of<AuthProvider>(context).shopDetails ??
        ShopDetails(
            shopName: "My Shop",
            ownerName: "Owner",
            address: "Address",
            phone1: "",
            phone2: "");

    // Preview Items Data
    final previewItems = [
      {
        'en': 'Rice',
        'qty': '1 kg',
        'rate': 100.0,
        'total': 100.0,
        'unit': 'kg'
      },
      {'en': 'Sugar', 'qty': '2 kg', 'rate': 40.0, 'total': 80.0, 'unit': 'kg'},
      {'en': 'Milk', 'qty': '2 L', 'rate': 60.0, 'total': 120.0, 'unit': 'L'},
      {
        'en': 'Soap',
        'qty': '5 pcs',
        'rate': 30.0,
        'total': 150.0,
        'unit': 'pcs'
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Profile"), actions: [
        IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _confirmLogout)
      ]),
      body: SingleChildScrollView(
        child: Column(children: [
          // 1. HEADER IMAGE
          Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(30)),
                  border: const Border(
                      bottom:
                          BorderSide(color: AppColors.primaryGreen, width: 4)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ]),
              child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(26)),
                  child: Image.asset("assets/geminigrocery.png",
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Center(
                          child: Icon(Icons.store,
                              size: 80, color: Colors.grey))))),

          Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. SHOP DETAILS BLOCK (New Requirement)
                    const Text("Shop Details",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          _buildEditableField(
                              "Shop Name", _shopNameCtrl, 'shop'),
                          const Divider(),
                          _buildEditableField(
                              "Owner Name", _ownerNameCtrl, 'owner'),
                          const Divider(),
                          _buildEditableField(
                              "Address", _addressCtrl, 'address'),
                          const Divider(),
                          _buildEditableField("Phone No. 1", _phone1Ctrl, 'ph1',
                              isPhone: true),
                          const Divider(),
                          _buildEditableField("Phone No. 2", _phone2Ctrl, 'ph2',
                              isPhone: true),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 3. APP LANGUAGE
                    const Text("App Language",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _buildOptionButton(
                              "English",
                              'en',
                              _appLanguage,
                              (val) => setState(() => _appLanguage = val))),
                      const SizedBox(width: 15),
                      Expanded(
                          child: _buildOptionButton("Hindi", 'hi', _appLanguage,
                              (val) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Hindi Language Coming Soon!")));
                      })),
                    ]),
                    const SizedBox(height: 30),

                    // 4. BILL SETTINGS
                    const Text("Bill Template Settings",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Select Language & Format",
                                      style: TextStyle(
                                          fontSize: 14, color: Colors.grey)),
                                  const SizedBox(height: 15),
                                  Row(children: [
                                    Expanded(
                                        child: _buildOptionButton(
                                            "Template 1\n(English)",
                                            'en',
                                            _selectedTemplate,
                                            (val) => setState(() =>
                                                _selectedTemplate = val))),
                                    const SizedBox(width: 15),
                                    Expanded(
                                        child: _buildOptionButton(
                                            "Template 2\n(Hindi)",
                                            'hi',
                                            _selectedTemplate,
                                            (val) => setState(() =>
                                                _selectedTemplate = val))),
                                  ]),
                                  const SizedBox(height: 20),

                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Add UPI QR Code to Bill",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Switch(
                                            value: _isQrEnabled,
                                            activeColor: AppColors.primaryGreen,
                                            onChanged: (val) => setState(
                                                () => _isQrEnabled = val))
                                      ]),

                                  if (_isQrEnabled)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 15),
                                        child: OutlinedButton.icon(
                                            onPressed: _uploadQr,
                                            icon: const Icon(Icons.upload),
                                            label:
                                                const Text("Upload QR Image"),
                                            style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.primaryGreen))),

                                  const SizedBox(height: 10),
                                  const Text("Live Preview:",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                  const SizedBox(height: 10),

                                  // PREVIEW WIDGET (Updates real-time with shop details)
                                  BillReceiptWidget(
                                      shopDetails: details,
                                      billId: "INV-PREVIEW",
                                      date: "24-1-2026",
                                      time: "19:45",
                                      items: previewItems,
                                      total: 450.0,
                                      isHindi: _selectedTemplate == 'hi',
                                      showQr: _isQrEnabled,
                                      qrImagePath: _uploadedQrPath)
                                ]))),
                    const SizedBox(height: 30),

                    // 5. CONNECTED DEVICES BLOCK (New Requirement)
                    const Text("Connected Devices",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Card(
                      child: Column(children: [
                        _buildDeviceTile(Icons.smartphone_rounded,
                            "Current Device (Android)", true),
                        const Divider(height: 1),
                        _buildDeviceTile(Icons.laptop_mac_rounded,
                            "Owner's Laptop (Windows)", true),
                        const Divider(height: 1),
                        _buildDeviceTile(
                            Icons.tablet_android_rounded, "Shop Tablet", false),
                      ]),
                    ),
                    const SizedBox(height: 50),
                  ])),
        ]),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildEditableField(
      String label, TextEditingController controller, String key,
      {bool isPhone = false}) {
    bool isEditing = _isEditing[key]!;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: controller,
                    enabled: isEditing,
                    keyboardType:
                        isPhone ? TextInputType.phone : TextInputType.text,
                    style: TextStyle(
                        color: isEditing ? Colors.black : Colors.grey[800],
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                    decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 8),
                        border: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: AppColors.primaryGreen))))),
            IconButton(
                onPressed: () => _toggleEdit(key),
                icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.grey[100], shape: BoxShape.circle),
                    child: Icon(isEditing ? Icons.check : Icons.edit,
                        size: 18,
                        color:
                            isEditing ? AppColors.primaryGreen : Colors.grey))),
          ]),
        ]));
  }

  Widget _buildOptionButton(
      String label, String value, String currentValue, Function(String) onTap) {
    bool isSelected = currentValue == value;
    return GestureDetector(
        onTap: () => onTap(value),
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGreen : Colors.white,
                border: Border.all(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10)),
            child: Center(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold)))));
  }

  Widget _buildDeviceTile(IconData icon, String name, bool isActive) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: isActive ? Colors.green.withOpacity(0.05) : Colors.white,
            border: Border(
                left: BorderSide(
                    color:
                        isActive ? AppColors.primaryGreen : Colors.transparent,
                    width: 4))),
        child: Row(children: [
          Icon(icon,
              color: isActive ? AppColors.primaryGreen : Colors.grey, size: 28),
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(isActive ? "Active Now" : "Last active: 2 hours ago",
                    style: TextStyle(
                        fontSize: 12,
                        color: isActive ? AppColors.primaryGreen : Colors.grey))
              ])),
          if (isActive)
            const Icon(Icons.check_circle,
                color: AppColors.primaryGreen, size: 22)
          else
            TextButton(
                onPressed: () {},
                child: const Text("Remove",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold))),
        ]));
  }
}
