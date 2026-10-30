# RASHI ENTERPRISES Biller

Web billing and invoice generation application for RASHI ENTERPRISES built with Flutter.

## Features
- **Customer Details (Optional)**: Name, Phone, and GSTIN.
- **Item Entry**:
  - Categories: *Sweet Meat, Milk Sweets, Mix Sweets, Ordinary Sweets, Dry Fruit Sweets, Kaju Sweets, Ice Halwa*
  - Quantity in KG and Price in ₹
- **Bill Calculation**:
  - Auto-calculated Subtotal
  - 5% Tax (GST)
  - Real-time Discount & Delivery Charge calculations
  - Grand Total
- **PDF Generation & Invoicing**:
  - Tax invoice branded for **RASHI ENTERPRISES**
  - GSTIN: `27ADDPD5275C1ZW`
  - HSN Code: `210690`
  - Formatted currency (`₹`) and dynamic **Amount in Words** (*... RUPEES ONLY*)
  - One-click **Preview PDF** & **Share PDF**
- **Reset Functionality**: Refresh icon in AppBar to quickly start a new bill.

## Getting Started

### Prerequisites
- Flutter SDK (>= 3.13.5)

### Running locally
```bash
flutter run -d chrome
```

### Building for Web
```bash
flutter build web
```

### Deploying to Firebase
```bash
firebase deploy
```
