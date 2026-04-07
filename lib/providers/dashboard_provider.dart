import 'package:flutter/foundation.dart';
import '../core/config/supabase_client.dart';
import '../models/order.dart';
import '../models/certificate.dart';
import '../models/painting.dart';
import '../models/profile.dart';
import '../repositories/order_repository.dart';
import '../repositories/certificate_repository.dart';
import '../repositories/painting_repository.dart';
import '../repositories/profile_repository.dart';

class DashboardStats {
  // Creator
  final double totalRevenue;
  final int totalSales;
  final int totalArtworks;
  final int totalFollowers;
  final int totalLikes;
  final int certificatesIssued;   // Phase H: certificates issued by creator
  final double verificationRate;  // Phase H: 0.0–1.0 (certified / total artworks)
  /// All completed sales (for charts); UI list uses [recentSales].
  final List<OrderModel> completedSales;
  final List<OrderModel> recentSales;
  final List<PaintingModel> myArtworks;
  // Collector
  final double totalSpent;
  final int ownedArtworks;
  final int certificatesCount;
  final List<OrderModel> myPurchases;
  final List<CertificateModel> myCertificates;
  // Shared
  final ProfileModel? profile;

  const DashboardStats({
    this.totalRevenue = 0,
    this.totalSales = 0,
    this.totalArtworks = 0,
    this.totalFollowers = 0,
    this.totalLikes = 0,
    this.certificatesIssued = 0,
    this.verificationRate = 0.0,
    this.completedSales = const [],
    this.recentSales = const [],
    this.myArtworks = const [],
    this.totalSpent = 0,
    this.ownedArtworks = 0,
    this.certificatesCount = 0,
    this.myPurchases = const [],
    this.myCertificates = const [],
    this.profile,
  });
}

class DashboardProvider with ChangeNotifier {
  DashboardStats? _stats;
  bool _loading = false;
  String? _error;

  DashboardStats? get stats => _stats;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadDashboard() async {
    final userId = SupabaseClientHelper.currentUserId;
    if (userId == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Run all queries in parallel
      final results = await Future.wait([
        ProfileRepository.getMyProfile(),
        OrderRepository.getMySales(),
        OrderRepository.getMyPurchases(),
        PaintingRepository.fetchByArtist(userId),
        CertificateRepository.getMyCollection(),
        _getLikesCount(userId),
      ]);

      final profile = results[0] as ProfileModel?;
      final sales = results[1] as List<OrderModel>;
      final purchases = results[2] as List<OrderModel>;
      final artworks = results[3] as List<PaintingModel>;
      final certificates = results[4] as List<CertificateModel>;
      final likesCount = results[5] as int;

      final completedSales =
          sales.where((s) => s.status == 'completed').toList();
      final completedPurchases =
          purchases.where((p) => p.status == 'completed').toList();

      final totalRevenue = completedSales.fold<double>(
          0, (sum, o) => sum + (o.amount ?? 0));
      final totalSpent = completedPurchases.fold<double>(
          0, (sum, o) => sum + (o.amount ?? 0));

      final certsIssued = certificates.length;
      final vRate = artworks.isEmpty ? 0.0 : (certsIssued / artworks.length).clamp(0.0, 1.0);

      _stats = DashboardStats(
        profile: profile,
        totalRevenue: totalRevenue,
        totalSales: completedSales.length,
        totalArtworks: artworks.length,
        totalFollowers: profile?.followersCount ?? 0,
        totalLikes: likesCount,
        certificatesIssued: certsIssued,
        verificationRate: vRate,
        completedSales: completedSales,
        recentSales: completedSales.take(5).toList(),
        myArtworks: artworks,
        totalSpent: totalSpent,
        ownedArtworks: completedPurchases.length,
        certificatesCount: certificates.length,
        myPurchases: completedPurchases.take(10).toList(),
        myCertificates: certificates,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<int> _getLikesCount(String artistId) async {
    try {
      final data = await SupabaseClientHelper.db
          .from('paintings')
          .select('id')
          .eq('artist_id', artistId);
      if ((data as List).isEmpty) return 0;

      final ids = data.map((e) => e['id'] as String).toList();
      final likes = await SupabaseClientHelper.db
          .from('painting_likes')
          .select('id')
          .inFilter('painting_id', ids);
      return (likes as List).length;
    } catch (_) {
      return 0;
    }
  }
}
