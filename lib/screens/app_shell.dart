import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_form_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _repository = TransactionRepository();
  late Future<(TransactionSummary, List<TransactionModel>)> _data;
  int _selectedIndex = 0;
  int _refreshVersion = 0;

  static const _titles = [
    'Overview',
    'Transactions',
    '',
    'Calendar',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _data = _loadData();
  }

  Future<(TransactionSummary, List<TransactionModel>)> _loadData() async {
    final summary = await _repository.getSummary();
    final transactions = await _repository.getAll();
    return (summary, transactions);
  }

  void _reload() => setState(() {
    _refreshVersion++;
    _data = _loadData();
  });

  Future<void> _openForm({TransactionModel? transaction}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          repository: _repository,
          transaction: transaction,
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _deleteTransaction(TransactionModel transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('Remove ${transaction.category} from your records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _repository.delete(transaction.id!);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete transaction: $error')),
        );
      }
    }
  }

  void _selectDestination(int index) {
    if (index == 2) {
      _openForm();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_titles[_selectedIndex]),
      actions: [
        if (_selectedIndex == 0)
          IconButton(
            tooltip: 'Add transaction',
            onPressed: _openForm,
            icon: const Icon(Icons.add_rounded),
          ),
      ],
    ),
    body: FutureBuilder<(TransactionSummary, List<TransactionModel>)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(message: '${snapshot.error}', onRetry: _reload);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final (summary, transactions) = snapshot.data!;
        return switch (_selectedIndex) {
          0 => _DashboardScreen(
            summary: summary,
            transactions: transactions,
            onAdd: () => _openForm(),
            onEdit: (transaction) => _openForm(transaction: transaction),
            onDelete: _deleteTransaction,
          ),
          1 => _HistoryScreen(
            key: ValueKey(_refreshVersion),
            repository: _repository,
            onEdit: (transaction) => _openForm(transaction: transaction),
            onDelete: _deleteTransaction,
          ),
          3 => _CalendarScreen(
            transactions: transactions,
            onEdit: (transaction) => _openForm(transaction: transaction),
            onDelete: _deleteTransaction,
          ),
          _ => _ProfileScreen(summary: summary),
        };
      },
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectDestination,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'History',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline_rounded),
          selectedIcon: Icon(Icons.add_circle_rounded),
          label: 'Add',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Calendar',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    ),
  );
}

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({
    required this.summary,
    required this.transactions,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionSummary summary;
  final List<TransactionModel> transactions;
  final VoidCallback onAdd;
  final ValueChanged<TransactionModel> onEdit;
  final ValueChanged<TransactionModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final recent = transactions.take(5).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        Text(
          'Your money, in one place',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: const Color(0xFF718078)),
        ),
        const SizedBox(height: 16),
        _BalanceCard(summary: summary),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _AmountCard(
                label: 'Income',
                amountPaise: summary.totalCreditPaise,
                color: const Color(0xFF087F5B),
                icon: Icons.south_west_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AmountCard(
                label: 'Expenses',
                amountPaise: summary.totalDebitPaise,
                color: const Color(0xFFD64545),
                icon: Icons.north_east_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _SectionHeading(title: 'Recent activity'),
        if (recent.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Nothing to see yet',
            message: 'Add your first transaction to start tracking.',
            action: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add transaction'),
            ),
          )
        else
          ...recent.map(
            (transaction) => _TransactionCard(
              transaction: transaction,
              onEdit: () => onEdit(transaction),
              onDelete: () => onDelete(transaction),
            ),
          ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final TransactionSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF087F5B), Color(0xFF0C684C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF087F5B).withValues(alpha: 0.18),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: Colors.white70),
            SizedBox(width: 8),
            Text('Current balance', style: TextStyle(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          formatRupees(summary.balancePaise),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.sync_alt_rounded, color: Colors.white70, size: 18),
            const SizedBox(width: 7),
            Text(
              '${summary.transactionCount} transaction${summary.transactionCount == 1 ? '' : 's'} recorded',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.label,
    required this.amountPaise,
    required this.color,
    required this.icon,
  });

  final String label;
  final int amountPaise;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEAF0EC)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF718078), fontSize: 13),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatRupees(amountPaise),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF17211D),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _HistoryScreen extends StatefulWidget {
  const _HistoryScreen({
    super.key,
    required this.repository,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionRepository repository;
  final ValueChanged<TransactionModel> onEdit;
  final ValueChanged<TransactionModel> onDelete;

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  TransactionType? _filter;
  String? _dateFilter;
  late Future<List<TransactionModel>> _transactions;

  @override
  void initState() {
    super.initState();
    _transactions = widget.repository.getAll();
  }

  void _setFilter(TransactionType? type) {
    setState(() {
      _filter = type;
      _transactions = widget.repository.getAll(type: type, date: _dateFilter);
    });
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateFilter == null
          ? DateTime.now()
          : dateFromIso(_dateFilter!),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'FILTER BY DATE',
    );
    if (selected != null) {
      setState(() {
        _dateFilter = isoDate(selected);
        _transactions = widget.repository.getAll(
          type: _filter,
          date: _dateFilter,
        );
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _dateFilter = null;
      _transactions = widget.repository.getAll(type: _filter);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
        child: Column(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'credit', label: Text('Income')),
                ButtonSegment(value: 'debit', label: Text('Expense')),
              ],
              selected: {_filter?.value ?? 'all'},
              onSelectionChanged: (selected) => _setFilter(
                selected.first == 'all'
                    ? null
                    : TransactionType.fromValue(selected.first),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text(
                      _dateFilter == null
                          ? 'Any date'
                          : formatDate(_dateFilter!),
                    ),
                  ),
                ),
                if (_dateFilter != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear date filter',
                    onPressed: _clearDateFilter,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<TransactionModel>>(
          future: _transactions,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _LoadError(
                message: '${snapshot.error}',
                onRetry: () => setState(
                  () => _transactions = widget.repository.getAll(
                    type: _filter,
                    date: _dateFilter,
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final transactions = snapshot.data!;
            if (transactions.isEmpty) {
              return const EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'No transactions found',
                message: 'Try another filter or add a transaction.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: transactions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _TransactionCard(
                transaction: transactions[index],
                onEdit: () => widget.onEdit(transactions[index]),
                onDelete: () => widget.onDelete(transactions[index]),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _CalendarScreen extends StatefulWidget {
  const _CalendarScreen({
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TransactionModel> transactions;
  final ValueChanged<TransactionModel> onEdit;
  final ValueChanged<TransactionModel> onDelete;

  @override
  State<_CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<_CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final selectedTransactions = widget.transactions
        .where((transaction) => transaction.date == isoDate(_selectedDate))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFEAF0EC)),
          ),
          child: CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
            onDateChanged: (date) => setState(() => _selectedDate = date),
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeading(
          title: formatDate(isoDate(_selectedDate), pattern: 'EEEE, d MMMM'),
        ),
        const SizedBox(height: 12),
        if (selectedTransactions.isEmpty)
          const EmptyState(
            icon: Icons.event_available_rounded,
            title: 'A clear day',
            message: 'No transactions recorded for this date.',
          )
        else
          ...selectedTransactions.map(
            (transaction) => _TransactionCard(
              transaction: transaction,
              onEdit: () => widget.onEdit(transaction),
              onDelete: () => widget.onDelete(transaction),
            ),
          ),
      ],
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen({required this.summary});

  final TransactionSummary summary;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    children: [
      const CircleAvatar(
        radius: 34,
        backgroundColor: Color(0xFFE8F4EE),
        foregroundColor: Color(0xFF087F5B),
        child: Icon(Icons.person_rounded, size: 34),
      ),
      const SizedBox(height: 14),
      Text(
        'Your wallet',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      const Text(
        'Personal expense tracker',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF718078)),
      ),
      const SizedBox(height: 28),
      Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEAF0EC)),
        ),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long_rounded),
              title: const Text('Transactions recorded'),
              trailing: Text(
                '${summary.transactionCount}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            const ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text('Private by design'),
              subtitle: Text('Your records stay on this device.'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Monee · Offline expense tracking',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF718078), fontSize: 12),
      ),
    ],
  );
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionModel transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFEAF0EC)),
    ),
    child: TransactionTile(
      transaction: transaction,
      onEdit: onEdit,
      onDelete: onDelete,
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFD64545)),
          const SizedBox(height: 12),
          const Text('Could not load your transactions.'),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
