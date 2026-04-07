import 'package:flutter/foundation.dart';
import '../models/painting.dart';
import '../repositories/painting_repository.dart';

class FeedProvider with ChangeNotifier {
  List<PaintingModel> _paintings = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 0;

  List<PaintingModel> get paintings => _paintings;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> loadFeed({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
      _hasMore = true;
      _error = null;
    }
    if (_loading) return;

    _loading = true;
    if (refresh) _paintings = [];
    notifyListeners();

    try {
      final data = await PaintingRepository.fetchFeed(page: _page);
      _paintings = refresh ? data : [..._paintings, ...data];
      _hasMore = data.length == 20;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    _loadingMore = true;
    notifyListeners();

    try {
      _page++;
      final data = await PaintingRepository.fetchFeed(page: _page);
      _paintings = [..._paintings, ...data];
      _hasMore = data.length == 20;
    } catch (e) {
      _page--; // rollback
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String paintingId) async {
    final idx = _paintings.indexWhere((p) => p.id == paintingId);
    if (idx == -1) return;

    final p = _paintings[idx];
    final wasLiked = p.isLikedByMe;

    // Optimistic update
    _paintings[idx] = PaintingModel.fromJson({
      'id': p.id,
      'artist_id': p.artistId,
      'title': p.title,
      'description': p.description,
      'medium': p.medium,
      'dimensions': p.dimensions,
      'image_url': p.imageUrl,
      'additional_images': p.additionalImages,
      'price': p.price,
      'is_for_sale': p.isForSale,
      'is_sold': p.isSold,
      'style_tags': p.styleTags,
      'category': p.category,
      'is_boosted': p.isBoosted,
      'boost_expires_at': p.boostExpiresAt?.toIso8601String(),
      'created_at': p.createdAt?.toIso8601String(),
      'display_name': p.artistDisplayName,
      'profile_picture_url': p.artistProfilePictureUrl,
      'is_verified': p.artistIsVerified,
      'artist_type': p.artistType,
      'likes_count': p.likesCount + (wasLiked ? -1 : 1),
      'is_liked': !wasLiked,
    });
    notifyListeners();

    try {
      await PaintingRepository.toggleLike(paintingId);
    } catch (_) {
      // Revert
      _paintings[idx] = p;
      notifyListeners();
    }
  }

  /// Called by ArtworkDetailScreen to sync like state back to feed list.
  void updateLikeLocally(String paintingId, bool isLiked) {
    final idx = _paintings.indexWhere((p) => p.id == paintingId);
    if (idx == -1) return;
    final p = _paintings[idx];
    _paintings[idx] = PaintingModel.fromJson({
      'id': p.id,
      'artist_id': p.artistId,
      'title': p.title,
      'description': p.description,
      'medium': p.medium,
      'dimensions': p.dimensions,
      'image_url': p.imageUrl,
      'additional_images': p.additionalImages,
      'price': p.price,
      'is_for_sale': p.isForSale,
      'is_sold': p.isSold,
      'style_tags': p.styleTags,
      'category': p.category,
      'is_boosted': p.isBoosted,
      'boost_expires_at': p.boostExpiresAt?.toIso8601String(),
      'created_at': p.createdAt?.toIso8601String(),
      'display_name': p.artistDisplayName,
      'profile_picture_url': p.artistProfilePictureUrl,
      'is_verified': p.artistIsVerified,
      'artist_type': p.artistType,
      'likes_count': isLiked ? p.likesCount + 1 : (p.likesCount - 1).clamp(0, 9999),
      'is_liked': isLiked,
    });
    notifyListeners();
  }
}

