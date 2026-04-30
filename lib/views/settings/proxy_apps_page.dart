import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/proxy_apps_controller.dart';
import '../../app/theme.dart';

class ProxyAppsPage extends StatelessWidget {
  const ProxyAppsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProxyAppsController());

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("分应用代理"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.theme.colorScheme.surface.withOpacity(0.8),
                context.theme.colorScheme.surface.withOpacity(0.5),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 背景装饰
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.theme.colorScheme.primary.withOpacity(0.05),
              ),
            ),
          ),
          
          Column(
            children: [
              const SizedBox(height: kToolbarHeight + 20),
              // 搜索框
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  onChanged: (v) => controller.searchQuery.value = v,
                  decoration: InputDecoration(
                    hintText: "搜索应用名称或包名...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: context.theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final displayApps = controller.filteredApps;

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: displayApps.length,
                    itemBuilder: (context, index) {
                      final app = displayApps[index];
                      final isSelected = controller.selectedPackages.contains(app['packageName']);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.theme.colorScheme.surface.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                              ? context.theme.colorScheme.primary.withOpacity(0.3)
                              : Colors.transparent,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => controller.toggleApp(app['packageName']!),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: context.theme.colorScheme.primaryContainer.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.android, size: 24),
                          ),
                          title: Text(
                            app['name']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            app['packageName']!,
                            style: TextStyle(fontSize: 11, color: context.theme.colorScheme.outline),
                          ),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: null, // 统一由 ListTile 的 onTap 处理，防止双重触发导致状态抵消
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.back(),
        label: const Text("保存并返回"),
        icon: const Icon(Icons.check),
      ),
    );
  }
}
