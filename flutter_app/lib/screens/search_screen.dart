import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;
  int _tokenBudget = 2048;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_controller.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.search(
        query: _controller.text,
        tokenBudget: _tokenBudget,
      );

      setState(() {
        _results = result['results'] ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search knowledge base...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Token Budget:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _tokenBudget.toDouble(),
                    min: 512,
                    max: 8192,
                    divisions: 15,
                    label: '$_tokenBudget',
                    onChanged: (value) {
                      setState(() => _tokenBudget = value.toInt());
                    },
                  ),
                ),
                Text('$_tokenBudget'),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _search,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: Text('Search')),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(
                            result['content']?.substring(0, 100) ?? 'No content',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Source: ${result['source'] ?? 'Unknown'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
