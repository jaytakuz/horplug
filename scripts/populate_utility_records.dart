import 'dart:convert';

void main() async {
  // Initialize Supabase (must be done before using the client)
  print('🔌 Initializing Supabase...');

  // You need to set up Supabase credentials
  // For now, showing the data structure

  final newRecords = _generateUtilityRecords();

  print(
      '\n📊 Generated ${newRecords.length} utility records for May-June 2026');
  print('\n📋 Sample records:');
  for (int i = 0; i < 3; i++) {
    print('  ${jsonEncode(newRecords[i])}');
  }

  print('\n✅ Ready to insert into Supabase!');
  print('\nTo insert into Supabase:');
  print('1. Replace Supabase.initialize() with your actual credentials');
  print('2. Uncomment the insertion code below');
  print('3. Run: dart scripts/populate_utility_records.dart');
}

List<Map<String, dynamic>> _generateUtilityRecords() {
  final records = <Map<String, dynamic>>[];
  int id = 121;

  final rooms = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  final random = DateTime.now().millisecond;

  // Generate for May 2026 and June 2026
  for (int month = 5; month <= 6; month++) {
    for (final room in rooms) {
      // Electricity record
      final prevReading = 3000 + (room * 100) + (month * 50);
      final currentReading = prevReading + 30 + (random % 120);
      final units = currentReading - prevReading;
      final amount = units * 8.0;

      records.add({
        'id': id++,
        'room_id': room,
        'utility_type': 'electricity',
        'billing_month': month,
        'billing_year': 2026,
        'previous_value': prevReading,
        'current_value': currentReading,
        'unit_rate': 8.0,
        'amount': amount,
        'recorded_at':
            DateTime(2026, month, 15 + (random % 10)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Water record
      final waterAmount = 80.0 + (random % 80);
      records.add({
        'id': id++,
        'room_id': room,
        'utility_type': 'water',
        'billing_month': month,
        'billing_year': 2026,
        'previous_value': null,
        'current_value': null,
        'unit_rate': waterAmount,
        'amount': waterAmount,
        'recorded_at':
            DateTime(2026, month, 15 + (random % 10)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  return records;
}

/* Uncomment this section to insert into Supabase:

Future<void> _insertRecords(List<Map<String, dynamic>> records) async {
  final client = Supabase.instance.client;
  
  try {
    print('\n🔄 Inserting ${records.length} records into utility_records table...');
    
    // Insert in batches of 10
    for (int i = 0; i < records.length; i += 10) {
      final batch = records.sublist(
        i,
        (i + 10 > records.length) ? records.length : i + 10,
      );
      
      await client.from('utility_records').insert(batch);
      print('✅ Inserted batch ${(i ~/ 10) + 1} (${batch.length} records)');
    }
    
    print('\n✨ All records inserted successfully!');
  } catch (e) {
    print('❌ Error inserting records: $e');
    rethrow;
  }
}
*/
