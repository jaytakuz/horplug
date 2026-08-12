import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horplug/viewmodels/refreshable.dart';

class _Fake extends ChangeNotifier with RefreshableViewModel {
  _Fake({this.shouldThrow = false});

  final bool shouldThrow;
  int loadCount = 0;
  final List<({bool loading, bool refreshing})> flagsSeen = [];

  Future<void> load() => runLoad(() async {
        loadCount++;
        flagsSeen.add((loading: isLoading, refreshing: isRefreshing));
        if (shouldThrow) throw Exception('boom');
      });
}

void main() {
  test('โหลดครั้งแรกตั้ง isLoading ไม่ใช่ isRefreshing', () async {
    final vm = _Fake();
    expect(vm.isLoading, isTrue, reason: 'ค่าเริ่มต้นต้องเป็นกำลังโหลด');

    await vm.load();

    expect(vm.flagsSeen.single.loading, isTrue);
    expect(vm.flagsSeen.single.refreshing, isFalse);
    expect(vm.isLoading, isFalse);
    expect(vm.hasLoadedOnce, isTrue);
  });

  test('โหลดครั้งถัดไปตั้ง isRefreshing และไม่แตะ isLoading', () async {
    final vm = _Fake();
    await vm.load();
    await vm.load();

    expect(vm.flagsSeen.last.loading, isFalse,
        reason: 'เนื้อหาเดิมต้องอยู่ครบระหว่างรีเฟรช');
    expect(vm.flagsSeen.last.refreshing, isTrue);
    expect(vm.isRefreshing, isFalse);
  });

  test('ความล้มไม่ทำให้ธงค้าง', () async {
    final vm = _Fake(shouldThrow: true);

    await expectLater(vm.load(), throwsException);

    expect(vm.isLoading, isFalse);
    expect(vm.isRefreshing, isFalse);
  });

  test('แจ้ง listener ทั้งตอนเริ่มและตอนจบ', () async {
    final vm = _Fake();
    var notifications = 0;
    vm.addListener(() => notifications++);

    await vm.load();

    expect(notifications, 2);
  });
}
