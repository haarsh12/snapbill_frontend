import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img; // v4 Library

import '../models/shop_details.dart';

class PrinterService {
  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<bool> isConnected() async {
    return (await bluetooth.isConnected) ?? false;
  }

  Future<String> printBill(
      Map<String, dynamic> billData, ShopDetails shopDetails) async {
    if (!await isConnected()) {
      return "Printer not connected";
    }

    try {
      // 1. Setup PDF Document
      final doc = pw.Document();
      // 80mm width creates a high-res master that we scale down to 58mm later
      // This ensures text is crisp and not pixelated
      const pageFormat = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity,
          marginAll: 2 * PdfPageFormat.mm);

      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // --- 1. BRANDING & HEADER ---
              pw.Center(
                  child: pw.Text("SNAPBILL",
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700))),
              pw.SizedBox(height: 2),

              pw.Center(
                  child: pw.Text(
                      (shopDetails.shopName.isNotEmpty
                              ? shopDetails.shopName
                              : "MY SHOP")
                          .toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 22))),

              // Address & Phone
              pw.Center(
                  child: pw.Text(
                      shopDetails.address.isNotEmpty
                          ? shopDetails.address
                          : "Shop Address Here",
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 12))),
              pw.Center(
                  child: pw.Text(
                      "Mob: ${shopDetails.phone1.isNotEmpty ? shopDetails.phone1 : '-'}",
                      style: const pw.TextStyle(fontSize: 12))),
              pw.Divider(thickness: 1),

              // --- 2. BILL META DATA ---
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        "Bill No: ${billData['id']?.toString().split('-').last ?? '001'}",
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.Text("Date: ${billData['date'] ?? '-'}",
                        style: const pw.TextStyle(fontSize: 12)),
                  ]),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Cst: Walk-in",
                        style: const pw.TextStyle(
                            fontSize: 12)), // Placeholder as requested
                    pw.Text("Time: ${billData['time'] ?? '-'}",
                        style: const pw.TextStyle(fontSize: 12)),
                  ]),
              pw.Divider(thickness: 1),

              // --- 3. TABLE HEADERS (4 Columns) ---
              pw.Row(children: [
                pw.Expanded(
                    flex: 4,
                    child: pw.Text("Item",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text("Rate",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12))),
                pw.Expanded(
                    flex: 1,
                    child: pw.Text("Qty",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12))),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text("Amt",
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12))),
              ]),
              pw.Divider(),

              // --- 4. ITEMS LIST (Smart Name Logic) ---
              ...billData['items'].map<pw.Widget>((item) {
                // SMART NAME RESOLVER: Checks all possible keys so it never prints "Item"
                String itemName = "Item";
                if (item['name'] != null)
                  itemName = item['name'];
                else if (item['en'] != null)
                  itemName = item['en'];
                else if (item['names'] != null &&
                    item['names'] is List &&
                    (item['names'] as List).isNotEmpty)
                  itemName = item['names'][0];

                String qty = item['qty']?.toString() ?? "1";
                String rate = item['rate']?.toString() ??
                    item['price']?.toString() ??
                    "0";
                String total = item['total']?.toInt()?.toString() ?? "0";

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(children: [
                    // Item Name
                    pw.Expanded(
                        flex: 4,
                        child: pw.Text(itemName,
                            style: const pw.TextStyle(fontSize: 14))),
                    // Rate
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text(rate,
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 14))),
                    // Qty
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text(qty,
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 14))),
                    // Amount
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text(total,
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 14))),
                  ]),
                );
              }).toList(),

              pw.Divider(thickness: 1),

              // --- 5. TOTAL SECTION ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text("Total Amount:  ",
                      style: const pw.TextStyle(fontSize: 14)),
                  pw.Text("Rs ${billData['total']?.toInt() ?? 0}",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 18)),
                ],
              ),
              pw.SizedBox(height: 10),

              // --- 6. FOOTER ---
              pw.Center(
                  child: pw.Text("Thank You! Visit Again",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14))),
              pw.SizedBox(height: 5),
              pw.Center(
                  child: pw.Text("Powered by SnapBill",
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey600))),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ));

      // 3. Rasterize (Convert PDF to Image)
      await for (final page
          in Printing.raster(await doc.save(), pages: [0], dpi: 203)) {
        final Uint8List imageBytes = await page.toPng();
        final img.Image? originalImage = img.decodeImage(imageBytes);

        if (originalImage != null) {
          // A. Resize to 384px (Standard Thermal Width)
          final img.Image resizedImage =
              img.copyResize(originalImage, width: 384);

          // B. Initialize Printer
          await bluetooth.writeBytes(Uint8List.fromList([0x1b, 0x40]));
          await Future.delayed(const Duration(milliseconds: 100));

          // C. Send Image (Using the Fixed Transparent/Black Logic)
          final List<int> printBytes = _generateRasterData(resizedImage);
          await bluetooth.writeBytes(Uint8List.fromList(printBytes));

          // D. Feed & Cut
          await Future.delayed(const Duration(milliseconds: 100));
          await bluetooth.writeBytes(Uint8List.fromList([0x0a, 0x0a, 0x0a]));
        }
        break;
      }
      return "Success";
    } catch (e) {
      return "Print Error: $e";
    }
  }

  // --- BIT PACKING (Fixed Black Background & Transparency) ---
  List<int> _generateRasterData(img.Image src) {
    List<int> data = [];
    int width = src.width;
    int height = src.height;

    // Header: GS v 0 0
    data.addAll([0x1d, 0x76, 0x30, 0x00]);

    int widthBytes = (width + 7) ~/ 8;
    data.add(widthBytes % 256);
    data.add(widthBytes ~/ 256);
    data.add(height % 256);
    data.add(height ~/ 256);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < widthBytes; x++) {
        int byte = 0;
        for (int k = 0; k < 8; k++) {
          int pixelX = x * 8 + k;
          if (pixelX < width) {
            final pixel = src.getPixel(pixelX, y);

            // 1. Check Transparency (Ignore background)
            if (pixel.a == 0) continue;

            // 2. Check Brightness (Dark pixels = 1, Light pixels = 0)
            double brightness = img.getLuminance(pixel).toDouble();
            if (brightness <= 1.0) brightness *= 255;

            if (brightness < 128) {
              byte |= (1 << (7 - k));
            }
          }
        }
        data.add(byte);
      }
    }
    return data;
  }
}
