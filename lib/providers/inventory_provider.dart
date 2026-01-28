import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/inventory_service.dart';
import '../core/master_list.dart';

class InventoryProvider with ChangeNotifier {
  final InventoryService _service = InventoryService();

  // Start with Master List
  List<Item> _items = List.from(masterInventoryList);

  bool _isLoading = false;
  String _selectedCategory = 'Anaj';

  List<Item> get items => _items;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;

  // Filter Logic for Display
  List<Item> getFilteredItems(String searchQuery) {
    if (searchQuery.isEmpty) {
      return _items.where((i) => i.category == _selectedCategory).toList();
    } else {
      return _items
          .where((i) => i.names
              .any((n) => n.toLowerCase().contains(searchQuery.toLowerCase())))
          .toList();
    }
  }

  // LOGIC TO GET ITEMS FOR BACKEND (Only non-zero price)
  List<Item> getItemsForBackend() {
    return _items.where((i) => i.price > 0).toList();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> fetchItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      final backendItems = await _service.getItems();

      for (var backendItem in backendItems) {
        final index = _items.indexWhere((local) =>
            local.id == backendItem.id ||
            local.names[0] == backendItem.names[0]);

        if (index != -1) {
          _items[index] = backendItem;
        } else {
          // If not in master list, add it
          _items.add(backendItem);
        }
      }
    } catch (e) {
      print("Error fetching items: $e");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addItem(Item newItem) async {
    try {
      final index = _items.indexWhere(
          (i) => i.id == newItem.id || i.names[0] == newItem.names[0]);
      if (index != -1) {
        _items[index] = newItem;
      } else {
        _items.add(newItem);
      }
      notifyListeners();
      await _service.addItem(newItem);
    } catch (e) {
      print("Add Error: $e");
    }
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
    try {
      await _service.deleteItem(id);
    } catch (e) {
      print("Delete Error: $e");
    }
  }
}
