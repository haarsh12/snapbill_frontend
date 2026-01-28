import '../core/config.dart';
import 'api_client.dart';
import '../models/item.dart';

class InventoryService {
  final ApiClient _api = ApiClient();

  // 1. Get All Items
  Future<List<Item>> getItems() async {
    final response = await _api.get('/items');
    // Assuming backend returns a list: [ {item1}, {item2} ]
    return (response as List).map((e) => Item.fromJson(e)).toList();
  }

  // 2. Add Item
  Future<Item> addItem(Item item) async {
    final response = await _api.post('/items', item.toJson());
    return Item.fromJson(response);
  }

  // 3. Update Item (Logic for future)
  Future<void> updateItem(Item item) async {
    // Backend needs PUT /items/{id}
    // await _api.put('/items/${item.id}', item.toJson());
  }

  // 4. Delete Item
  Future<void> deleteItem(String id) async {
    // Backend needs DELETE /items/{id}
    // For now, we will simulate it or implement if backend supports
    // await _api.delete('/items/$id');
  }
}
