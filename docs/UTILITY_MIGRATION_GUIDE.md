# Utility Billing Migration Guide

## Overview
This migration transforms the utility records system from snapshot format to a normalized **one row per utility per month** schema. This enables:
- Accurate monthly billing calculations
- Historical tracking of meter readings and charges  
- Automatic billing period generation
- Easy future extensions (rate changes, seasonal pricing, etc.)

## Files

### 1. Migration Script
**File**: `database/utility_records_normalization.sql`

**What it does**:
- Creates `utility_records_new` table with normalized schema
- Migrates electricity records using window functions to calculate previous meter readings
- Migrates water records with fixed monthly charges
- Creates composite unique index on `(room_id, utility_type, billing_month, billing_year)`
- Renames old table to `utility_records_archive` for rollback capability
- Creates auto-update trigger for `updated_at` timestamp

**How to run**:
```bash
# Execute on Supabase via SQL Editor or CLI
psql postgresql://user:password@db.host/horplug < database/utility_records_normalization.sql
```

### 2. Seed Data Script
**File**: `database/seed_utility_data_5months.sql`

**What it does**:
- Generates monthly utility records for Jan-Jun 2026 (6 months total)
- Creates records for all occupied rooms in the dormitory
- Electricity: Simulates realistic meter progression with incremental readings
  - Each month increases by 50 units
  - Previous value calculated from previous month's current value
  - Amount = (current - previous) × unit_rate
- Water: Fixed monthly charges (100 baht per month by default)
  - No meter readings (previous_value = NULL)
  - Amount = fixed charge

**How to run**:
```bash
# Execute AFTER running the migration script
psql postgresql://user:password@db.host/horplug < database/seed_utility_data_5months.sql
```

**Data Structure**:
```sql
-- Example electricity record for Room 1, June 2026
room_id: 1
utility_type: 'electricity'
billing_month: 6
billing_year: 2026
previous_value: 3249.0   -- Previous month meter reading
current_value: 3300.0    -- Current month meter reading  
unit_rate: 8.0           -- Baht per unit
amount: 408.0            -- (3300 - 3249) × 8 = 51 × 8

-- Example water record for Room 1, June 2026
room_id: 1
utility_type: 'water'
billing_month: 6
billing_year: 2026
previous_value: NULL     -- Water is not meter-based
current_value: 100.0     -- Fixed monthly charge
unit_rate: 100.0         -- Fixed charge
amount: 100.0            -- Direct charge
```

## Code Changes

### Dart Service Layer Changes
**File**: `lib/services/supabase_service.dart`

**New Features**:

1. **Automatic Billing Period Generation**
   ```dart
   // Old: Manual billing_month/year in UI
   // New: Auto-generated from current date
   
   (int, int) _getCurrentBillingPeriod({DateTime? billingDate}) {
     final now = (billingDate ?? DateTime.now()).toUtc();
     return (now.month, now.year);
   }
   ```

2. **Updated saveUtilityMeterRecords**
   ```dart
   Future<void> saveUtilityMeterRecords(
     List<UtilityMeterRecord> records,
     {DateTime? billingDate}  // Optional: override billing date
   ) async {
     final (currentMonth, currentYear) = _getCurrentBillingPeriod(billingDate: billingDate);
     
     for (final record in records) {
       // Auto-assign current billing period
       record.billingMonth = currentMonth;
       record.billingYear = currentYear;
       // ... rest of logic
     }
   }
   ```

**Benefits**:
- Records automatically use current month/year when saved
- Optional `billingDate` parameter for backdated entries (historical data)
- No manual billing period management in UI code
- Future billing period changes (e.g., fiscal year) only need backend updates

### Data Model
**File**: `lib/models/models.dart` (already updated in previous phase)

**Key Fields**:
```dart
class UtilityMeterRecord {
  final int billingMonth;      // 1-12, auto-populated on save
  final int billingYear;       // 2026+, auto-populated on save
  final double? previousValue; // Previous meter reading (electricity only)
  double? currentValue;        // Current meter reading or charge
  double unitRate;             // Rate per unit or fixed charge
  double amount;               // Calculated amount
}
```

## Execution Sequence

