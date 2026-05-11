import 'dart:developer';

import 'package:flutter/foundation.dart';
import '../services/example_field_delay_service.dart';
import '../model/product_model.dart';

class ExampleFieldDelayProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  
  // Pagination state
  final int _limit = 40;
  int _offset = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _loadMoreError;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get loadMoreError => _loadMoreError;
  int get limit => _limit;
  int get offset => _offset;

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    _loadMoreError = null;
    _offset = 0;
    _hasMore = true;
    notifyListeners();

    try {
      final result = await ExampleFieldDelayService.fetchProducts(
        limit: _limit,
        offset: _offset,
      );
      _products = result;
      _offset = _products.length;
      _hasMore = result.length == _limit;
    } catch (e) {
      log("catch : ${e.toString()}");
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    // Clear current items first so UI can show proper error state on failure
    _products = [];
    _error = null;
    _loadMoreError = null;
    _offset = 0;
    _hasMore = true;
    notifyListeners();
    await loadProducts();
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final result = await ExampleFieldDelayService.fetchProducts(
        limit: _limit,
        offset: _offset,
      );
      _products = [..._products, ...result];
      _offset += result.length;
      _hasMore = result.length == _limit;
    } catch (e) {
      _loadMoreError = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> nextPage() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final result = await ExampleFieldDelayService.fetchProducts(
        limit: _limit,
        offset: _offset,
      );
      // Replace current items with next page
      _products = result;
      _offset += result.length;
      _hasMore = result.length == _limit;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> prevPage() async {
    if (_isLoading) return;
    final int newOffset = (_offset - _limit) < 0 ? 0 : (_offset - _limit);
    if (newOffset == _offset) return;

    _isLoading = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final result = await ExampleFieldDelayService.fetchProducts(
        limit: _limit,
        offset: newOffset,
      );
      _products = result;
      _offset = newOffset + result.length;
      _hasMore = result.length == _limit;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
