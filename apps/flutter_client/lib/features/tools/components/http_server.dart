// HTTP file server panel for sharing files via browser.

import 'package:flutter/material.dart';
import '../../app/app_strings.dart';

class HttpServerPanel extends StatefulWidget {
  const HttpServerPanel({
    super.key,
    required this.strings,
    required this.localIp,
  });

  final AppStrings strings;
  final String localIp;

  @override
  State<HttpServerPanel> createState() => _HttpServerPanelState();
}

class _HttpServerPanelState extends State<HttpServerPanel> {
  bool _isRunning = false;
  int _port = 8080;
  String _sharePath = '';
  int _connectedClients = 0;

  Future<void> _toggleServer() async {
    // In a real implementation, this would start/stop an HTTP server
    // listening on the virtual IP
    setState(() => _isRunning = !_isRunning);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.http_rounded,
                color: _isRunning ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                widget.strings.toolsHttpServerTitle,
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isRunning
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isRunning
                      ? widget.strings.toolsHttpRunning
                      : widget.strings.toolsHttpStopped,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isRunning
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // URL display
          if (_isRunning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      'http://${widget.localIp}:$_port/',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      // Copy to clipboard
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // Controls
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: widget.strings.toolsHttpPort,
                    hintText: '8080',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _port = int.tryParse(value) ?? 8080,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: widget.strings.toolsHttpSharePath,
                    hintText: '/path/to/share',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => _sharePath = value,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _toggleServer,
                child: Text(_isRunning
                    ? widget.strings.toolsHttpStop
                    : widget.strings.toolsHttpStart),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats
          if (_isRunning)
            Row(
              children: [
                Icon(Icons.people_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${widget.strings.toolsHttpConnectedClients} $_connectedClients',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