### Phase 1: Schema Migration (Production)
```bash
# 1. Backup current data
# 2. Run migration script
psql ... < database/utility_records_normalization.sql
# 3. Verify row counts
SELECT utility_type, COUNT(*) FROM utility_records GROUP BY utility_type;
# Expected: electricity count + water count = old count
```

### Phase 2: Seed Historical Data (Testing/QA)
```bash
# Run seed script to populate past 5 months
psql ... < database/seed_utility_data_5months.sql
# Verify data loaded
SELECT DISTINCT billing_month, COUNT(*) FROM utility_records GROUP BY billing_month;
```

### Phase 3: Deploy Code Changes
```bash
# Update Flutter app with modified Dart code
flutter pub get
flutter analyze lib/services/supabase_service.dart  # Verify no errors
flutter run
```

### Phase 4: End-to-End Testing
```dart
// Test 1: Load records
final records = await supabase.fetchUtilityMeterRecords();
assert(records.isNotEmpty);  // Should include June 2026 data

// Test 2: Save new record (auto billing period)
final newRecords = [...];
await supabase.saveUtilityMeterRecords(newRecords);
// Verify: billing_month = 6, billing_year = 2026 (current date)

// Test 3: Save backdated record
final pastDate = DateTime(2026, 5, 15);
await supabase.saveUtilityMeterRecords(backupRecords, billingDate: pastDate);
// Verify: billing_month = 5, billing_year = 2026
```

## Key Features

### 1. Automatic Billing Month/Year
- No manual input required in UI
- Derived from current system date
- Optional override for historical entries
- Ensures consistency across all records

### 2. Water Charge Migration
- Old `water_rate` field → New `amount` field (fixed charge)
- No meter readings (previous_value = NULL)
- Preserves existing rates from dormitory defaults
- Ready for rate adjustments per month

### 3. Electricity Meter Calculation
- Window functions calculate previous meter readings
- Automatic consumption calculation: `current - previous`
- Amount = consumption × unit_rate
- Prevents negative consumption with GREATEST()

### 4. Composite Unique Key
- Prevents duplicate records: `(room_id, utility_type, billing_month, billing_year)`
- Enables upsert for updates
- Enforces data integrity

### 5. Extensibility
- `unit_rate` can vary per month (future seasonal pricing)
- `recorded_at` vs `created_at` tracks when meter was read vs recorded
- Trigger auto-updates `updated_at` for audit trails
- Archive table preserved for rollback/audit

## Future Enhancements

### Seasonal Pricing
```sql
-- Example: Different rates for peak/off-peak seasons
SELECT 
  CASE WHEN billing_month BETWEEN 4 AND 9 
    THEN 10  -- Peak season rate
    ELSE 8   -- Off-peak rate
  END AS seasonal_rate
```

### Rate Changes
```dart
// Can store different rates per month
// Allow manual override of auto-calculated unit_rate
record.unitRate = 9.5;  // Custom rate for this month
```

### Deposit/Credit Management
```sql
-- Add fields to track deposits and credits
ALTER TABLE utility_records ADD COLUMN deposit_paid NUMERIC DEFAULT 0;
ALTER TABLE utility_records ADD COLUMN late_charge NUMERIC DEFAULT 0;
ALTER TABLE utility_records ADD COLUMN credit_applied NUMERIC DEFAULT 0;
```

## Rollback Plan

If issues occur:
```sql
-- 1. Rename new table back
ALTER TABLE utility_records RENAME TO utility_records_new;
ALTER TABLE utility_records_archive RENAME TO utility_records;

-- 2. Drop archive after verification
DROP TABLE IF EXISTS utility_records_archive;
```

## Verification Checklist

- [ ] Migration executes without errors
- [ ] Row count unchanged: `SELECT COUNT(*) FROM utility_records`
- [ ] Composite key constraint works: Try duplicate entry
- [ ] Electricity records have previous_value (except first month)
- [ ] Water records have NULL previous_value
- [ ] Seed data loads successfully for all 6 months
- [ ] Flutter app builds without errors
- [ ] fetch returns June 2026 records
- [ ] save auto-assigns current billing period
- [ ] UI displays electricity/water calculations correctly
