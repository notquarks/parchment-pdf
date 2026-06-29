import 'package:flutter/material.dart';

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

  void _switchFileView() {
    setState(() {
      _fileViewModeIndex = (_fileViewModeIndex + 1) % _fileViewIcons.length;
    });
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
                        onSelected: (selected) =>
                            setState(() => _fileFilterIndex = index),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(child: Text('Files Screen')),
    );
  }
}
