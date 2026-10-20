import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const SparePartsApp());
}

class PartItem {
  int? id;
  String name;
  double buyPrice;
  double sellPrice;

  PartItem({
    this.id,
    required this.name,
    required this.buyPrice,
    required this.sellPrice,
  });

  double get profit => sellPrice - buyPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'buyPrice': buyPrice,
      'sellPrice': sellPrice,
    };
  }

  factory PartItem.fromMap(Map<String, dynamic> map) {
    return PartItem(
      id: map['id'],
      name: map['name'],
      buyPrice: map['buyPrice'],
      sellPrice: map['sellPrice'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('parts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE parts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            buyPrice REAL NOT NULL,
            sellPrice REAL NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertPart(PartItem part) async {
    final db = await instance.database;
    return await db.insert('parts', part.toMap());
  }

  Future<List<PartItem>> getAllParts() async {
    final db = await instance.database;
    final result = await db.query('parts', orderBy: 'id DESC');
    return result.map((json) => PartItem.fromMap(json)).toList();
  }

  Future<int> updatePart(PartItem part) async {
    final db = await instance.database;
    return await db.update('parts', part.toMap(), where: 'id = ?', whereArgs: [part.id]);
  }

  Future<int> deletePart(int id) async {
    final db = await instance.database;
    return await db.delete('parts', where: 'id = ?', whereArgs: [id]);
  }
}

class SparePartsApp extends StatelessWidget {
  const SparePartsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'إدارة قطع الغيار',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PartItem> _allParts = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshParts();
  }

  Future<void> _refreshParts() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllParts();
    setState(() {
      _allParts = data;
      _isLoading = false;
    });
  }

  List<PartItem> get _filteredParts {
    if (_searchQuery.isEmpty) return _allParts;
    return _allParts.where((part) => part.name.contains(_searchQuery)).toList();
  }

  double get _totalProfit {
    return _filteredParts.fold(0, (sum, item) => sum + item.profit);
  }

  void _showPartDialog({PartItem? existingPart}) {
    final isEditing = existingPart != null;
    final nameController = TextEditingController(text: isEditing ? existingPart.name : '');
    final buyPriceController = TextEditingController(text: isEditing ? existingPart.buyPrice.toString() : '');
    final sellPriceController = TextEditingController(text: isEditing ? existingPart.sellPrice.toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'تعديل قطعة الغيار' : 'إضافة قطعة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم القطعة',
                    prefixIcon: const Icon(Icons.build_circle_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: buyPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'سعر الشراء',
                    prefixIcon: const Icon(Icons.arrow_downward, color: Colors.redAccent),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sellPriceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'سعر البيع',
                    prefixIcon: const Icon(Icons.arrow_upward, color: Colors.green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final buyPrice = double.tryParse(buyPriceController.text) ?? 0.0;
                final sellPrice = double.tryParse(sellPriceController.text) ?? 0.0;

                if (name.isNotEmpty && buyPrice >= 0 && sellPrice >= 0) {
                  if (isEditing) {
                    existingPart.name = name;
                    existingPart.buyPrice = buyPrice;
                    existingPart.sellPrice = sellPrice;
                    await DatabaseHelper.instance.updatePart(existingPart);
                  } else {
                    await DatabaseHelper.instance.insertPart(PartItem(
                      name: name,
                      buyPrice: buyPrice,
                      sellPrice: sellPrice,
                    ));
                  }
                  _refreshParts();
                  Navigator.of(ctx).pop();
                }
              },
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(PartItem item) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت تأكد من حذف "${item.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                if (item.id != null) {
                  await DatabaseHelper.instance.deletePart(item.id!);
                  _refreshParts();
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          centerTitle: true,
          title: const Text('نظام قطع الغيار والمبيعات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1565C0),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'إجمالي القطع',
                            value: '${_filteredParts.length}',
                            icon: Icons.inventory_2_outlined,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'الربح المتوقع',
                            value: '\$${_totalProfit.toStringAsFixed(1)}',
                            icon: Icons.monetization_on_outlined,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن قطعة بالاسم...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF1565C0)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _filteredParts.isEmpty
                          ? const Center(child: Text('لا توجد قطع غيار مسجلة'))
                          : ListView.builder(
                              itemCount: _filteredParts.length,
                              itemBuilder: (context, index) {
                                final item = _filteredParts[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: ListTile(
                                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('شراء: \$${item.buyPrice} | بيع: \$${item.sellPrice}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('\$${item.profit}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _showPartDialog(existingPart: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _confirmDelete(item),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showPartDialog(),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('إضافة قطعة'),
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}