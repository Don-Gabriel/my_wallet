# MyWallet

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web%20%7C%20Flutter-1A7F64?style=for-the-badge)](#supported-platforms)
[![Status](https://img.shields.io/badge/Status-Functional%20Prototype-3B82F6?style=for-the-badge)](#project-status)

MyWallet is a professional, privacy-conscious smart expense tracker built with Flutter and Firebase. It is designed for fast manual entry, offline-first usage, clean personal finance visibility, and practical spending insights without requiring bank integrations.

The app helps users answer the everyday money questions that matter:

| Question | MyWallet Answer |
| --- | --- |
| How much money do I currently have? | Net balance and wallet-wise balance summary |
| How much did I spend today? | Today spent widget and transaction list |
| Am I within budget? | Budget usage, safe-to-spend, and threshold insights |
| Where is my money going? | Category reports, trend charts, and top category analytics |
| What should I improve? | Smart insights, anomaly detection, subscriptions, and savings suggestions |

---

## Table Of Contents

- [Project Overview](#project-overview)
- [Who This App Is For](#who-this-app-is-for)
- [Feature Highlights](#feature-highlights)
- [Screens And User Flow](#screens-and-user-flow)
- [Architecture](#architecture)
- [Firebase Setup](#firebase-setup)
- [Download And Run The App](#download-and-run-the-app)
- [Build The APK](#build-the-apk)
- [Testing And Verification](#testing-and-verification)
- [Data Model](#data-model)
- [Privacy And Security](#privacy-and-security)
- [Troubleshooting](#troubleshooting)
- [Project Status](#project-status)

---

## Project Overview

| Item | Details |
| --- | --- |
| App name | MyWallet |
| Product type | Smart expense tracker / personal finance manager |
| Frontend | Flutter |
| Backend | Firebase |
| Auth | Google Sign-In and guest mode |
| Database | Cloud Firestore with offline persistence |
| Local settings | Shared Preferences |
| Export and backup | CSV export/import plus MyWallet backup restore |
| Main package | `com.don.mywallet` |
| Firebase project ID | `mywallet-d581d` |
| Firebase project number | `343256388815` |
| Firestore location | Mumbai |

MyWallet focuses on manual-first finance tracking. This keeps the product lightweight, private, and usable even when banking integrations are unavailable or unnecessary.

---

## Who This App Is For

| User Type | Common Problem | MyWallet Helps With |
| --- | --- | --- |
| Students | Fixed allowance and impulse spending | Daily spend tracking, safe-to-spend, category budgets |
| Professionals | Bills, subscriptions, savings inconsistency | Monthly summaries, recurring reminders, insight feed |
| Freelancers | Irregular income and cash-flow uncertainty | Income/expense visibility, wallet tracking, reports |
| Families | Shared household expenses | Wallets, budgets, goals, recurring bills |

---

## Feature Highlights

### Dashboard

The dashboard is designed to show the most important information first, without unnecessary technical details.

| Feature | Description |
| --- | --- |
| Net balance hero | Shows the current overall balance clearly |
| Monthly income and expense | Tracks current month totals |
| Budget progress | Shows how much of the monthly budget is used |
| Safe-to-spend | Shows how much can be spent today while staying within budget |
| Savings rate | Shows how much of income remains after expenses |
| Wallet balance summary | Shows balances across active wallets |
| Upcoming bills | Shows bills that need attention |
| Recent transactions | Shows the latest spending/income entries |
| Insight feed | Shows practical spending warnings and recommendations |

### Transaction Management

Transactions are built around fast entry and easy correction.

| Feature | Description |
| --- | --- |
| Calculator-style entry | Add amounts using a built-in keypad |
| Live comma formatting | Amounts are easier to read while typing |
| Income / Expense / Transfer tabs | Quickly choose transaction type |
| Wallet selector | Choose which wallet/account is affected |
| Category selector | Pick from active categories |
| Date, note, and payment method | Extra details are available without clutter |
| Duplicate warning | Warns before saving a likely duplicate |
| Undo actions | Undo after add, edit, or delete |
| Advanced search filters | Filter by amount, wallet, category, payment method, and date |
| Split, refund, duplicate, recurring actions | Manage real-world transaction flows |

### Smart Insights

MyWallet includes lightweight, privacy-friendly intelligence based on local transaction patterns.

| Insight | Example |
| --- | --- |
| Category rule suggestions | Notes containing `Uber` suggest `Transport`; `Swiggy` suggests `Food` |
| Subscription detection | Repeated monthly expenses are detected |
| Spending anomaly | Flags unusually large expenses |
| Weekend spending | Shows if weekend spending is high |
| Category saving suggestion | Shows how much reducing a category by 10% can save |
| Low-balance warning | Warns when balance is low compared to spending |
| Savings streak | Shows positive cash-flow streaks subtly |

### Budgets

| Feature | Description |
| --- | --- |
| Monthly budget | Set an overall monthly spending limit |
| Category budgets | Track spending against category-specific limits |
| Safe-to-spend calculation | Converts remaining budget into a daily spending guide |
| Budget recommendation | Suggests a starter budget based on past spending |
| Budget alerts | Insight feed highlights 50%, 75%, 90%, and 100% usage |

### Goals, Bills, And Recurring Items

| Module | Features |
| --- | --- |
| Savings goals | Target amount, current progress, deadline, progress bar |
| Bills | Bill list, due status, mark paid, post bill as transaction |
| Bill calendar | Compact upcoming bill view |
| Recurring items | Weekly/monthly income or expense tracking |
| Recurring actions | Post now, skip once, pause/resume, edit, delete |

### Reports And Analytics

| Report | Description |
| --- | --- |
| Monthly analytics | Average daily spend, savings rate, largest expense |
| Month-over-month comparison | Income, expense, and savings comparison |
| Top categories | Category ranking with bars |
| Spending calendar | Heatmap-style daily spending view |
| Wallet breakdown | Wallet-wise balance and monthly spend |
| Closed months | Clean monthly close summaries for previous months |

### Data Tools

| Tool | Description |
| --- | --- |
| CSV export | Save transactions as an actual `.csv` file |
| CSV import | Import from pasted CSV data |
| CSV restore | Restore transactions from a CSV file |
| Import preview | Preview transactions before saving imported rows |
| MyWallet backup | Save a structured `.mywallet` backup file |
| Backup restore | Restore app data from `.mywallet` or `.json` backup |
| Monthly report | Save a text summary report |
| Offline status | UI explains offline sync behavior |
| Conflict behavior | Latest saved edit wins when the same item changes on multiple devices |

---

## Screens And User Flow

```text
Open App
  |
  +-- Sign in with Google
  |      |
  |      +-- Sync profile and wallet data
  |
  +-- Continue as Guest
         |
         +-- Use a private wallet without Google sign-in

After sign-in:

Dashboard
  |
  +-- Add Transaction
  |      |
  |      +-- Calculator amount entry
  |      +-- Category / wallet picker
  |      +-- Smart duplicate and category suggestions
  |
  +-- Transactions
  |      |
  |      +-- Search
  |      +-- Filters
  |      +-- Edit / duplicate / refund / split / delete
  |
  +-- Reports
  |      |
  |      +-- Analytics
  |      +-- Category budgets
  |      +-- Closed month summaries
  |
  +-- Goals
  |      |
  |      +-- Savings goals
  |      +-- Bills
  |      +-- Recurring transactions
  |
  +-- Settings
         |
         +-- Appearance
         +-- Privacy
         +-- Wallets
         +-- Categories
         +-- Data tools
         +-- Account
```

---

## Architecture

The app is organized by feature and responsibility. The goal is to keep UI, data access, models, and shared utilities separate.

```text
lib/
  main.dart
  src/
    app/
      bootstrap.dart
      my_wallet_app.dart
    data/
      wallet_repository.dart
      firebase_wallet_repository.dart
    features/
      auth/
      budget/
      dashboard/
      goals/
      reports/
      settings/
      shell/
      transactions/
    models/
      bill_reminder.dart
      budget.dart
      category_budget.dart
      recurring_transaction.dart
      savings_goal.dart
      transaction.dart
      wallet_account.dart
      wallet_summary.dart
      wallet_user.dart
    security/
      security_controller.dart
      security_scope.dart
    shared/
      backup_tools.dart
      common_widgets.dart
      csv_tools.dart
      error_handling.dart
      finance_intelligence.dart
      formatters.dart
```

### Architectural Layers

| Layer | Responsibility |
| --- | --- |
| `features` | Screens, forms, and user flows |
| `models` | App data structures and Firestore conversion helpers |
| `data` | Repository contract and Firebase implementation |
| `shared` | Reusable widgets, formatters, CSV/backup tools, insights |
| `security` | Local privacy preferences and privacy screen behavior |
| `app` | Bootstrap, theme, auth routing, and app shell setup |

### Repository Pattern

The app uses `WalletRepository` as an abstraction over data operations. This keeps the UI from directly depending on Firebase APIs.

```text
UI screen
  -> WalletRepository interface
      -> FirebaseWalletRepository
          -> Firebase Auth
          -> Cloud Firestore
```

Benefits:

- Easier testing
- Cleaner feature code
- Centralized Firestore behavior
- Easier future migration to another backend or local database

---

## Firebase Setup

This codebase is already configured for the Firebase project below:

| Setting | Value |
| --- | --- |
| Project ID | `mywallet-d581d` |
| Project number | `343256388815` |
| Android package | `com.don.mywallet` |
| Firestore location | Mumbai |

### Firebase Services Used

| Firebase Service | Purpose |
| --- | --- |
| Firebase Auth | Google Sign-In and guest sign-in |
| Cloud Firestore | User data, transactions, categories, budgets, goals, bills, recurring items |
| Firebase Analytics | Basic app analytics |

### Firestore Rules

Rules are stored in:

```text
firestore.rules
```

Deploy rules with:

```powershell
firebase deploy --only firestore:rules --project mywallet-d581d
```

### Firestore Collections

Data is stored under each authenticated user:

```text
users/{uid}
users/{uid}/transactions/{transactionId}
users/{uid}/categories/{categoryId}
users/{uid}/budgets/monthly
users/{uid}/categoryBudgets/{categoryId}
users/{uid}/goals/{goalId}
users/{uid}/wallets/{walletId}
users/{uid}/billReminders/{billReminderId}
users/{uid}/recurringTransactions/{recurringTransactionId}
```

### Using Your Own Firebase Project

If you want to run this with a new Firebase project:

1. Create a Firebase project in the Firebase Console.
2. Add an Android app with package name:

   ```text
   com.don.mywallet
   ```

3. Add your SHA-1 and SHA-256 fingerprints for Google Sign-In.
4. Enable Firebase Authentication:
   - Google provider
   - Anonymous provider
5. Create Cloud Firestore.
6. Install FlutterFire CLI if needed:

   ```powershell
   dart pub global activate flutterfire_cli
   ```

7. Reconfigure FlutterFire:

   ```powershell
   flutterfire configure
   ```

8. Deploy Firestore rules:

   ```powershell
   firebase deploy --only firestore:rules
   ```

---

## Download And Run The App

### 1. Install Required Tools

Install these before running the project:

| Tool | Why It Is Needed |
| --- | --- |
| Flutter SDK | Builds and runs the Flutter app |
| Android Studio | Android SDK, emulator, build tools |
| Java JDK | Required by Android/Gradle builds |
| Git | Download or clone the project |
| Firebase CLI | Optional, only needed to deploy Firestore rules |

Check Flutter installation:

```powershell
flutter doctor
```

Fix any major Android toolchain issues shown by `flutter doctor`.

### 2. Download The Code

If using Git:

```powershell
git clone <your-repository-url>
cd MyWallet
```

If using a ZIP file:

1. Download the ZIP.
2. Extract it.
3. Open PowerShell inside the extracted `MyWallet` folder.

The folder should contain:

```text
android/
lib/
test/
web/
pubspec.yaml
firebase.json
firestore.rules
README.md
```

### 3. Install Flutter Packages

From the project root:

```powershell
flutter pub get
```

### 4. Run On Android

Connect a phone with USB debugging enabled or start an Android emulator.

Check devices:

```powershell
flutter devices
```

Run the app:

```powershell
flutter run
```

If multiple devices are connected:

```powershell
flutter run -d <device-id>
```

### 5. Run On Web

```powershell
flutter run -d chrome
```

Note: Google Sign-In behavior may differ between Android and web depending on Firebase OAuth configuration.

---

## Build The APK

To create a debug APK:

```powershell
flutter build apk --debug
```

Output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

To create a release APK:

```powershell
flutter build apk --release
```

Release builds usually require signing configuration before publishing outside your own device.

---

## Testing And Verification

Run static analysis:

```powershell
flutter analyze
```

Run tests:

```powershell
flutter test
```

Build Android debug APK:

```powershell
flutter build apk --debug
```

Full recommended verification:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Current verified status:

| Check | Status |
| --- | --- |
| `flutter analyze` | Passing |
| `flutter test` | Passing |
| `flutter build apk --debug` | Passing |

---

## Data Model

### Transaction

| Field | Description |
| --- | --- |
| `amount` | Transaction amount |
| `category` | Category name |
| `type` | Expense, income, transfer, or refund |
| `date` | Transaction date |
| `walletId` | Source wallet |
| `transferWalletId` | Destination wallet for transfers |
| `notes` | Optional note or merchant text |
| `paymentMethod` | Cash, UPI, card, bank, etc. |
| `linkedTransactionId` | Used for refunds or linked entries |
| `isSplit` | Marks split transactions |

### Wallet

| Field | Description |
| --- | --- |
| `name` | Wallet/account name |
| `openingBalance` | Starting balance |
| `showOnDashboard` | Whether it appears on dashboard |
| `isArchived` | Whether it is hidden from active use |

### Budget

| Type | Description |
| --- | --- |
| Monthly budget | Overall monthly spending limit |
| Category budget | Monthly spending limit for a category |

### Backup Format

MyWallet backup files use structured JSON and are saved with the `.mywallet` extension.

Backups can include:

- Categories
- Wallets
- Transactions
- Monthly budget
- Category budgets
- Savings goals
- Bills
- Recurring transactions

---

## Privacy And Security

MyWallet is designed to avoid unnecessary data exposure.

| Area | Behavior |
| --- | --- |
| Bank integrations | Not required |
| Authentication | Google Sign-In or guest mode |
| Firestore access | User-scoped data paths |
| Local privacy | Hide amounts toggle |
| Privacy screen | Optional app preview protection |
| Data export | User-controlled CSV and backup export |
| Data deletion | Cloud data and local privacy settings can be cleared |

The app does not include receipt image uploads in this version. Firebase Storage is not required for the current feature set.

---

## Supported Platforms

| Platform | Status |
| --- | --- |
| Android | Primary supported platform |
| Web | Supported for development/testing |
| iOS | Flutter-compatible, but Firebase/iOS setup must be configured separately |
| Windows/macOS/Linux | Not the primary target |

---

## Troubleshooting

### `flutter pub get` fails

Try:

```powershell
flutter clean
flutter pub get
```

### No Android device found

Check connected devices:

```powershell
flutter devices
```

If using a physical phone:

1. Enable Developer Options.
2. Enable USB debugging.
3. Accept the debug prompt on the phone.

### Google Sign-In does not work

Check:

- Google provider is enabled in Firebase Authentication.
- Android package name is correct: `com.don.mywallet`.
- SHA-1 fingerprint is added in Firebase project settings.
- SHA-256 fingerprint is added in Firebase project settings.
- `google-services.json` matches the Firebase project.

### Firestore permission error

Deploy rules:

```powershell
firebase deploy --only firestore:rules --project mywallet-d581d
```

Also confirm the user is signed in before writing data.

### Kotlin Gradle Plugin warning

Flutter may show a warning that some plugins still apply the Kotlin Gradle Plugin directly.

Known plugins:

- `file_picker`
- `file_saver`
- `firebase_analytics`

This is currently a warning and does not stop the debug APK from building. Future Flutter versions may require plugin updates.

### File picker build issue

This project pins:

```yaml
file_picker: 10.3.10
```

This version is used because it builds correctly with the current Android setup.

---

## Project Status

MyWallet is currently a complete functional prototype with a professional feature set:

| Area | Status |
| --- | --- |
| Authentication | Complete |
| Dashboard | Complete |
| Transactions | Complete |
| Calculator entry | Complete |
| Budgets | Complete |
| Reports | Complete |
| Goals | Complete |
| Bills | Complete |
| Recurring items | Complete |
| Smart insights | Complete |
| CSV tools | Complete |
| App backup/restore | Complete |
| Privacy controls | Complete |
| Android debug build | Passing |

---

## Development Notes

Recommended development loop:

```powershell
flutter analyze
flutter test
flutter run
```

Before sharing an APK:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

---

## License

This project is currently private/internal. Add a license file before publishing it publicly.
