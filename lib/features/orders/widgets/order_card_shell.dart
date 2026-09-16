import 'package:flutter/material.dart';

import '../../../core/widgets/app_surface_card.dart';

/// Wrapper card trắng bo góc dùng chung cho các block trong active_order_screen
/// (RouteCard, TopupCard, BatchStopsCard, EarningCard).
Widget orderCardShell({required Widget child}) => AppSurfaceCard(child: child);
