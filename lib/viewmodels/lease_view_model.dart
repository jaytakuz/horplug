import 'package:flutter/foundation.dart';

import '../mock/mock_data.dart';
import '../models/models.dart';

class LeaseViewModel extends ChangeNotifier {
  bool isPreview = false;
  String? selectedRoom;

  List<Room> get vacantRooms =>
      MockData.rooms.where((r) => r.status == RoomStatus.vacant).toList();

  void selectRoom(String? roomId) {
    selectedRoom = roomId;
    notifyListeners();
  }

  void showPreview() {
    isPreview = true;
    notifyListeners();
  }

  void backToForm() {
    isPreview = false;
    notifyListeners();
  }

  void confirmLease() {
    isPreview = false;
    notifyListeners();
  }
}
