import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Column(
            children: _buildChildrenWithDividers(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChildrenWithDividers() {
    final List<Widget> items = [];
    
    for (int i = 0; i < children.length; i++) {
      items.add(children[i]);
      
      // Add divider except for the last item
      if (i < children.length - 1) {
        items.add(
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey[200]!,
            indent: 16,
            endIndent: 16,
          ),
        );
      }
    }
    
    return items;
  }
}