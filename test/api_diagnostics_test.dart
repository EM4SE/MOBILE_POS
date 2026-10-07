import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/services/api_service.dart';
import 'package:mobile_pos/data/models/product_model.dart';

void main() {
  test('Fast concurrent product sync test', () async {
    final api = ApiService();
    final stopwatch = Stopwatch()..start();
    final Map<String, Product> productMap = {};

    Product? mapItem(Map item) {
      final code = (item['Prod_Code'] ?? item['prod_Code'] ?? item['Product_Code'] ?? item['Code'] ?? item['code'] ?? '').toString().trim();
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

      final barcode = (item['Barcode'] ?? 
                       item['barcode'] ?? 
                       item['Item_Barcode'] ?? 
                       item['Bar_Code'] ?? 
                       code).toString().trim();

      return Product(
        code: code,
        barcode: barcode.isNotEmpty ? barcode : code,
        description: name.isNotEmpty ? name : code,
        price: double.tryParse(priceStr) ?? 0.0,
        cost: double.tryParse(costStr) ?? 0.0,
        active: true,
      );
    }

    void addFromResponse(Map<String, dynamic> res) {
      final cr = res['CommonResult'] ?? res['commonResult'];
      if (cr is Map) {
        for (final entry in cr.entries) {
          if (entry.key.toString().toLowerCase().startsWith('table') && entry.value is List) {
            for (final row in (entry.value as List)) {
              if (row is Map) {
                final p = mapItem(row);
                if (p != null) {
                  productMap[p.code] = p;
                }
              }
            }
          }
        }
      }
    }

    // 1. Fetch departments
    final deptRes = await api.executeCommonSp(
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

    final deptTable = (deptRes['CommonResult']?['Table'] ?? []) as List;
    print('Fetched ${deptTable.length} departments');

    // 2. Fetch categories for all departments
    final List<Map<String, String>> allCategories = []; // {deptCode, catCode}

    await Future.wait(deptTable.map((d) async {
      if (d is! Map) return;
      final dCode = d['Dept_Code']?.toString() ?? '';
      if (dCode.isEmpty) return;

      try {
        final catRes = await api.executeCommonSp(
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
          final cCode = c['Cat_Code']?.toString() ?? '';
          if (cCode.isNotEmpty) {
            allCategories.add({'deptCode': dCode, 'catCode': cCode});
          }
        }
      } catch (_) {}
    }));

    print('Discovered ${allCategories.length} categories across all departments in ${stopwatch.elapsedMilliseconds}ms');

    // 3. Process categories in concurrent batches of 15
    const batchSize = 15;
    for (int i = 0; i < allCategories.length; i += batchSize) {
      final batch = allCategories.sublist(
        i,
        (i + batchSize < allCategories.length) ? i + batchSize : allCategories.length,
      );

      await Future.wait(batch.map((cat) async {
        try {
          final prodRes = await api.executeCommonSp(
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
    }

    print('=== FINISHED SYNC: ${productMap.length} PRODUCTS IN ${stopwatch.elapsedMilliseconds}ms ===');
    final sample = productMap.values.take(5).toList();
    for (final s in sample) {
      print('Product: [${s.code}] ${s.description} • Price: Rs. ${s.price}');
    }
  });
}
