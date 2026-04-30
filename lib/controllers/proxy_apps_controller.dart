import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

class ProxyAppsController extends GetxController {
  final apps = <Map<String, String>>[].obs;
  final selectedPackages = <String>{}.obs;
  final isLoading = true.obs;
  final searchQuery = "".obs;

  late Box _box;

  @override
  void onInit() {
    super.onInit();
    _initData();
  }

  Future<void> _initData() async {
    _box = await Hive.openBox('proxy_settings');
    
    // 加载已保存的勾选内容
    final saved = _box.get('allowed_apps', defaultValue: <String>[]);
    selectedPackages.addAll(List<String>.from(saved));

    await fetchApps();
  }

  Future<void> fetchApps() async {
    isLoading.value = true;
    try {
      const channel = MethodChannel('com.tianque.appmi/vpn');
      final List<dynamic> result = await channel.invokeMethod('getInstalledApps');
      
      apps.value = result.map((e) => Map<String, String>.from(e)).toList();
      // 排序：把已勾选的放前面，其余按字典序
      apps.sort((a, b) {
        bool selectedA = selectedPackages.contains(a['packageName']);
        bool selectedB = selectedPackages.contains(b['packageName']);
        if (selectedA != selectedB) return selectedA ? -1 : 1;
        return a['name']!.compareTo(b['name']!);
      });
    } catch (e) {
      print("[ProxyApps] Fetch failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void toggleApp(String packageName) {
    if (selectedPackages.contains(packageName)) {
      selectedPackages.remove(packageName);
    } else {
      selectedPackages.add(packageName);
    }
    _box.put('allowed_apps', selectedPackages.toList());
    selectedPackages.refresh(); // 🚀 强制刷新 RxSet 确保 Obx 感知到变化
  }

  List<Map<String, String>> get filteredApps {
    if (searchQuery.isEmpty) return apps;
    return apps.where((app) => 
      app['name']!.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
      app['packageName']!.toLowerCase().contains(searchQuery.value.toLowerCase())
    ).toList();
  }
}
