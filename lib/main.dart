import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SweetsBillerApp());
}

class SweetsBillerApp extends StatelessWidget {
  const SweetsBillerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF00796B);
    return MaterialApp(
      title: 'RASHI ENTERPRISES Biller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          primary: primaryTeal,
        ),
        scaffoldBackgroundColor: const Color(0xFFFBF9FA),
        cardTheme: CardThemeData(
          elevation: 0.5,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300, width: 0.8),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryTeal, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const BillerHomePage(),
    );
  }
}

class BillItem {
  final String category;
  final double quantity;
  final double price;

  BillItem({
    required this.category,
    required this.quantity,
    required this.price,
  });

  double get total => quantity * price;
}

class BillerHomePage extends StatefulWidget {
  const BillerHomePage({super.key});

  @override
  State<BillerHomePage> createState() => _BillerHomePageState();
}

class _BillerHomePageState extends State<BillerHomePage> {
  // Customer details
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerGstinController = TextEditingController();

  // Item entry (Editable Dropdown / TextField)
  final _categoryController = TextEditingController();
  final _categoryFocusNode = FocusNode();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  // Tax toggle (Default: ON)
  bool _applyTax = true;

  // Discount & Delivery
  final _discountController = TextEditingController();
  final _deliveryController = TextEditingController();

  final List<BillItem> _items = [];

  final List<String> _categories = [
    'Sweet Meat',
    'Milk Sweets',
    'Mix Sweets',
    'Ordinary Sweets',
    'Dry Fruit Sweets',
    'Kaju Sweets',
    'Ice Halwa',
  ];

