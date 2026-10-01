import 'package:flutter/material.dart';

/// User-level sections of the P2WLAN client.
///
/// Information architecture:
///
///   Desktop and mobile primary: Home / Devices / Interconnect / Settings
///
/// Troubleshooting carries the full technical surface (route verification,
/// repair, daemon restart, permissions, logs, raw data) behind its Advanced
/// section. It remains routable from contextual actions and the mobile
/// overflow menu, but is not a permanent left navigation item.
///
/// "Hide complexity, don't remove capability."
enum P2WlanSection {
  home(Icons.home_outlined),
  devices(Icons.devices_outlined),
  interconnect(Icons.lan_outlined),
  meeting(Icons.videocam_rounded),
  tools(Icons.build_rounded),
  troubleshooting(Icons.monitor_heart_outlined),
  settings(Icons.settings_outlined);

  const P2WlanSection(this.icon);

  final IconData icon;

  /// Primary user-level destinations, in display order.
  static const List<P2WlanSection> primary = [
    home,
    devices,
    interconnect,
    meeting,
    tools,
    settings,
  ];

  /// Permanent compact (phone) bottom-bar destinations — five now.
  static const List<P2WlanSection> mobilePrimary = [
    home,
    devices,
    interconnect,
    tools,
    settings,
  ];

  /// Desktop sidebar grouping.
  static const List<List<P2WlanSection>> sidebarGroups = [
    [home, devices, interconnect, meeting, tools],
    [settings],
  ];
}
