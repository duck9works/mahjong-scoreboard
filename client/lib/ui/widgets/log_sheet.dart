import 'package:flutter/material.dart';
import '../../model/models.dart';

class LogSheet extends StatelessWidget {
  final List<RoomLogEntry> logs;

  const LogSheet({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, ctl) {
          return Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('履歴ログ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: ctl,
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = logs[logs.length - 1 - i];
                      return ListTile(
                        dense: true,
                        title: Text(e.message),
                        subtitle: Text('${e.at.toLocal()}'),
                        trailing: Text('#${e.seq}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
