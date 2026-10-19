import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../core/palette.dart';
import '../../core/theme.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/listing_repository.dart'
    show ListingEditRejectedException;
import '../../providers/listing_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/utils.dart';
import '../../widgets/lot_photo.dart';

class CreateListingScreen extends StatefulWidget {
  final Listing? listing;

  const CreateListingScreen({super.key, this.listing});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  static const int _maxPhotos = 6;
  static const double _maxPhotoWidth = 1600;
  static const int _maxTitleLength = 80;
  static const int _maxDescriptionLength = 1000;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedCategory =
      AppCategories.selectableCategories[0]['id'] as String;
  String _selectedCondition = AppConditions.conditions[0];
  String _selectedParish = AppParishes.parishes[0];
  int _selectedDurationDays = 7;
  final List<String> _imagePaths = [];
  bool _isLoading = false;

  bool get _isEditing => widget.listing != null;

  /// Once somebody has bid, the lot is what it was advertised as. The seller
  /// may still add photographs; the terms are closed.
  bool get _termsAreFixed => (widget.listing?.bidCount ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final l = widget.listing!;
      _titleController.text = l.title;
      _descController.text = l.description;
      _priceController.text = _priceAsTyped(l.startingBid);
      _selectedCategory = l.category;
      _selectedCondition = l.condition;
      _selectedParish = l.parish;
      _imagePaths.addAll(l.imagePaths);
    } else {
      final userParish = context.read<UserProvider>().currentUser?.parish;
      if (userParish != null && AppParishes.parishes.contains(userParish)) {
        _selectedParish = userParish;
      }
    }
  }

  /// Shows whole amounts without a trailing '.0' but never drops real cents.
  static String _priceAsTyped(double amount) {
    return amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_imagePaths.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A lot can carry $_maxPhotos photos.')),
      );
      return;
    }
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: _maxPhotoWidth,
    );
    if (images.isEmpty) return;
    final remaining = _maxPhotos - _imagePaths.length;
    final photos = await _readAll(images.take(remaining));
    if (!mounted) return;
    setState(() => _imagePaths.addAll(photos));
  }

  /// Carries each picked photograph inline as a data URI.
  ///
  /// A picked file's path is a device path on mobile and a blob handle on the
  /// web, and neither can be read back once the app restarts. The bytes can,
  /// so the bytes are what the lot keeps.
  Future<List<String>> _readAll(Iterable<XFile> images) async {
    final photos = <String>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      photos.add('data:${_mimeTypeOf(image)};base64,${base64Encode(bytes)}');
    }
    return photos;
  }

  String _mimeTypeOf(XFile image) {
    final declared = image.mimeType;
    if (declared != null && declared.startsWith('image/')) return declared;
    return image.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
  }

  Future<void> _saveListing() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<UserProvider>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to list a lot.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    final price = AppUtils.readAmount(_priceController.text) ?? 0;

    try {
      if (_isEditing) {
        final updated = widget.listing!.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          startingBid: price,
          category: _selectedCategory,
          condition: _selectedCondition,
          parish: _selectedParish,
          imagePaths: _imagePaths,
        );
        await context
            .read<ListingProvider>()
            .updateListingDetails(updated, imagePaths: _imagePaths);
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Lot updated'),
              backgroundColor: AppColors.ink,
            ),
          );
        }
      } else {
        await context.read<ListingProvider>().createListing(
              userId: user.id,
              title: _titleController.text.trim(),
              description: _descController.text.trim(),
              startingBid: price,
              category: _selectedCategory,
              condition: _selectedCondition,
              parish: _selectedParish,
              imagePaths: _imagePaths,
              durationDays: _selectedDurationDays,
            );
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Lot is on the floor'),
              backgroundColor: AppColors.ink,
            ),
          );
        }
      }
    } on ListingEditRejectedException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.reason), backgroundColor: AppColors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Failed to ${_isEditing ? "update" : "create"} auction. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.appName.toUpperCase(),
              style: AppTheme.money(19, palette.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              _isEditing ? 'EDIT THIS LOT' : 'CONSIGN A LOT',
              style: AppTheme.sectionLabel(palette.gold),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_termsAreFixed) ...[
                const _FixedTermsNotice(),
                const SizedBox(height: 14),
              ],
              _FormPanel(
                title: 'Add photos',
                detail: 'Up to $_maxPhotos photos. The more, the better.',
                child: _PhotoGrid(
                  imagePaths: _imagePaths,
                  maxPhotos: _maxPhotos,
                  onAdd: _pickImages,
                  onRemove: (index) =>
                      setState(() => _imagePaths.removeAt(index)),
                ),
              ),
              const SizedBox(height: 14),
              _FormPanel(
                title: 'What are you selling?',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      enabled: !_termsAreFixed,
                      maxLength: _maxTitleLength,
                      decoration: const InputDecoration(
                        hintText: 'e.g. 2019 Honda CR-V EX',
                        counterText: '',
                      ),
                      validator: _validateTitle,
                    ),
                    const SizedBox(height: 14),
                    _FieldPair(
                      first: _LabelledDropdown<String>(
                        label: 'Category',
                        icon: Icons.category_outlined,
                        value: _selectedCategory,
                        items: AppCategories.selectableCategories
                            .map((c) => DropdownMenuItem(
                                  value: c['id'] as String,
                                  child: Text(c['name'] as String),
                                ))
                            .toList(),
                        onChanged: _termsAreFixed
                            ? null
                            : (v) => setState(() => _selectedCategory = v!),
                      ),
                      second: _LabelledDropdown<String>(
                        label: 'Condition',
                        icon: Icons.verified_outlined,
                        value: _selectedCondition,
                        items: AppConditions.conditions
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: _termsAreFixed
                            ? null
                            : (v) => setState(() => _selectedCondition = v!),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldPair(
                      first: _LabelledDropdown<String>(
                        label: 'Parish',
                        icon: Icons.place_outlined,
                        value: _selectedParish,
                        items: AppParishes.parishes
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedParish = v!),
                      ),
                      second: _isEditing
                          ? null
                          : _LabelledDropdown<int>(
                              label: 'Auction duration',
                              icon: Icons.event_outlined,
                              value: _selectedDurationDays,
                              items: AppDurations.auctionDurations
                                  .map((d) => DropdownMenuItem(
                                        value: d['days'] as int,
                                        child: Text(d['label'] as String),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedDurationDays = v!),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _FormPanel(
                title: 'Opening price',
                detail: 'Bidding starts here. There is no reserve.',
                child: TextFormField(
                  controller: _priceController,
                  enabled: !_termsAreFixed,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    // prefixText only appears once the field has focus, which
                    // leaves the currency off the screen exactly when a seller
                    // is deciding what to type. A prefix widget is always up.
                    prefixIcon: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                      child: Text(
                        'J\$',
                        style: AppTheme.money(17, context.palette.onSurface),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0),
                    hintText: 'Enter amount',
                  ),
                  validator: _validateStartingBid,
                ),
              ),
              const SizedBox(height: 14),
              _FormPanel(
                title: 'Item description',
                child: TextFormField(
                  controller: _descController,
                  enabled: !_termsAreFixed,
                  maxLines: 5,
                  maxLength: _maxDescriptionLength,
                  decoration: const InputDecoration(
                    hintText:
                        "Describe the lot's features, condition and history.",
                    alignLabelWithHint: true,
                  ),
                  validator: _validateDescription,
                ),
              ),
              const SizedBox(height: 14),
              const _ConsignmentTips(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveListing,
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.onAmber,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_isEditing ? 'UPDATE LOT' : 'SEND TO THE FLOOR'),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Title is required';
    if (value.trim().length < 3) {
      return 'Title must be at least 3 characters';
    }
    return null;
  }

  String? _validateStartingBid(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Starting bid is required';
    }
    final price = AppUtils.readAmount(value);
    if (price == null || price <= 0) return 'Enter a valid starting bid';
    return null;
  }

  String? _validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }
    if (value.trim().length < 10) {
      return 'Description must be at least 10 characters';
    }
    return null;
  }
}

