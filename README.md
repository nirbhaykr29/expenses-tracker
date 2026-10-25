# Monee Expense Tracker

An offline-first Flutter expense tracker. Transactions are stored locally in
SQLite, and all persisted monetary amounts are integers in paise.

## Run the app

```sh
flutter pub get
flutter run
```

## Features

- Dashboard totals calculated from saved income and expense transactions.
- Add, edit, delete, and date transactions, including past dates.
- History filtered by income or expense, and a calendar view by date.
- Local SQLite persistence with parameterized database operations.

The app uses the Flutter SDK and the existing `sqflite`, `path`, and `intl`
dependencies. On desktop/web targets where `sqflite` has no configured
database implementation, use a supported mobile platform or add the
appropriate platform database adapter.
