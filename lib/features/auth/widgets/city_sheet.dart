import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

class City {
  final int id;
  final String name;
  const City({required this.id, required this.name});
}

class CitySheet extends StatefulWidget {
  final List<City> cities;
  final City? selected;
  const CitySheet({super.key, required this.cities, required this.selected});

  static Future<City?> show(
    BuildContext context, {
    required List<City> cities,
    required City? selected,
  }) {
    return showAppBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CitySheet(cities: cities, selected: selected),
    );
  }

  @override
  State<CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<CitySheet> {
  final _searchCtrl = TextEditingController();
  List<City> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.cities;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.cities
          : widget.cities
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.62,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: AppBottomSheetHeader(
              title: 'Chọn khu vực',
              subtitle: 'Khu vực bạn sẽ nhận đơn',
              icon: Icons.location_on_outlined,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppSheetSearchField(
                controller: _searchCtrl, hint: 'Tìm khu vực...'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('Không tìm thấy khu vực',
                        style: TextStyle(
                            fontSize: AppFontSize.base,
                            color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(12, 4, 12, bottom + 16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final city = _filtered[i];
                      return AppSheetOption(
                        icon: Icons.location_city_rounded,
                        iconBackground: AppColors.surfaceAlt,
                        iconColor: AppColors.textSecondary,
                        label: city.name,
                        selected: city.id == widget.selected?.id,
                        onTap: () => Navigator.pop(context, city),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