/// A bordered block of the consignment form, titled the way the paper form is.
class _FormPanel extends StatelessWidget {
  final String title;
  final String? detail;
  final Widget child;

  const _FormPanel({required this.title, this.detail, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: context.palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (detail != null) ...[
            const SizedBox(height: 3),
            Text(detail!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Two fields side by side, as the paper form sets them.
class _FieldPair extends StatelessWidget {
  final Widget first;
  final Widget? second;

  const _FieldPair({required this.first, this.second});

  @override
  Widget build(BuildContext context) {
    if (second == null) return first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second!),
      ],
    );
  }
}

class _LabelledDropdown<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const _LabelledDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded, color: palette.muted),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: palette.muted),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// The photographs, in the grid the mockup lays them out in.
class _PhotoGrid extends StatelessWidget {
  final List<String> imagePaths;
  final int maxPhotos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _PhotoGrid({
    required this.imagePaths,
    required this.maxPhotos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final slots = imagePaths.length < maxPhotos
        ? imagePaths.length + 1
        : imagePaths.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: slots < 4 ? 4 : slots,
      itemBuilder: (context, index) {
        if (index < imagePaths.length) {
          return _PhotoTile(
            path: imagePaths[index],
            onRemove: () => onRemove(index),
          );
        }
        if (index == imagePaths.length && imagePaths.length < maxPhotos) {
          return _AddPhotoTile(
            count: imagePaths.length,
            maxPhotos: maxPhotos,
            onTap: onAdd,
          );
        }
        return const _EmptyPhotoSlot();
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;

  const _PhotoTile({required this.path, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.markRadius),
          child: LotPhoto(
            path: path,
            width: double.infinity,
            height: double.infinity,
            onUnreadable: (_) => Container(
              color: palette.raisedSurface,
              child: Icon(Icons.broken_image, color: palette.muted),
            ),
          ),
        ),
        Positioned(
          top: 3,
          right: 3,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.panel.withValues(alpha: 0.75),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: AppColors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final int count;
  final int maxPhotos;
  final VoidCallback onTap;

  const _AddPhotoTile({
    required this.count,
    required this.maxPhotos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: DottedBorderBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 22, color: palette.gold),
            const SizedBox(height: 5),
            Text(
              '$count/$maxPhotos',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.raisedSurface,
        borderRadius: BorderRadius.circular(AppTheme.markRadius),
      ),
      child: Icon(Icons.image_outlined, size: 20, color: palette.muted),
    );
  }
}

/// The dashed slot a photograph is dropped into.
class DottedBorderBox extends StatelessWidget {
  final Widget child;

  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppTheme.markRadius),
        border: Border.all(color: palette.gold, width: 1.2),
      ),
      child: child,
    );
  }
}

class _ConsignmentTips extends StatelessWidget {
  const _ConsignmentTips();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.star_outline_rounded, size: 20, color: palette.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What sells a lot',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  'Be honest, say what is wrong with it, and photograph it in '
                  'daylight. Bidders pay more for a lot they can see clearly.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Why half this form is greyed out.
class _FixedTermsNotice extends StatelessWidget {
  const _FixedTermsNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.gold, width: 1.5),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: const Text(
        'Bidding has started on this lot. Bidders committed to the item as '
        'described at the price advertised, so the title, description, '
        'category, condition and opening price are now fixed. You can still '
        'add photographs.',
        style: TextStyle(height: 1.45),
      ),
    );
  }
}
