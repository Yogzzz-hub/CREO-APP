import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/creo_card.dart';
import '../../widgets/creo_pill_button.dart';
import '../../widgets/creo_segmented_tabs.dart';
import '../../widgets/creo_animations.dart';

class AssetLibraryScreen extends StatefulWidget {
  const AssetLibraryScreen({super.key});

  @override
  State<AssetLibraryScreen> createState() => _AssetLibraryScreenState();
}

class _AssetLibraryScreenState extends State<AssetLibraryScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<_LibraryAsset> _allAssets = [
    _LibraryAsset(
      id: 'lib-1',
      title: 'Founder Story: Why traditional agencies fail',
      type: 'REEL',
      typeLabel: 'Reel · 9:16',
      status: 'Approved',
      isVideo: true,
      aspectRatio: 9 / 16,
      fileUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=600&q=80',
    ),
    _LibraryAsset(
      id: 'lib-2',
      title: 'Ceramic Glaze Reveal (Macro 4K)',
      type: 'REEL',
      typeLabel: 'Reel · 9:16',
      status: 'Published',
      isVideo: true,
      aspectRatio: 9 / 16,
      fileUrl: 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?auto=format&fit=crop&w=600&q=80',
    ),
    _LibraryAsset(
      id: 'lib-3',
      title: 'March 2026 Editorial Drop',
      type: 'CAROUSEL',
      typeLabel: 'Carousel · 4:5',
      status: 'Scheduled',
      isVideo: false,
      aspectRatio: 4 / 5,
      fileUrl: 'https://images.unsplash.com/photo-1509631179647-0177331693ae?auto=format&fit=crop&w=600&q=80',
    ),
    _LibraryAsset(
      id: 'lib-4',
      title: 'Studio Lighting Setup Behind The Scenes',
      type: 'POST',
      typeLabel: 'Static Post · 1:1',
      status: 'Approved',
      isVideo: false,
      aspectRatio: 1 / 1,
      fileUrl: 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=600&q=80',
    ),
    _LibraryAsset(
      id: 'lib-5',
      title: 'Flash Sale 24h Countdown Reminder',
      type: 'STORY',
      typeLabel: 'Story · 9:16',
      status: 'Published',
      isVideo: false,
      aspectRatio: 9 / 16,
      fileUrl: 'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?auto=format&fit=crop&w=600&q=80',
    ),
    _LibraryAsset(
      id: 'lib-6',
      title: 'Texture & Clay Tactile Close-up',
      type: 'REEL',
      typeLabel: 'Reel · 9:16',
      status: 'Approved',
      isVideo: true,
      aspectRatio: 9 / 16,
      fileUrl: 'https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261?auto=format&fit=crop&w=600&q=80',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _allAssets.where((a) {
      final matchesFilter = _selectedFilter == 'All' || a.type.toUpperCase() == _selectedFilter.toUpperCase();
      final matchesSearch = a.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();

    final counts = {
      'All': _allAssets.length,
      'Reels': _allAssets.where((a) => a.type == 'REEL').length,
      'Carousels': _allAssets.where((a) => a.type == 'CAROUSEL').length,
      'Posts': _allAssets.where((a) => a.type == 'POST').length,
      'Stories': _allAssets.where((a) => a.type == 'STORY').length,
    };

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Action Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Asset Library',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              CreoPillButton(
                label: 'Download All (.zip)',
                icon: Icons.archive_outlined,
                dense: true,
                isPrimary: false,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preparing full-resolution .zip archive with captions & tags...'),
                      backgroundColor: AppColors.amber,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // First-round approval rate banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.amber.withAlpha(30), AppColors.surface]
                    : [AppColors.amber.withAlpha(20), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.amber.withAlpha(80)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.amber.withAlpha(35),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '92%',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.amber,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '92% First-Round Approval Rate',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.ivory : AppColors.lightInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Every asset in high-res with final captions, hashtags, and project files.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.mist : AppColors.lightMist,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.ivory : AppColors.lightInk),
            decoration: InputDecoration(
              hintText: 'Search assets by title or topic...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.mist : AppColors.lightMist),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? AppColors.mist : AppColors.lightMist),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.cardBg : AppColors.lightSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppColors.line : AppColors.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.amber),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Segmented Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', 'All ${counts['All']}', isDark),
                const SizedBox(width: 8),
                _filterChip('Reels', 'Reels ${counts['Reels']}', isDark),
                const SizedBox(width: 8),
                _filterChip('Carousels', 'Carousels ${counts['Carousels']}', isDark),
                const SizedBox(width: 8),
                _filterChip('Posts', 'Posts ${counts['Posts']}', isDark),
                const SizedBox(width: 8),
                _filterChip('Stories', 'Stories ${counts['Stories']}', isDark),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2-Column Asset Grid
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Text(
                'No approved assets found in this filter',
                style: TextStyle(fontSize: 13, color: isDark ? AppColors.mist : AppColors.lightMist),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              itemBuilder: (ctx, i) {
                final asset = filtered[i];
                return CreoFadeSlide(
                  delay: Duration(milliseconds: 60 * i),
                  child: _buildAssetGridItem(context, asset, isDark),
                );
              },
            ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label, bool isDark) {
    final isSelected = _selectedFilter.toLowerCase() == key.toLowerCase();
    return CreoPressScale(
      onTap: () => setState(() => _selectedFilter = key),
      pressedScale: 0.93,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.amber.withAlpha(35)
              : (isDark ? AppColors.cardBg : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.amber
                : (isDark ? AppColors.line : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected
                ? AppColors.amber
                : (isDark ? AppColors.ivory : AppColors.lightInk),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetGridItem(BuildContext context, _LibraryAsset asset, bool isDark) {
    Color badgeColor = AppColors.emerald;
    if (asset.status == 'Scheduled') badgeColor = Colors.amber;
    if (asset.status == 'Published') badgeColor = Colors.purple;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBg : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.line : AppColors.lightBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / Video Preview
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    asset.fileUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.black26,
                      child: const Icon(Icons.movie_filter_rounded, color: AppColors.mist),
                    ),
                  ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.55), Colors.transparent, Colors.black.withOpacity(0.7)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Status badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      asset.status.toUpperCase(),
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
                if (asset.isVideo)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(Icons.play_circle_fill_rounded, size: 20, color: Colors.white70),
                  ),
              ],
            ),
          ),

          // Content Box
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.typeLabel.toUpperCase(),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.amber),
                ),
                const SizedBox(height: 3),
                Text(
                  asset.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: isDark ? AppColors.ivory : AppColors.lightInk,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ready for Post',
                      style: TextStyle(fontSize: 10, color: isDark ? AppColors.mist : AppColors.lightMist),
                    ),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Downloading "${asset.title}"...'),
                            backgroundColor: AppColors.amber,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surface : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.download_rounded, size: 14, color: AppColors.amber),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryAsset {
  final String id;
  final String title;
  final String type;
  final String typeLabel;
  final String status;
  final bool isVideo;
  final double aspectRatio;
  final String fileUrl;

  const _LibraryAsset({
    required this.id,
    required this.title,
    required this.type,
    required this.typeLabel,
    required this.status,
    required this.isVideo,
    required this.aspectRatio,
    required this.fileUrl,
  });
}
