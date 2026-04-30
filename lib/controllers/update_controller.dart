import 'dart:io';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class UpdateController extends GetxController {
  final String repoUrl = "https://api.github.com/repos/tianquege/MClash-TianQue/releases/latest";
  
  RxString currentVersion = "".obs;
  RxString latestVersion = "".obs;
  RxString releaseNotes = "".obs;
  RxString downloadUrl = "".obs;
  RxBool isChecking = false.obs;
  RxDouble downloadProgress = 0.0.obs;
  RxString updateStatus = "准备下载...".obs;

  @override
  void onInit() {
    super.onInit();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    currentVersion.value = info.version;
  }

  Future<void> checkUpdate({bool showToast = false}) async {
    isChecking.value = true;
    try {
      final dio = Dio();
      final response = await dio.get(repoUrl);
      
      if (response.statusCode == 200) {
        final data = response.data;
        latestVersion.value = data['tag_name']?.toString().replaceAll('v', '') ?? "";
        releaseNotes.value = data['body'] ?? "没有更新说明";
        
        // 智能提取对应平台的资源包
        if (data['assets'] != null && (data['assets'] as List).isNotEmpty) {
          final List assets = data['assets'];
          String? platformAsset;
          
          if (Platform.isAndroid) {
            platformAsset = assets.firstWhere((a) => a['name'].toString().endsWith('.apk'), orElse: () => null)?['browser_download_url'];
          } else if (Platform.isWindows) {
            platformAsset = assets.firstWhere((a) => a['name'].toString().endsWith('.exe'), orElse: () => null)?['browser_download_url'] ??
                            assets.firstWhere((a) => a['name'].toString().endsWith('.zip'), orElse: () => null)?['browser_download_url'];
          } else if (Platform.isMacOS) {
            platformAsset = assets.firstWhere((a) => a['name'].toString().endsWith('.dmg'), orElse: () => null)?['browser_download_url'] ??
                            assets.firstWhere((a) => a['name'].toString().endsWith('.zip'), orElse: () => null)?['browser_download_url'];
          }
          
          downloadUrl.value = platformAsset ?? assets[0]['browser_download_url'];
        }

        if (_isNewer(latestVersion.value, currentVersion.value)) {
          _showUpdateDialog();
        } else if (showToast) {
          _showToast("您的软件已是最新版本 (v${currentVersion.value})", isError: false);
        }
      }
    } catch (e) {
      if (showToast) _showToast("无法连接到 GitHub，请检查网络", isError: true);
    } finally {
      isChecking.value = false;
    }
  }

  bool _isNewer(String latest, String current) {
    if (latest.isEmpty || current.isEmpty) return false;
    List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    for (int i = 0; i < l.length && i < c.length; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return l.length > c.length;
  }

  void _showToast(String msg, {required bool isError}) {
    Get.snackbar(
      isError ? "更新失败" : "检查更新", 
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: (isError ? Colors.redAccent : Colors.indigo).withOpacity(0.9),
      colorText: Colors.white,
      margin: const EdgeInsets.all(15),
      borderRadius: 15,
      icon: Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
    );
  }

  void _showUpdateDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.rocket_launch_rounded, color: Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            Text("新版本 v${latestVersion.value}", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("📦 更新日志:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Text(releaseNotes.value, style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("稍后再说", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Get.back();
              _startDownloadFlow();
            },
            child: const Text("立即更新", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startDownloadFlow() {
    if (downloadUrl.isEmpty) return;
    
    _showProgressDialog();

    if (Platform.isAndroid) {
      _doAndroidUpdate();
    } else {
      _doDesktopUpdate();
    }
  }

  void _showProgressDialog() {
    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("正在极速下载更新...", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: downloadProgress.value / 100,
                  minHeight: 10,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(updateStatus.value, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text("${downloadProgress.value.toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ],
              ),
            ],
          )),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _doAndroidUpdate() {
    try {
      OtaUpdate().execute(downloadUrl.value, destinationFilename: 'mclash_new.apk').listen((OtaEvent event) {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            downloadProgress.value = double.tryParse(event.value ?? "0") ?? 0;
            updateStatus.value = "正在下载资源包...";
            break;
          case OtaStatus.INSTALLING:
            Get.back();
            updateStatus.value = "下载完成，准备安装";
            break;
          case OtaStatus.INTERNAL_ERROR:
            Get.back();
            _showToast("系统安装器内部错误", isError: true);
            break;
          case OtaStatus.DOWNLOAD_ERROR:
            Get.back();
            _showToast("下载过程发生网络中断", isError: true);
            break;
          case OtaStatus.ALREADY_RUNNING_ERROR:
            Get.back();
            _showToast("更新任务已在运行", isError: true);
            break;
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            Get.back();
            _showToast("请授予存储与安装权限以完成更新", isError: true);
            break;
          default:
            Get.back();
            _showToast("状态异常: ${event.status}", isError: true);
        }
      });
    } catch (e) {
      Get.back();
      _showToast("更新引擎启动失败", isError: true);
    }
  }

  Future<void> _doDesktopUpdate() async {
    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final extension = Platform.isWindows ? '.exe' : '.dmg';
      final savePath = p.join(tempDir.path, "mclash_installer$extension");

      await dio.download(
        downloadUrl.value,
        savePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            downloadProgress.value = (count / total * 100);
            updateStatus.value = "正在下载安装程序...";
          }
        },
      );

      updateStatus.value = "下载完成，正在启动安装程序...";
      await Future.delayed(const Duration(seconds: 1));

      if (Platform.isWindows) {
        // 🚀 优化：如果下载的是独立 exe 且包含 Setup 字样，尝试静默，否则普通启动
        if (savePath.toLowerCase().contains("setup") || savePath.toLowerCase().contains("install")) {
           await Process.start(savePath, ['/VERYSILENT', '/CLOSEAPPLICATIONS']);
           exit(0);
        } else {
           // 独立版程序直接打开，不退出当前 App，由用户自行替换
           await Process.run('cmd', ['/c', 'start', '', savePath]);
           Get.back();
           _showToast("安装程序已启动，请手动完成替换", isError: false);
        }
      } else if (Platform.isMacOS) {
        await Process.run('open', [savePath]);
        exit(0);
      }
    } catch (e) {
      Get.back();
      _showToast("电脑端下载失败: $e", isError: true);
    }
  }
}
