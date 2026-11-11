import 'base_repository.dart';

/// Manages vertical business module records (restaurant tables/KOT, gym, hotel rooms, repair jobs).
class IndustryModulesRepository extends BaseRepository {
  const IndustryModulesRepository([super.dbService]);

  Future<List<Map<String, dynamic>>> getRestaurantTables({String? section}) async {
    final where = (section != null && section != 'All') ? 'section = ?' : null;
    final whereArgs = (section != null && section != 'All') ? [section] : null;
    return await db.query('restaurant_tables', where: where, whereArgs: whereArgs, orderBy: 'id ASC');
  }

  Future<int> addRestaurantTable(Map<String, dynamic> table) async {
    return await db.insert('restaurant_tables', table);
  }

  Future<int> updateRestaurantTable(int id, Map<String, dynamic> table) async {
    return await db.update('restaurant_tables', table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRestaurantTable(int id) async {
    return await db.delete('restaurant_tables', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getRestaurantKotOrders() async {
    return await db.query('restaurant_kot_orders', orderBy: 'id DESC');
  }

  Future<int> addRestaurantKotOrder(Map<String, dynamic> order) async {
    return await db.insert('restaurant_kot_orders', order);
  }

  Future<int> updateRestaurantKotStatus(int id, String status) async {
    return await db.update('restaurant_kot_orders', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRestaurantKotOrder(int id) async {
    return await db.delete('restaurant_kot_orders', where: 'id = ?', whereArgs: [id]);
  }


// ===================== INDUSTRY MODULE OPERATIONS (DYNAMIC SQLITE) =====================

  // Gym & Fitness Members
  Future<List<Map<String, dynamic>>> getGymMembers({String? status}) async {
    final where = (status != null && status != 'All') ? 'status = ?' : null;
    final whereArgs = (status != null && status != 'All') ? [status] : null;
    return await db.query(
      'gym_members',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
  }

  Future<int> addGymMember(Map<String, dynamic> member) async {
    return await db.insert('gym_members', member);
  }

  Future<int> updateGymMember(int id, Map<String, dynamic> member) async {
    return await db.update('gym_members', member, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGymMember(int id) async {
    return await db.delete('gym_members', where: 'id = ?', whereArgs: [id]);
  }

  // Hotel & Guest Rooms
  Future<List<Map<String, dynamic>>> getHotelRooms({String? status}) async {
    final where = (status != null && status != 'all') ? 'status = ?' : null;
    final whereArgs = (status != null && status != 'all') ? [status] : null;
    return await db.query(
      'hotel_rooms',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'room ASC',
    );
  }

  Future<int> addHotelRoom(Map<String, dynamic> room) async {
    return await db.insert('hotel_rooms', room);
  }

  Future<int> updateHotelRoom(int id, Map<String, dynamic> room) async {
    return await db.update('hotel_rooms', room, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteHotelRoom(int id) async {
    return await db.delete('hotel_rooms', where: 'id = ?', whereArgs: [id]);
  }

  // Repair & Service Jobs
  Future<List<Map<String, dynamic>>> getRepairJobs({String? status}) async {
    final where = (status != null && status != 'All') ? 'status = ?' : null;
    final whereArgs = (status != null && status != 'All') ? [status] : null;
    return await db.query(
      'repair_jobs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
  }

  Future<int> addRepairJob(Map<String, dynamic> job) async {
    return await db.insert('repair_jobs', job);
  }

  Future<int> updateRepairJob(int id, Map<String, dynamic> job) async {
    return await db.update('repair_jobs', job, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRepairJob(int id) async {
    return await db.delete('repair_jobs', where: 'id = ?', whereArgs: [id]);
  }


  Future<int> updateRestaurantTableStatus(
    int id,
    String status, {
    double? orderTotal,
    String? kotTime,
    String? waiterName,
    int? waiterId,
    int? currentSaleId,
  }) async {
    final updates = <String, dynamic>{'status': status};
    if (orderTotal != null) updates['order_total'] = orderTotal;
    if (kotTime != null) updates['kot_time'] = kotTime;
    if (waiterName != null) updates['waiter_name'] = waiterName;
    if (waiterId != null) updates['waiter_id'] = waiterId;
    if (currentSaleId != null) updates['current_sale_id'] = currentSaleId;
    return await db.update('restaurant_tables', updates, where: 'id = ?', whereArgs: [id]);
  }


}
