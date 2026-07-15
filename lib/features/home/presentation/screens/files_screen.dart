import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf_tools/core/widgets/item_card.dart';
import 'package:pdf_tools/features/home/data/models/recent_file.dart';
import 'package:pdf_tools/features/home/presentation/providers/recent_files_provider.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final List<IconData> _fileViewIcons = [Icons.view_list, Icons.grid_view];
  final _filters = ['All', 'Recent', 'Starred', 'Folders'];
  int _fileViewModeIndex = 0;
  int _fileFilterIndex = 0;
  List<RecentFile> _allFiles = [];
  List<RecentFile> _filteredFiles = [];
  final _searchController = TextEditingController();

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadFiles();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    final service = RecentFilesProvider.of(context);
    final files = await service.getRecentFiles();
    setState(() {
      _allFiles = files;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final search = _searchController.text.toLowerCase();
    var filtered = _allFiles;

    if (search.isNotEmpty) {
      filtered = filtered
          .where((f) => f.fileName.toLowerCase().contains(search))
          .toList();
    }

    switch (_fileFilterIndex) {
      case 1:
        final sevenDaysAgo =
            DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
        filtered = filtered.where((f) => f.timestamp >= sevenDaysAgo).toList();
        break;
      case 2:
      case 3:
        filtered = [];
        break;
    }

    setState(() {
      _filteredFiles = filtered;
    });
  }

  void _switchFileView() {
    setState(() {
      _fileViewModeIndex = (_fileViewModeIndex + 1) % _fileViewIcons.length;
    });
  }

  IconData _iconForOperation(String type) {
    switch (type) {
      case 'compress':
        return Icons.compress;
      case 'merge':
        return Icons.merge;
      case 'split':
        return Icons.call_split;
      case 'rearrange':
        return Icons.reorder;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Files'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(_fileViewIcons[_fileViewModeIndex]),
          onPressed: _switchFileView,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilter(),
                  decoration: InputDecoration(
                    hintText: 'Search PDF files...',
                    prefixIcon: Icon(Icons.find_in_page),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  children: List.generate(_filters.length, (int index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                      child: ChoiceChip(
                        shape: StadiumBorder(),
                        showCheckmark: false,
                        label: Text(_filters[index]),
                        selected: index == _fileFilterIndex,
                        onSelected: (selected) {
                          setState(() => _fileFilterIndex = index);
                          _applyFilter();
                        },
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _filteredFiles.isEmpty
          ? Center(child: Text('No files found'))
          : ListView.builder(
              padding: const EdgeInsets.all(4.0),
              itemCount: _filteredFiles.length,
              itemBuilder: (context, index) {
                final file = _filteredFiles[index];
                return ItemCard(
                  title: file.fileName,
                  icon: Icon(_iconForOperation(file.operationType)),
                  subtitle:
                      '${file.inputFileCount} files • ${_formatTimestamp(file.timestamp)}',
                  onTap: () => OpenFilex.open(file.filePath),
                );
              },
            ),
    );
  }
}