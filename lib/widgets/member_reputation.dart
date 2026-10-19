import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/palette.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../data/models/review.dart';
import '../providers/transaction_provider.dart';
import 'catalogue_marks.dart';

/// What buyers have said about a member.
///
/// A seller's reputation is the thing a bidder weighs before they raise their
/// paddle, so it reads the same on the member's own record and on the public
/// profile a buyer opens from a lot. The query runs once, not on every
/// rebuild.
class MemberReputation extends StatefulWidget {
  final String userId;

  const MemberReputation({super.key, required this.userId});

  @override
  State<MemberReputation> createState() => MemberReputationState();
}

class MemberReputationState extends State<MemberReputation> {
  late Future<List<Review>> _reviews;

  @override
  void initState() {
    super.initState();
    _reviews = _fetch();
  }

  @override
  void didUpdateWidget(MemberReputation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _reviews = _fetch();
  }

  Future<List<Review>> _fetch() =>
      context.read<TransactionProvider>().getReviewsForUser(widget.userId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: _reviews,
      builder: (_, snapshot) {
        final reviews = snapshot.data ?? const <Review>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewsHeader(reviews: reviews),
            if (reviews.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...reviews.map((review) => _ReviewCard(review: review)),
            ],
          ],
        );
      },
    );
  }
}

/// What buyers say, read the way a saleroom prints its reputation: the average
/// beside the spread that produced it.
class _ReviewsHeader extends StatelessWidget {
  static const int _highestRating = 5;

  final List<Review> reviews;

  const _ReviewsHeader({required this.reviews});

  double get _averageRating {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / reviews.length;
  }

  int _countAt(int rating) =>
      reviews.where((review) => review.rating == rating).length;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RuledPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELLER REPUTATION',
            style: AppTheme.sectionLabel(palette.gold),
          ),
          const SizedBox(height: 4),
          Text(
            'What buyers say',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reviews.isEmpty
                        ? '—'
                        : _averageRating.toStringAsFixed(1),
                    style: AppTheme.money(40, palette.onSurface),
                  ),
                  const SizedBox(height: 6),
                  _Stars(rating: _averageRating.round()),
                  const SizedBox(height: 6),
                  Text(
                    'Based on ${AppUtils.countOf(reviews.length, 'review')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    for (var rating = _highestRating; rating >= 1; rating--)
                      _RatingBar(
                        rating: rating,
                        count: _countAt(rating),
                        total: reviews.length,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row of the ratings spread: how many people gave this many stars.
class _RatingBar extends StatelessWidget {
  final int rating;
  final int count;
  final int total;

  const _RatingBar({
    required this.rating,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final share = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$rating',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: palette.muted,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.star, size: 11, color: palette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 5,
                backgroundColor: palette.hairline,
                valueColor: AlwaysStoppedAnimation<Color>(palette.gold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final comment = review.comment;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.palette.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.reviewerName ?? 'Anonymous',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _Stars(rating: review.rating),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 8),
          Text(
            AppUtils.formatDate(review.createdAt).toUpperCase(),
            style: AppTheme.sectionLabel(context.palette.muted),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  static const int _outOf = 5;

  final int rating;

  const _Stars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        _outOf,
        (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: index < rating
              ? context.palette.gold
              : context.palette.hairline,
          size: 15,
        ),
      ),
    );
  }
}
