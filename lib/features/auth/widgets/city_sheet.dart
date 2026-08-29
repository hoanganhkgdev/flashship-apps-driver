import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

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
    return showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
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

    return Material(
      color: const Color(0xFFFFFEFD),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.58,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE1D9D5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 17),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Chọn khu vực',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1411))),
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B1411)),
                decoration: InputDecoration(
                  hintText: 'Tìm khu vực...',
                  hintStyle:
                      const TextStyle(color: Color(0xFFA99F9A), fontSize: 15),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF1B1411), size: 21),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _searchCtrl.clear(),
                          child: const Icon(Icons.close_rounded,
                              color: Color(0xFF6A605C), size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFFFF8F5),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: Color(0xFFFF6035), width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE5DDD9)),
            Flexible(
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('Không tìm thấy khu vực',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textSecondary)),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.only(bottom: bottom + 16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                          color: Color(0xFFEDE6E2)),
                      itemBuilder: (_, i) {
                        final city = _filtered[i];
                        final isSelected = city.id == widget.selected?.id;
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          minTileHeight: 45,
                          title: Text(city.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w700,
                                color: isSelected
                                    ? const Color(0xFFFF6035)
                                    : const Color(0xFF1B1411),
                              )),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded,
                                  color: Color(0xFF1B1411), size: 20)
                              : null,
                          onTap: () => Navigator.pop(context, city),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
