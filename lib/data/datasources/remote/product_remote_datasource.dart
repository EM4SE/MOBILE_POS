import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../models/product_model.dart';

abstract class ProductRemoteDataSource {
  Future<List<Product>> fetchAllProductsFromApi({
    String? baseUrl,
    void Function(int count, String status)? onProgress,
  });
  Future<List<Product>> fetchQuickProductsFromApi({String? baseUrl});
  Future<Product?> fetchProductByCode(String code, {String? baseUrl});
  Future<List<Product>> searchProductsLike(String query, {String? baseUrl});
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  final ApiService _apiService;

  ProductRemoteDataSourceImpl([ApiService? apiService])
      : _apiService = apiService ?? ApiService();

  @override
  Future<List<Product>> fetchAllProductsFromApi({
    String? baseUrl,
    void Function(int count, String status)? onProgress,
  }) async {
    final effectiveBaseUrl = baseUrl ?? ApiService.defaultBaseUrl;
    final Map<String, Product> productMap = {};

    void addFromResponse(Map<String, dynamic> res) {
      final cr = res['CommonResult'] ?? res['commonResult'];
      if (cr is Map) {
        for (final entry in cr.entries) {
          if (entry.key.toString().toLowerCase().startsWith('table') && entry.value is List) {
            for (final row in (entry.value as List)) {
              if (row is Map) {
                final p = _mapToProduct(row);
                if (p != null) {
                  productMap[p.code] = p;
                }
              }
            }
          }
        }
      }
    }

    onProgress?.call(0, 'Discovering departments...');

    // 1. Fetch all departments (@Iid = "3")
    List deptList = [];
    try {
      final deptRes = await _apiService.executeCommonSp(
        baseUrl: effectiveBaseUrl,
        spName: 'sp_Android_Common_API',
        con: '1',
        hasReturnData: 'T',
        parameters: [
          {'para_Name': '@Iid', 'para_Type': 'int', 'para_Direction': 'Input', 'para_Data': '3'},
          {'para_Name': '@Text1', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text2', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text3', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
        ],
      );
      deptList = (deptRes['CommonResult']?['Table'] ?? []) as List;
      debugPrint('ProductRemoteDataSource: Found ${deptList.length} departments');
    } catch (e) {
      debugPrint('ProductRemoteDataSource @Iid=3 error: $e');
    }

    onProgress?.call(0, 'Scanning categories across ${deptList.length} departments...');

    // 2. Fetch categories for all departments in parallel
    final List<Map<String, String>> allCategories = [];

    await Future.wait(deptList.map((d) async {
      if (d is! Map) return;
      final dCode = (d['Dept_Code'] ?? d['dept_Code'] ?? '').toString().trim();
      if (dCode.isEmpty) return;

      try {
        final catRes = await _apiService.executeCommonSp(
          baseUrl: effectiveBaseUrl,
          spName: 'sp_Android_Common_API',
          con: '1',
          hasReturnData: 'T',
          parameters: [
            {'para_Name': '@Iid', 'para_Type': 'int', 'para_Direction': 'Input', 'para_Data': '4'},
            {'para_Name': '@Text1', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': dCode},
            {'para_Name': '@Text2', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
            {'para_Name': '@Text3', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
            {'para_Name': '@Text4', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          ],
        );
        addFromResponse(catRes); // direct products in Table1

        final catList = (catRes['CommonResult']?['Table'] ?? []) as List;
        for (final c in catList) {
          if (c is! Map) continue;
          final cCode = (c['Cat_Code'] ?? c['cat_Code'] ?? '').toString().trim();
          if (cCode.isNotEmpty) {
            allCategories.add({'deptCode': dCode, 'catCode': cCode});
          }
        }
      } catch (_) {}
    }));

    debugPrint('ProductRemoteDataSource: Discovered ${allCategories.length} categories to download');

    // 3. Process categories in concurrent batches of 10
    const batchSize = 10;
    for (int i = 0; i < allCategories.length; i += batchSize) {
      final batch = allCategories.sublist(
        i,
        (i + batchSize < allCategories.length) ? i + batchSize : allCategories.length,
      );

      final progressPercent = ((i / allCategories.length) * 100).toInt();
      onProgress?.call(
        productMap.length,
        'Downloading items: $progressPercent% (${productMap.length} products found)...',
      );

      await Future.wait(batch.map((cat) async {
        try {
          final prodRes = await _apiService.executeCommonSp(
            baseUrl: effectiveBaseUrl,
            spName: 'sp_Android_Common_API',
            con: '1',
            hasReturnData: 'T',
            parameters: [
              {'para_Name': '@Iid', 'para_Type': 'int', 'para_Direction': 'Input', 'para_Data': '5'},
              {'para_Name': '@Text1', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': cat['deptCode']!},
              {'para_Name': '@Text2', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': cat['catCode']!},
              {'para_Name': '@Text3', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
              {'para_Name': '@Text4', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
            ],
          );
          addFromResponse(prodRes);
        } catch (_) {}
      }));

      // Brief yield to allow UI frame updates and avoid socket exhaustion
      await Future.delayed(const Duration(milliseconds: 5));
    }

    // 4. Also fetch favorite / quick items (@Iid = "54")
    try {
      final favRes = await _apiService.executeCommonSp(
        baseUrl: effectiveBaseUrl,
        spName: 'sp_Android_Common_API',
        con: '1',
        hasReturnData: 'T',
        parameters: [
          {'para_Name': '@Iid', 'para_Type': 'int', 'para_Direction': 'Input', 'para_Data': '54'},
          {'para_Name': '@Text1', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text2', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text3', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text4', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
        ],
      );
      addFromResponse(favRes);
    } catch (_) {}

    onProgress?.call(productMap.length, 'Completed: ${productMap.length} products ready');
    debugPrint('ProductRemoteDataSource: Total products downloaded: ${productMap.length}');
    return productMap.values.toList();
  }

  @override
  Future<List<Product>> fetchQuickProductsFromApi({String? baseUrl}) async {
    final effectiveBaseUrl = baseUrl ?? ApiService.defaultBaseUrl;
    final Map<String, Product> productMap = {};

    try {
      final favRes = await _apiService.executeCommonSp(
        baseUrl: effectiveBaseUrl,
        spName: 'sp_Android_Common_API',
        con: '1',
        hasReturnData: 'T',
        parameters: [
          {'para_Name': '@Iid', 'para_Type': 'int', 'para_Direction': 'Input', 'para_Data': '54'},
          {'para_Name': '@Text1', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text2', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text3', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text4', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
        ],
      );

      final cr = favRes['CommonResult'] ?? favRes['commonResult'];
      if (cr is Map) {
        for (final entry in cr.entries) {
          if (entry.key.toString().toLowerCase().startsWith('table') && entry.value is List) {
            for (final row in (entry.value as List)) {
              if (row is Map) {
                final p = _mapToProduct(row);
                if (p != null) {
                  productMap[p.code] = p;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ProductRemoteDataSource quick fetch notice: $e');
    }

    return productMap.values.toList();
  }

  @override
  Future<Product?> fetchProductByCode(String code, {String? baseUrl}) async {
    final effectiveBaseUrl = baseUrl ?? ApiService.defaultBaseUrl;

    // 1. Try Barcode Scan endpoint @Iid = "65" (matching RHINO M10P InvoiceFragment line 5267)
    try {
      final res65 = await _apiService.executeCommonSp(
        baseUrl: effectiveBaseUrl,
        spName: 'sp_Android_Common_API',
        con: '1',
        hasReturnData: 'T',
        parameters: [
          {'para_Name': '@Iid', 'para_Type': 'int', 'para_Direction': 'Input', 'para_Data': '65'},
          {'para_Name': '@Text1', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': code.trim()},
          {'para_Name': '@Text2', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': 'PROD'},
          {'para_Name': '@Text3', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text4', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
        ],
      );
      final cr = res65['CommonResult'] ?? res65['commonResult'];
      if (cr is Map) {
        for (final entry in cr.entries) {
          if (entry.key.toString().toLowerCase().startsWith('table') && entry.value is List) {
            for (final row in (entry.value as List)) {
              if (row is Map) {
                final p = _mapToProduct(row);
                if (p != null) return p;
              }
            }
          }
        }
      }
    } catch (_) {}

    // 2. Fallback to @Iid = "11" (Product Code lookup)
    try {
      final response = await _apiService.executeCommonSp(
        baseUrl: effectiveBaseUrl,
        spName: 'sp_Android_Common_API',
        con: '1',
        hasReturnData: 'T',
        parameters: [
          {'para_Name': '@Iid', 'para_Type': 'int', 'para_Direction': 'Input', 'para_Data': '11'},
          {'para_Name': '@Text1', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': code.trim()},
          {'para_Name': '@Text2', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text3', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text4', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
        ],
      );

      final cr = response['CommonResult'] ?? response['commonResult'];
      if (cr is Map) {
        for (final entry in cr.entries) {
          if (entry.key.toString().toLowerCase().startsWith('table') && entry.value is List) {
            for (final row in (entry.value as List)) {
              if (row is Map) {
                final p = _mapToProduct(row);
                if (p != null) return p;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ProductRemoteDataSource fetchProductByCode failed: $e');
    }
    return null;
  }

  @override
  Future<List<Product>> searchProductsLike(String query, {String? baseUrl}) async {
    final effectiveBaseUrl = baseUrl ?? ApiService.defaultBaseUrl;
    final List<Product> products = [];
    try {
      final response = await _apiService.executeCommonSp(
        baseUrl: effectiveBaseUrl,
        spName: 'sp_Android_Common_API',
        con: '1',
        hasReturnData: 'T',
        parameters: [
          {'para_Name': '@Iid', 'para_Type': 'int', 'para_Direction': 'Input', 'para_Data': '24'},
          {'para_Name': '@Text1', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': query.trim()},
          {'para_Name': '@Text2', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text3', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
          {'para_Name': '@Text4', 'para_Type': 'varchar', 'para_Direction': 'Input', 'para_Data': ''},
        ],
      );

      final cr = response['CommonResult'] ?? response['commonResult'];
      if (cr is Map) {
        for (final entry in cr.entries) {
          if (entry.key.toString().toLowerCase().startsWith('table') && entry.value is List) {
            for (final row in (entry.value as List)) {
              if (row is Map) {
                final p = _mapToProduct(row);
                if (p != null) products.add(p);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('ProductRemoteDataSource searchProductsLike failed: $e');
    }
    return products;
  }

  Product? _mapToProduct(Map item) {
    final code = (item['Prod_Code'] ?? 
                  item['prod_Code'] ?? 
                  item['Product_Code'] ?? 
                  item['Code'] ?? 
                  item['code'] ?? 
                  '').toString().trim();
    if (code.isEmpty) return null;

    final name = (item['Prod_Name'] ?? 
                  item['prod_Name'] ?? 
                  item['Short_Description'] ?? 
                  item['short_Description'] ?? 
                  item['Short_Descrip'] ?? 
                  item['short_Descrip'] ?? 
                  item['Prod_Descrip'] ?? 
                  item['Description'] ?? 
                  item['Description1'] ?? 
                  item['des'] ?? 
                  item['ShortName'] ?? 
                  code).toString().trim();

    final priceStr = (item['Selling_Price'] ?? 
                      item['selling_Price'] ?? 
                      item['Price'] ?? 
                      item['price'] ?? 
                      item['Marked_Price'] ?? 
                      '0').toString().trim();

    final costStr = (item['Purchase_Price'] ?? 
                     item['purchase_Price'] ?? 
                     item['pPrice'] ?? 
                     item['Cost'] ?? 
                     item['cost'] ?? 
                     '0').toString().trim();

    final barcodeVal = (item['Barcode'] ?? 
                        item['barcode'] ?? 
                        item['Item_Barcode'] ?? 
                        item['Bar_Code'] ?? 
                        item['BarCode'] ?? 
                        '').toString().trim();

    final isbnVal = (item['Isbn'] ?? 
                     item['isbn'] ?? 
                     item['ISBN'] ?? 
                     item['Isbn_No'] ?? 
                     item['isbn_No'] ?? 
                     item['ISBN_NO'] ?? 
                     item['IsbnNo'] ?? 
                     '').toString().trim();

    final finalBarcode = barcodeVal.isNotEmpty
        ? barcodeVal
        : (isbnVal.isNotEmpty ? isbnVal : code);

    return Product(
      code: code,
      barcode: finalBarcode,
      isbn: isbnVal,
      description: name.isNotEmpty ? name : code,
      price: double.tryParse(priceStr) ?? 0.0,
      cost: double.tryParse(costStr) ?? 0.0,
      active: true,
    );
  }
}
