import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';

class NFTScreen extends StatefulWidget {
  const NFTScreen({super.key});

  @override
  State<NFTScreen> createState() => _NFTScreenState();
}

class _NFTScreenState extends State<NFTScreen> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _allNFTs = [];
  List<Map<String, dynamic>> _myNFTs = [];
  List<Map<String, dynamic>> _marketplaceNFTs = [];
  bool _loading = true;
  String _activeTab = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _activeTab = ['all', 'my', 'marketplace'][_tabController.index];
      });
      _fetchNFTs();
    });
    _fetchNFTs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchNFTs() async {
    setState(() => _loading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;

      // Fetch all NFTs (assuming there's an 'nfts' table or we use 'paintings' with NFT flag)
      final allResponse = await _supabase
          .from('paintings')
          .select('''
            *,
            profiles:artist_id (
              id,
              username,
              display_name,
              profile_picture_url
            )
          ''')
          .eq('is_nft', true)
          .order('created_at', ascending: false)
          .limit(50);

      final allNFTs = List<Map<String, dynamic>>.from(allResponse);

      // Fetch user's NFTs if logged in
      List<Map<String, dynamic>> myNFTs = [];
      if (user != null) {
        final myResponse = await _supabase
            .from('paintings')
            .select('''
              *,
              profiles:artist_id (
                id,
                username,
                display_name,
                profile_picture_url
              )
            ''')
            .eq('is_nft', true)
            .eq('owner_id', user.id)
            .order('created_at', ascending: false);

        myNFTs = List<Map<String, dynamic>>.from(myResponse);
      }

      // Fetch marketplace NFTs (for sale)
      final marketplaceResponse = await _supabase
          .from('paintings')
          .select('''
            *,
            profiles:artist_id (
              id,
              username,
              display_name,
              profile_picture_url
            )
          ''')
          .eq('is_nft', true)
          .eq('is_for_sale', true)
          .order('created_at', ascending: false)
          .limit(50);

      final marketplaceNFTs = List<Map<String, dynamic>>.from(marketplaceResponse);

      setState(() {
        _allNFTs = allNFTs;
        _myNFTs = myNFTs;
        _marketplaceNFTs = marketplaceNFTs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _allNFTs = [];
        _myNFTs = [];
        _marketplaceNFTs = [];
        _loading = false;
      });
    }
  }

  PreferredSizeWidget _retroAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.black.withOpacity(0.4),
      title: const Text(
        "NFT Gallery",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
      centerTitle: true,
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.purpleAccent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        tabs: const [
          Tab(text: 'All NFTs'),
          Tab(text: 'My NFTs'),
          Tab(text: 'Marketplace'),
        ],
      ),
    );
  }

  BoxDecoration _retroBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFF0f0c29),
          Color(0xFF302b63),
          Color(0xFF24243e),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  Widget _glassContainer({
    required Widget child,
    double radius = 18,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.3),
          width: 1.3,
        ),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _buildNFTCard(Map<String, dynamic> nft) {
    final profile = nft['profiles'] ?? {};
    final isForSale = nft['is_for_sale'] == true;
    final price = nft['price'];

    return _glassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: nft['image_url'] ?? '',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 200,
                    color: Colors.white12,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.purpleAccent,
                        strokeWidth: 1,
                      ),
                    ),
                  ),
                ),
              ),
              // NFT Badge
              Positioned(
                top: 10,
                left: 10,
                child: _glassContainer(
                  radius: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'NFT',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              // For Sale Badge
              if (isForSale)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _glassContainer(
                    radius: 10,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: const Text(
                      'FOR SALE',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nft['title'] ?? "Untitled NFT",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "by ${profile['display_name'] ?? profile['username'] ?? 'Unknown'}",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                if (isForSale && price != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "₹${price}",
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _handleBuyNFT(nft),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'Buy Now',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    "Not for sale",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBuyNFT(Map<String, dynamic> nft) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to purchase NFTs')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase NFT?'),
        content: Text(
          'Are you sure you want to buy "${nft['title'] ?? 'Untitled'}" for ₹${nft['price']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Buy'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update NFT ownership
      await _supabase
          .from('paintings')
          .update({
            'owner_id': user.id,
            'is_for_sale': false,
          })
          .eq('id', nft['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NFT purchased successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh NFTs
      _fetchNFTs();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to purchase NFT: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getCurrentNFTs() {
    switch (_activeTab) {
      case 'my':
        return _myNFTs;
      case 'marketplace':
        return _marketplaceNFTs;
      default:
        return _allNFTs;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _retroAppBar(),
      body: Container(
        decoration: _retroBackground(),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.purpleAccent),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildNFTGrid(_allNFTs),
                  _buildNFTGrid(_myNFTs),
                  _buildNFTGrid(_marketplaceNFTs),
                ],
              ),
      ),
    );
  }

  Widget _buildNFTGrid(List<Map<String, dynamic>> nfts) {
    if (nfts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎨', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text(
              _activeTab == 'my'
                  ? 'You don\'t own any NFTs yet'
                  : _activeTab == 'marketplace'
                      ? 'No NFTs for sale'
                      : 'No NFTs found',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start collecting or creating NFTs!',
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNFTs,
      color: Colors.purpleAccent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: nfts.length,
          itemBuilder: (_, i) => _buildNFTCard(nfts[i]),
        ),
      ),
    );
  }
}

