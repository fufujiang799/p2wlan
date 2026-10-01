// File transfer dialog for peer-to-peer file sharing.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../app/app_strings.dart';
import '../../core/models/diagnostics_models.dart';

class FileTransferDialog extends StatefulWidget {
  const FileTransferDialog({
    super.key,
    required this.peer,
    required this.strings,
  });

  final PeerSnapshot peer;
  final AppStrings strings;

  @override
  State<FileTransferDialog> createState() => _FileTransferDialogState();
}

class _FileTransferDialogState extends State<FileTransferDialog> {
  PlatformFile? _selectedFile;
  bool _uploading = false;
  double _progress = 0.0;
  String? _status;

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _status = null;
        });
      }
    } catch (e) {
      setState(() {
        _status = widget.strings.toolsFileTransferError;
      });
    }
  }

  Future<void> _sendFile() async {
    if (_selectedFile == null) return;

    setState(() {
      _uploading = true;
      _progress = 0.0;
      _status = null;
    });

    // TODO: Implement actual P2P file transfer over the existing WireGuard tunnel
    // For now, simulate progress
    for (var i = 0; i <= 100; i += 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        setState(() => _progress = i / 100);
      }
    }

    if (mounted) {
      setState(() {
        _uploading = false;
        _status = widget.strings.toolsFileTransferSuccess;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(
          '${widget.strings.toolsFileTransfer} · ${widget.peer.displayName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Peer info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.device_hub, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.peer.displayName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.peer.virtualIp,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // File selector
            ListTile(
              leading: Icon(Icons.insert_drive_file_rounded),
              title: Text(
                _selectedFile == null
                    ? widget.strings.toolsSelectFile
                    : _selectedFile!.name,
              ),
              subtitle: _selectedFile == null
                  ? Text(widget.strings.toolsSelectFileHint)
                  : Text(
                      '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                    ),
              trailing: OutlinedButton(
                onPressed: _uploading ? null : _selectFile,
                child: Text(widget.strings.toolsBrowse),
              ),
            ),
            const SizedBox(height: 8),
            // Progress
            if (_uploading || _progress > 0) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelMedium,
              ),
            ],
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(
                _status!,
                style: TextStyle(
                  color: _status!.contains('失败')
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.strings.cancel),
        ),
        FilledButton(
          onPressed: _uploading ? null : _sendFile,
          child: Text(
            _uploading ? widget.strings.toolsSending : widget.strings.toolsSend,
          ),
        ),
      ],
    );
  }
}
