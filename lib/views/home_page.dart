import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/api_request_history.dart';
import '../providers/history_notifier.dart';
import '../providers/response_notifier.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _curlController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Future<void> _importCurlFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'sh'],
      );
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final curlText = await file.readAsString();
        
        if (curlText.trim().isNotEmpty) {
          ref.read(requestFormProvider.notifier).updateFromCurl(curlText);
          _curlController.text = curlText;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('cURL 파일을 성공적으로 가져왔습니다.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 가져오기 실패: $e')),
        );
      }
    }
  }

  Future<void> _exportCurlToFile() async {
    try {
      final requestForm = ref.read(requestFormProvider);
      final curlString = requestForm.curl;
      
      if (curlString.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내보낼 cURL 명령어가 비어있습니다.')),
        );
        return;
      }
      
      final outputFilePath = await FilePicker.platform.saveFile(
        dialogTitle: 'cURL 파일 저장',
        fileName: 'request.sh',
        type: FileType.custom,
        allowedExtensions: ['sh', 'txt'],
      );
      
      if (outputFilePath != null) {
        final file = File(outputFilePath);
        await file.writeAsString(curlString);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('파일이 저장되었습니다: $outputFilePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 저장 실패: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // 초기 폼 상태 동기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final requestForm = ref.read(requestFormProvider);
      _urlController.text = requestForm.url;
      _bodyController.text = requestForm.body;
      _curlController.text = requestForm.curl;
      _descriptionController.text = requestForm.description;
    });

    // 탭 이동 시 cURL View 탭에 갈 경우 최신 cURL 동기화
    _tabController.addListener(() {
      if (_tabController.index == 3) {
        final requestForm = ref.read(requestFormProvider);
        _curlController.text = requestForm.curl;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _bodyController.dispose();
    _curlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    int i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}";
  }

  @override
  Widget build(BuildContext context) {
    final requestForm = ref.watch(requestFormProvider);
    final responseState = ref.watch(responseProvider);
    final historyList = ref.watch(historyProvider);

    // 외부 상태가 변경되었을 때 컨트롤러 텍스트 동기화 (단, 사용자가 포커스하여 입력 중일 때는 제외)
    ref.listen<RequestFormState>(requestFormProvider, (prev, next) {
      if (_urlController.text != next.url && !_urlController.value.composing.isValid) {
        _urlController.text = next.url;
      }
      if (_bodyController.text != next.body) {
        _bodyController.text = next.body;
      }
      if (_tabController.index != 3 && _curlController.text != next.curl) {
        _curlController.text = next.curl;
      }
      if (_descriptionController.text != next.description) {
        _descriptionController.text = next.description;
      }
    });

    final favorites = historyList.where((h) => h.isFavorite).toList();
    final histories = historyList.where((h) => !h.isFavorite).toList();

    return Scaffold(
      body: Row(
        children: [
          // ================= Left Sidebar (260px) =================
          Container(
            width: 260,
            color: const Color(0xFF181818),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Branding Header
                Padding(
                  padding: const EdgeInsets.only(left: 20.0, top: 50.0, bottom: 20.0, right: 20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBB86FC).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBB86FC).withOpacity(0.3)),
                        ),
                        child: const Icon(
                          Icons.blur_on_rounded,
                          color: Color(0xFFBB86FC),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'LEVIATHAN',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Color(0xFFBB86FC),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 1. Favorites Section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'FAVORITES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: favorites.isEmpty
                      ? const Center(
                          child: Text(
                            '고정된 요청이 없습니다.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          itemCount: favorites.length,
                          itemBuilder: (context, index) {
                            final item = favorites[index];
                            return _buildSidebarItem(item, ref);
                          },
                        ),
                ),
                
                const Divider(height: 1, color: Color(0xFF2D2D2D)),
                
                // 2. History Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'HISTORY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: Colors.grey,
                        ),
                      ),
                      if (histories.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            ref.read(historyProvider.notifier).clearNonFavorites();
                          },
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(fontSize: 11, color: Color(0xFFCF6679)),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: histories.isEmpty
                      ? const Center(
                          child: Text(
                            '최근 내역이 없습니다.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          itemCount: histories.length,
                          itemBuilder: (context, index) {
                            final item = histories[index];
                            return _buildSidebarItem(item, ref);
                          },
                        ),
                ),
              ],
            ),
          ),
          
          const VerticalDivider(width: 1, color: Color(0xFF2D2D2D)),

          // ================= Right Main Panel =================
          Expanded(
            child: Container(
              color: const Color(0xFF121212),
              child: Column(
                children: [
                  // 1. Top URL Request Bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Method Selector Dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF2D2D2D)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: requestForm.method,
                                  dropdownColor: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(8),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFBB86FC)),
                                  items: ['GET', 'POST', 'PUT', 'DELETE']
                                      .map((m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(
                                              m,
                                              style: TextStyle(
                                                color: _getMethodColor(m),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      ref.read(requestFormProvider.notifier).updateMethod(val);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // URL input field
                            Expanded(
                              child: TextField(
                                controller: _urlController,
                                onChanged: (val) {
                                  ref.read(requestFormProvider.notifier).updateUrl(val);
                                },
                                decoration: InputDecoration(
                                  hintText: 'https://api.example.com/endpoint',
                                  hintStyle: const TextStyle(color: Colors.grey),
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF2D2D2D)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFBB86FC), width: 1.5),
                                  ),
                                ),
                                style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Send Button
                            ElevatedButton(
                              onPressed: responseState.isLoading
                                  ? null
                                  : () => ref.read(responseProvider.notifier).sendRequest(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBB86FC),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 2,
                              ),
                              child: responseState.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Send', style: TextStyle(fontWeight: FontWeight.bold)),
                                        SizedBox(width: 6),
                                        Icon(Icons.send_rounded, size: 14),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Description input field
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _descriptionController,
                                onChanged: (val) {
                                  ref.read(requestFormProvider.notifier).updateDescription(val);
                                },
                                decoration: InputDecoration(
                                  hintText: '요청에 대한 설명(Description)을 입력하세요...',
                                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  prefixIcon: Icon(Icons.description_outlined, size: 16, color: Colors.grey[500]),
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: Color(0xFF2D2D2D)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: Color(0xFFBB86FC), width: 1.0),
                                  ),
                                ),
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. Middle Request Tabs Panel
                  Container(
                    height: 250,
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2D2D2D)),
                    ),
                    child: Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: const [
                            Tab(text: 'Headers'),
                            Tab(text: 'Query Params'),
                            Tab(text: 'Body (JSON)'),
                            Tab(text: '💻 cURL View'),
                          ],
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                // Headers Tab
                                _KeyValueEditor(
                                  initialMap: requestForm.headers,
                                  hintKey: 'Content-Type',
                                  hintValue: 'application/json',
                                  onChanged: (map) {
                                    ref.read(requestFormProvider.notifier).updateHeaders(map);
                                  },
                                ),
                                
                                // Query Params Tab
                                _KeyValueEditor(
                                  initialMap: requestForm.queryParams,
                                  hintKey: 'page',
                                  hintValue: '1',
                                  onChanged: (map) {
                                    ref.read(requestFormProvider.notifier).updateQueryParams(map);
                                  },
                                ),
                                
                                // Body (JSON) Tab
                                TextField(
                                  controller: _bodyController,
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  onChanged: (val) {
                                    ref.read(requestFormProvider.notifier).updateBody(val);
                                  },
                                  decoration: const InputDecoration(
                                    hintText: '{\n  "key": "value"\n}',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(8),
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'Menlo',
                                    fontSize: 12,
                                    color: Color(0xFF03DAC6),
                                  ),
                                ),
                                
                                // cURL View Tab
                                Stack(
                                  children: [
                                    TextField(
                                      controller: _curlController,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      onChanged: (val) {
                                        ref.read(requestFormProvider.notifier).updateFromCurl(val);
                                      },
                                      decoration: const InputDecoration(
                                        hintText: 'Paste raw cURL command here...',
                                        hintStyle: TextStyle(color: Colors.grey),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.only(top: 8, left: 8, right: 120, bottom: 8),
                                      ),
                                      style: const TextStyle(
                                        fontFamily: 'Menlo',
                                        fontSize: 12,
                                        color: Color(0xFFBB86FC),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.file_upload_outlined, size: 18, color: Colors.grey),
                                            onPressed: _importCurlFromFile,
                                            tooltip: 'cURL 파일 가져오기 (Import)',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.file_download_outlined, size: 18, color: Colors.grey),
                                            onPressed: _exportCurlToFile,
                                            tooltip: 'cURL 파일 내보내기 (Export)',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: _curlController.text));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('cURL 클립보드에 복사됨'),
                                                  duration: Duration(seconds: 1),
                                                ),
                                              );
                                            },
                                            tooltip: 'cURL 복사',
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // 3. Bottom Response Panel
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2D2D2D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Response Meta Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFF151515),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'RESPONSE',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                                ),
                                const Spacer(),
                                if (responseState.statusCode != null) ...[
                                  _buildStatusBadge(responseState.statusCode!, responseState.statusMessage),
                                  const SizedBox(width: 12),
                                  _buildMetaItem(Icons.timer_outlined, '${responseState.elapsedTimeMs} ms'),
                                  const SizedBox(width: 12),
                                  _buildMetaItem(Icons.analytics_outlined, _formatBytes(responseState.responseSize)),
                                ] else if (responseState.isLoading)
                                  const Text('요청 중...', style: TextStyle(color: Colors.grey, fontSize: 12))
                                else
                                  const Text('대기 상태', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          
                          // Response Body Content View
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: responseState.isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : responseState.errorMessage != null
                                      ? SingleChildScrollView(
                                          child: Text(
                                            'Error: ${responseState.errorMessage}\n\n${responseState.body}',
                                            style: const TextStyle(
                                              fontFamily: 'Menlo',
                                              color: Color(0xFFCF6679),
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      : responseState.body.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'Send 버튼을 눌러 API 요청을 전송하세요.',
                                                style: TextStyle(color: Colors.grey, fontSize: 13),
                                              ),
                                            )
                                          : SingleChildScrollView(
                                              child: SelectableText(
                                                responseState.body,
                                                style: const TextStyle(
                                                  fontFamily: 'Menlo',
                                                  fontSize: 12.5,
                                                  height: 1.4,
                                                  color: Color(0xFFE0E0E0),
                                                ),
                                              ),
                                            ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(ApiRequestHistory item, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            ref.read(requestFormProvider.notifier).loadFromHistory(item);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              children: [
                // Method Badge
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: _getMethodColor(item.method).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _getMethodColor(item.method).withOpacity(0.3)),
                  ),
                  child: Text(
                    item.method,
                    style: TextStyle(
                      color: _getMethodColor(item.method),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // URL / Description text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.description != null && item.description!.trim().isNotEmpty) ...[
                        Text(
                          item.description!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.url,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 9,
                            color: Colors.grey[500],
                          ),
                        ),
                      ] else ...[
                        Text(
                          item.url,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 11,
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Star Button (Favorite Toggle)
                IconButton(
                  icon: Icon(
                    item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: item.isFavorite ? const Color(0xFFFFD700) : Colors.grey[600],
                    size: 16,
                  ),
                  onPressed: () {
                    ref.read(historyProvider.notifier).toggleFavorite(item.id);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),

                // Delete Button (only if not favorite)
                if (!item.isFavorite)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.grey[700],
                      size: 16,
                    ),
                    onPressed: () {
                      ref.read(historyProvider.notifier).deleteHistory(item.id);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return const Color(0xFF03DAC6); // Cyan
      case 'POST':
        return const Color(0xFFBB86FC); // Violet/Purple
      case 'PUT':
        return const Color(0xFFFFB74D); // Amber/Orange
      case 'DELETE':
        return const Color(0xFFCF6679); // Coral/Red
      default:
        return Colors.white70;
    }
  }

  Widget _buildStatusBadge(int statusCode, String? message) {
    final bool isSuccess = statusCode >= 200 && statusCode < 300;
    final color = isSuccess ? const Color(0xFF03DAC6) : const Color(0xFFCF6679);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$statusCode ${message ?? ""}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2D2D2D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

// 헬퍼 extension
extension ColorsExtension on Color {
  static const Color whiteEF = Color(0xFFE0E0E0);
}

// Key-Value 동적 추가/삭제 에디터 위젯
class _KeyValueEditor extends StatefulWidget {
  final Map<String, String> initialMap;
  final String hintKey;
  final String hintValue;
  final ValueChanged<Map<String, String>> onChanged;

  const _KeyValueEditor({
    required this.initialMap,
    required this.hintKey,
    required this.hintValue,
    required this.onChanged,
  });

  @override
  State<_KeyValueEditor> createState() => _KeyValueEditorState();
}

class _KeyValueEditorState extends State<_KeyValueEditor> {
  late List<MapEntry<String, String>> _list;
  late List<TextEditingController> _keyControllers;
  late List<TextEditingController> _valueControllers;

  @override
  void initState() {
    super.initState();
    _list = widget.initialMap.entries.toList();
    
    // 최소 1개의 입력 줄이 보이도록 설정
    if (_list.isEmpty) {
      _list.add(const MapEntry('', ''));
    }
    
    _keyControllers = _list.map((e) => TextEditingController(text: e.key)).toList();
    _valueControllers = _list.map((e) => TextEditingController(text: e.value)).toList();
  }

  @override
  void didUpdateWidget(covariant _KeyValueEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부 상태와 로컬 동기화 (사용자 포커스 유지를 위해 맵 차이가 날 때만 갱신)
    final widgetEntries = widget.initialMap.entries.toList();
    bool isSame = widgetEntries.length == _list.length;
    if (isSame) {
      for (int i = 0; i < _list.length; i++) {
        if (_list[i].key != widgetEntries[i].key || _list[i].value != widgetEntries[i].value) {
          isSame = false;
          break;
        }
      }
    }

    if (!isSame) {
      setState(() {
        _list = widgetEntries.isEmpty ? [const MapEntry('', '')] : widgetEntries;
        
        // 기존 컨트롤러 리소스 해제 후 재생성
        for (var c in _keyControllers) {
          c.dispose();
        }
        for (var c in _valueControllers) {
          c.dispose();
        }
        
        _keyControllers = _list.map((e) => TextEditingController(text: e.key)).toList();
        _valueControllers = _list.map((e) => TextEditingController(text: e.value)).toList();
      });
    }
  }

  @override
  void dispose() {
    for (var c in _keyControllers) {
      c.dispose();
    }
    for (var c in _valueControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _triggerChange() {
    final Map<String, String> map = {};
    for (int i = 0; i < _list.length; i++) {
      final key = _keyControllers[i].text.trim();
      final value = _valueControllers[i].text.trim();
      if (key.isNotEmpty) {
        map[key] = value;
      }
    }
    widget.onChanged(map);
  }

  void _addRow() {
    setState(() {
      _list.add(const MapEntry('', ''));
      _keyControllers.add(TextEditingController());
      _valueControllers.add(TextEditingController());
    });
  }

  void _removeRow(int index) {
    setState(() {
      _list.removeAt(index);
      _keyControllers[index].dispose();
      _keyControllers.removeAt(index);
      _valueControllers[index].dispose();
      _valueControllers.removeAt(index);
    });
    _triggerChange();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _list.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    // Key Field
                    Expanded(
                      child: TextField(
                        controller: _keyControllers[index],
                        onChanged: (val) => _triggerChange(),
                        decoration: InputDecoration(
                          hintText: widget.hintKey,
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF151515),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFF2D2D2D)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFFBB86FC)),
                          ),
                        ),
                        style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(':', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    // Value Field
                    Expanded(
                      child: TextField(
                        controller: _valueControllers[index],
                        onChanged: (val) => _triggerChange(),
                        decoration: InputDecoration(
                          hintText: widget.hintValue,
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF151515),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFF2D2D2D)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0xFFBB86FC)),
                          ),
                        ),
                        style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.grey[600], size: 18),
                      onPressed: () => _removeRow(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFFBB86FC)),
            label: const Text('행 추가', style: TextStyle(color: Color(0xFFBB86FC), fontSize: 12)),
          ),
        )
      ],
    );
  }
}