  final currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _discountController.addListener(() => setState(() {}));
    _deliveryController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerGstinController.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _deliveryController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.total);
  }

  double get _tax {
    if (!_applyTax) return 0.0;
    return _subtotal * 0.05; // 5% GST
  }

  double get _discount {
    final text = _discountController.text.trim();
    return double.tryParse(text) ?? 0.0;
  }

  double get _deliveryCharge {
    final text = _deliveryController.text.trim();
    return double.tryParse(text) ?? 0.0;
  }

  double get _grandTotal {
    return _subtotal + _tax - _discount + _deliveryCharge;
  }

  void _addItem() {
    final category = _categoryController.text.trim();
    final qtyText = _quantityController.text.trim();
    final priceText = _priceController.text.trim();

    if (category.isEmpty || qtyText.isEmpty || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter category, quantity, and price.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final qty = double.tryParse(qtyText);
    final price = double.tryParse(priceText);

    if (qty == null || price == null || qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid positive numbers for quantity and price.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _items.add(
        BillItem(
          category: category,
          quantity: qty,
          price: price,
        ),
      );

      // Add to category options if not already present
      if (!_categories.contains(category)) {
        _categories.add(category);
      }

      _categoryController.clear();
      _quantityController.clear();
      _priceController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _resetBill() {
    setState(() {
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customerGstinController.clear();
      _categoryController.clear();
      _quantityController.clear();
      _priceController.clear();
      _discountController.clear();
      _deliveryController.clear();
      _applyTax = true; // reset back to default ON
      _items.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New bill initialized.')),
    );
  }

  Future<Uint8List> _generatePdfData() async {
    final pdf = pw.Document();

    // Load NotoSans font for Indian Rupee symbol support
    pw.Font font;
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      font = pw.Font.ttf(fontData);
    } catch (_) {
      font = await PdfGoogleFonts.notoSansRegular();
    }

    final invoiceNumber = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    final tableData = <List<String>>[];
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      tableData.add([
        '${i + 1}',
        item.category,
        '210690',
        currencyFormat.format(item.quantity).replaceAll('₹', '').trim(),
        currencyFormat.format(item.price),
        currencyFormat.format(item.total),
      ]);
    }

    final roundedTotal = _grandTotal.round();
    final amountWords = NumberToWords.convert(roundedTotal).toUpperCase();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: font,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RASHI ENTERPRISES',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'GSTIN: 27ADDPD5275C1ZW',
                        style: pw.TextStyle(font: font, fontSize: 11),
                      ),
                    ],
                  ),
                  pw.Text(
                    _applyTax ? 'TAX INVOICE' : 'INVOICE',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 10),

              // Metadata & Bill To
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Invoice No: $invoiceNumber',
                        style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Date: $dateStr',
                        style: pw.TextStyle(font: font),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Bill To:',
                        style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                      ),
                      if (_customerNameController.text.trim().isNotEmpty)
                        pw.Text(_customerNameController.text.trim(), style: pw.TextStyle(font: font)),
                      if (_customerPhoneController.text.trim().isNotEmpty)
                        pw.Text(_customerPhoneController.text.trim(), style: pw.TextStyle(font: font)),
                      if (_customerGstinController.text.trim().isNotEmpty)
                        pw.Text('GSTIN: ${_customerGstinController.text.trim()}', style: pw.TextStyle(font: font)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Table
              pw.TableHelper.fromTextArray(
                headers: ['SN', 'Description', 'HSN Code', 'Qty (Kg)', 'Rate', 'Total'],
                data: tableData,
                headerStyle: pw.TextStyle(
                  font: font,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 16),

              // Summary Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.SizedBox(
                    width: 220,
                    child: pw.Column(
                      children: [
                        _buildPdfSummaryRow('Subtotal:', currencyFormat.format(_subtotal), font),
                        // Only include tax if the tax toggle is ON
                        if (_applyTax)
                          _buildPdfSummaryRow('Tax (5%):', currencyFormat.format(_tax), font),
                        if (_discount > 0)
                          _buildPdfSummaryRow('Discount:', '-${currencyFormat.format(_discount)}', font),
                        if (_deliveryCharge > 0)
                          _buildPdfSummaryRow('Delivery Charge:', currencyFormat.format(_deliveryCharge), font),
                        pw.Divider(),
                        _buildPdfSummaryRow(
                          'Grand Total:',
                          currencyFormat.format(_grandTotal),
                          font,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Amount in words
              pw.Text(
                'Amount in Words: $amountWords RUPEES ONLY',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Divider(thickness: 0.8),
              pw.Center(
                child: pw.Text(
                  'Thank you for your purchase!',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfSummaryRow(String label, String value, pw.Font font, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _previewPdf() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item before previewing PDF.')),
      );
      return;
    }
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => _generatePdfData(),
      name: 'Invoice-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}.pdf',
    );
  }

  Future<void> _sharePdf() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item before sharing PDF.')),
      );
      return;
    }

    final pdfBytes = await _generatePdfData();
    final filename = 'Invoice-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
      subject: 'Invoice from RASHI ENTERPRISES',
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF00796B);
    const greenColor = Color(0xFF4CAF50);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RASHI ENTERPRISES Biller',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Bill',
            onPressed: _resetBill,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Customer Details (Optional)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Details (Optional)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: tealColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                            hintText: 'Customer Name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Customer Phone',
                            hintText: 'Customer Phone',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerGstinController,
                          decoration: const InputDecoration(
                            labelText: 'Customer GSTIN',
                            hintText: 'Customer GSTIN',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Add Item
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Item',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: tealColor,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Editable Dropdown / Textfield (RawAutocomplete with PopupMenu)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return RawAutocomplete<String>(
                              textEditingController: _categoryController,
                              focusNode: _categoryFocusNode,
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return _categories;
                                }
                                return _categories.where((cat) {
                                  return cat.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Select or Type Category',
                                    hintText: 'Select Category or type new item...',
                                    suffixIcon: PopupMenuButton<String>(
                                      icon: const Icon(Icons.arrow_drop_down, size: 26),
                                      tooltip: 'Choose category',
                                      onSelected: (String val) {
                                        controller.text = val;
                                        focusNode.unfocus();
                                      },
                                      itemBuilder: (BuildContext context) {
                                        return _categories.map((String cat) {
                                          return PopupMenuItem<String>(
                                            value: cat,
                                            child: Text(cat),
                                          );
                                        }).toList();
                                      },
                                    ),
                                  ),
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth,
                                        maxHeight: 220,
                                      ),
                                      child: ListView.separated(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (BuildContext context, int index) {
                                          final String option = options.elementAt(index);
                                          return ListTile(
                                            dense: true,
                                            title: Text(option),
                                            onTap: () {
                                              onSelected(option);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _quantityController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Quantity (KG)',
                                  hintText: 'Quantity (KG)',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Price (₹)',
                                  hintText: 'Price (₹)',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tealColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                            label: const Text(
                              'Add Item',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: _addItem,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Added Items List
                if (_items.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: tealColor.withOpacity(0.12),
                              foregroundColor: tealColor,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              item.category,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${item.quantity} kg x ${currencyFormat.format(item.price)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currencyFormat.format(item.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // 4. Bill Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Center(
                          child: Text(
                            'Bill Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildSummaryRow('Subtotal:', currencyFormat.format(_subtotal)),
                        const SizedBox(height: 6),

                        // Tax Toggle Row (Default set to ON)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tax (5%):',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _applyTax ? Colors.black87 : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 28,
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: Switch(
                                      value: _applyTax,
                                      activeColor: tealColor,
                                      onChanged: (bool value) {
                                        setState(() {
                                          _applyTax = value;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _applyTax ? currencyFormat.format(_tax) : '₹0.00 (Off)',
                              style: TextStyle(
                                fontSize: 14,
                                color: _applyTax ? Colors.black87 : Colors.grey.shade500,
                                fontWeight: _applyTax ? FontWeight.normal : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        TextField(
                          controller: _discountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Discount Amount (₹)',
                            hintText: 'Discount Amount (₹)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _deliveryController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Delivery Charge (₹)',
                            hintText: 'Delivery Charge (₹)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currencyFormat.format(_grandTotal),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 5. Action Buttons
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tealColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 20),
                    label: const Text(
                      'Preview PDF',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _previewPdf,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: greenColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text(
                      'Share PDF',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _sharePdf,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ],
    );
  }
}

class NumberToWords {
  static const List<String> _units = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];

  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  static String convert(int n) {
    if (n == 0) return 'Zero';
    if (n < 0) return 'Minus ${convert(-n)}';

    String words = '';

    if ((n ~/ 10000000) > 0) {
      words += '${convert(n ~/ 10000000)} Crore ';
      n %= 10000000;
    }

    if ((n ~/ 100000) > 0) {
      words += '${convert(n ~/ 100000)} Lakh ';
      n %= 100000;
    }

    if ((n ~/ 1000) > 0) {
      words += '${convert(n ~/ 1000)} Thousand ';
      n %= 1000;
    }

    if ((n ~/ 100) > 0) {
      words += '${convert(n ~/ 100)} Hundred ';
      n %= 100;
    }

    if (n > 0) {
      if (words.isNotEmpty && !words.endsWith('Hundred ')) {
        words += ' ';
      }
      if (n < 20) {
        words += _units[n];
      } else {
        words += _tens[n ~/ 10];
        if ((n % 10) > 0) {
          words += ' ${_units[n % 10]}';
        }
      }
    }

    return words.trim();
  }
}
