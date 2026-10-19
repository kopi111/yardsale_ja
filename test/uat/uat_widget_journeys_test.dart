// UAT widget suite - drives the real screens through the real providers and
// the real sqflite database. A failing test is a defect report.
//
// Every screen here carries a live countdown, so `pumpAndSettle` never
// settles: it waits for the frame loop to go quiet and a ticking clock never
// does. Each journey pumps a fixed number of frames instead.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:yardsale_ja/core/constants.dart';
import 'package:yardsale_ja/data/database/database_helper.dart';
import 'package:yardsale_ja/data/models/listing.dart';
import 'package:yardsale_ja/data/models/listing_image.dart';
import 'package:yardsale_ja/data/models/user.dart';
import 'package:yardsale_ja/data/repositories/listing_repository.dart';
import 'package:yardsale_ja/data/repositories/user_repository.dart';
import 'package:yardsale_ja/providers/listing_provider.dart';
import 'package:yardsale_ja/providers/user_provider.dart';
import 'package:yardsale_ja/screens/listing/bid_screen.dart';
import 'package:yardsale_ja/screens/listing/create_listing_screen.dart';
import 'package:yardsale_ja/screens/welcome/profile_setup_screen.dart';
import 'package:yardsale_ja/widgets/listing_card.dart';

const _uuid = Uuid();

/// A one-pixel PNG, carried the way an uploaded photograph is carried.
const _uploadedPhoto =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0'
    'lEQVR42mP8Xw8AAoMBgDTD2qgAAAAASUVORK5CYII=';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late ListingRepository listingRepo;
  late UserRepository userRepo;
  late User seller;
  late User bidder;
  late UserProvider userProvider;
  late Listing seeded1000;
  late Listing seeded5000;

  Future<User> makeUser(String name, {bool current = false}) async {
    final u = User(
      id: _uuid.v4(),
      name: name,
      email: '${name.toLowerCase()}@test.jm',
      phone: '8765550000',
      parish: 'Kingston',
      isCurrent: current,
    );
    await userRepo.createUser(u);
    return u;
  }

  /// Wraps [child] in the provider stack the app uses. Synchronous on purpose:
  /// awaiting database I/O inside testWidgets deadlocks against FakeAsync.
  Widget harness(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ChangeNotifierProvider(create: (_) => ListingProvider()),
      ],
      child: MaterialApp(home: child),
    );
  }

  /// Advances the frame loop past whatever work a tap kicked off, without
  /// waiting for a screen that never goes idle.
  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Gives the test a phone-shaped surface. The default 800x600 leaves the
  /// action bar of a full-height screen below the fold, where it cannot be
  /// tapped.
  Future<void> useAPhoneScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<Listing> seedListingWith(double startingBid) async {
    final l = Listing(
      id: _uuid.v4(),
      userId: seller.id,
      title: 'UAT Item',
      description: 'An item under acceptance test',
      startingBid: startingBid,
      category: 'electronics',
      condition: 'Good',
      parish: 'Kingston',
      auctionEndTime: DateTime.now().add(const Duration(days: 2)),
    );
    await listingRepo.insertListing(l);
    return (await listingRepo.getListingById(l.id))!;
  }

  setUp(() async {
    await DatabaseHelper.instance.resetDatabase();
    listingRepo = ListingRepository();
    userRepo = UserRepository();
    seller = await makeUser('Seller');
    bidder = await makeUser('Bidder', current: true);
    userProvider = UserProvider();
    await userProvider.init();
    seeded1000 = await seedListingWith(1000);
    seeded5000 = await seedListingWith(5000);
  });

  // ==========================================================
  // UAT-01  Registration
  // ==========================================================
  group('UAT-01 bidder registration', () {
    Finder field(String hint) => find.widgetWithText(TextFormField, hint);

    Future<void> openRegistration(WidgetTester tester) async {
      await useAPhoneScreen(tester);
      await tester.pumpWidget(harness(const ProfileSetupScreen()));
      await settle(tester);
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(find.text('COLLECT MY PADDLE'));
      await settle(tester);
    }

    testWidgets('UAT-01.1 an empty form is rejected field by field',
        (tester) async {
      await openRegistration(tester);
      await submit(tester);

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Phone is required'), findsOneWidget);
    });

    testWidgets('UAT-01.2 a one-character name and a malformed email are caught',
        (tester) async {
      await openRegistration(tester);
      await tester.enterText(field('The name on your paddle'), 'A');
      await tester.enterText(field('you@example.com'), 'not-an-email');
      await tester.enterText(field('876-555-0000'), '876');
      await submit(tester);

      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Enter a valid Jamaican phone number'), findsOneWidget);
    });

    testWidgets('UAT-01.3 a whitespace-only name is rejected', (tester) async {
      await openRegistration(tester);
      await tester.enterText(field('The name on your paddle'), '     ');
      await submit(tester);
      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('UAT-01.4 a made-up phone number is refused', (tester) async {
      await openRegistration(tester);
      await tester.enterText(field('The name on your paddle'), 'Real Person');
      await tester.enterText(field('you@example.com'), 'real@example.com');
      await tester.enterText(field('876-555-0000'), '0000000');
      await submit(tester);

      expect(find.text('Enter a valid Jamaican phone number'), findsOneWidget,
          reason: 'the phone number is the only way a seller can reach a '
              'buyer, so a number that cannot exist must not pass');
    });

    testWidgets('UAT-01.5 a good registration is accepted', (tester) async {
      await openRegistration(tester);
      await tester.enterText(field('The name on your paddle'), 'Marcia Bennett');
      await tester.enterText(field('you@example.com'), 'marcia@example.com');
      await tester.enterText(field('876-555-0000'), '876-421-8890');
      await submit(tester);

      expect(find.text('Name is required'), findsNothing);
      expect(find.text('Enter a valid email address'), findsNothing);
      expect(find.text('Enter a valid Jamaican phone number'), findsNothing);
    });
  });

  // ==========================================================
  // UAT-03  Consignment form
  // ==========================================================
  group('UAT-03 consignment form', () {
    Finder field(String hint) => find.widgetWithText(TextFormField, hint);
    const titleHint = 'e.g. 2019 Honda CR-V EX';
    const priceHint = 'Enter amount';

    Finder descriptionField() => field(
          "Describe the lot's features, condition and history.",
        );

    Future<void> openForm(WidgetTester tester) async {
      await useAPhoneScreen(tester);
      await tester.pumpWidget(harness(const CreateListingScreen()));
      await settle(tester);
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.tap(find.text('SEND TO THE FLOOR'));
      await settle(tester);
    }

    testWidgets('UAT-03.6 an empty consignment is rejected', (tester) async {
      await openForm(tester);
      await submit(tester);

      expect(find.text('Title is required'), findsOneWidget);
      expect(find.text('Starting bid is required'), findsOneWidget);
      expect(find.text('Description is required'), findsOneWidget);
    });

    testWidgets('UAT-03.7 short title/description and a zero bid are rejected',
        (tester) async {
      await openForm(tester);
      await tester.enterText(field(titleHint), 'ab');
      await tester.enterText(field(priceHint), '0');
      await tester.enterText(descriptionField(), 'short');
      await submit(tester);

      expect(find.text('Title must be at least 3 characters'), findsOneWidget);
      expect(find.text('Enter a valid starting bid'), findsOneWidget);
      expect(find.text('Description must be at least 10 characters'),
          findsOneWidget);
    });

    testWidgets('UAT-03.8 a non-numeric starting bid is rejected',
        (tester) async {
      await openForm(tester);
      await tester.enterText(field(priceHint), 'free');
      await submit(tester);
      expect(find.text('Enter a valid starting bid'), findsOneWidget);
    });

    testWidgets('UAT-03.9 a NEGATIVE starting bid is refused, not flipped',
        (tester) async {
      await openForm(tester);
      await tester.enterText(field(titleHint), 'Toyota Corolla 2018');
      await tester.enterText(field(priceHint), '-5000');
      await tester.enterText(
          descriptionField(), 'Selling my car, good condition throughout.');
      await submit(tester);

      expect(find.text('Enter a valid starting bid'), findsOneWidget,
          reason: 'stripping the minus sign once turned "-5000" into a '
              'J\$5,000 opening price the seller never asked for');

      final posted = (await tester.runAsync(
          () => listingRepo.getListingsByOwner(bidder.id)))!;
      expect(posted, isEmpty, reason: 'nothing reached the floor');
    });

    testWidgets('UAT-03.10 a lot posted with no photos carries no photos',
        (tester) async {
      await openForm(tester);
      expect(find.text('0/6'), findsOneWidget, reason: 'no photos attached');

      await tester.enterText(field(titleHint), 'Toyota Corolla 2018');
      await tester.enterText(field(priceHint), '3200000');
      await tester.enterText(
          descriptionField(), 'Selling my car, good condition throughout.');
      await submit(tester);

      final posted = (await tester.runAsync(
          () => listingRepo.getListingsByOwner(bidder.id)))!;
      expect(posted, hasLength(1));
      expect(posted.first.imagePaths, isEmpty,
          reason: 'the lot must not acquire photographs it was never given');
    });
  });

  // ==========================================================
  // UAT-04  Lot imagery
  // ==========================================================
  group('UAT-04 listing imagery', () {
    Future<void> showCard(WidgetTester tester, Listing listing) async {
      await tester.pumpWidget(harness(
        Scaffold(
            body: SizedBox(width: 200, child: ListingCard(listing: listing))),
      ));
      await tester.pump();
    }

    testWidgets(
        'UAT-04.1 a photo-less lot is NOT dressed in a stock internet photo '
        "of someone else's item", (tester) async {
      final lot = Listing(
        id: _uuid.v4(),
        userId: seller.id,
        title: 'Toyota Corolla 2018',
        description: 'no photos supplied by the seller',
        startingBid: 3200000,
        category: 'vehicles',
        condition: 'Good',
        parish: 'Kingston',
      );
      await showCard(tester, lot);

      final networkImages = tester
          .widgetList<Image>(find.byType(Image))
          .where((image) => image.image is NetworkImage);
      expect(networkImages, isEmpty,
          reason: 'a bidder reads the picture as the thing they are bidding '
              'on; a stock photograph of a different Corolla misrepresents it');
      expect(find.text('Toyota Corolla 2018'), findsWidgets,
          reason: 'the plate names the lot instead');
    });

    testWidgets('UAT-04.2 a photo the seller uploaded IS displayed',
        (tester) async {
      final lot = Listing(
        id: _uuid.v4(),
        userId: seller.id,
        title: 'Item With Real Photos',
        description: 'seller uploaded a photo',
        startingBid: 1000,
        category: 'other',
        condition: 'Good',
        parish: 'Kingston',
        imagePaths: const [_uploadedPhoto],
      );
      await showCard(tester, lot);

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images.where((image) => image.image is MemoryImage), isNotEmpty,
          reason: 'the seller\'s own photograph renders on every build, the '
              'web one included');
    });

    testWidgets('UAT-04.3 an uploaded photo survives being stored and read back',
        (tester) async {
      final lot = Listing(
        id: _uuid.v4(),
        userId: seller.id,
        title: 'Stored Photo Lot',
        description: 'the photo goes to the database and comes back',
        startingBid: 1000,
        category: 'other',
        condition: 'Good',
        parish: 'Kingston',
        auctionEndTime: DateTime.now().add(const Duration(days: 2)),
      );
      final stored = await tester.runAsync(() async {
        await listingRepo.insertListing(lot);
        await listingRepo.insertListingImage(ListingImage(
          id: _uuid.v4(),
          listingId: lot.id,
          imagePath: _uploadedPhoto,
        ));
        return listingRepo.getListingById(lot.id);
      });

      expect(stored!.imagePaths, [_uploadedPhoto]);
      expect(base64Decode(_uploadedPhoto.split(',').last), isNotEmpty);
    });
  });

  // ==========================================================
  // UAT-05  Bid screen input handling
  // ==========================================================
  group('UAT-05 bid screen', () {
    Future<void> openBidScreen(WidgetTester tester, Listing l) async {
      await useAPhoneScreen(tester);
      await tester.pumpWidget(harness(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BidScreen(listing: l)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    /// The bid screen's own submit button — the last one on the screen, below
    /// the raise chips.
    ElevatedButton submitButton(WidgetTester tester) =>
        tester.widgetList<ElevatedButton>(find.byType(ElevatedButton)).last;

    Future<void> type(WidgetTester tester, String amount) async {
      await tester.enterText(find.byType(TextField), amount);
      await settle(tester);
    }

    testWidgets('UAT-05.15 the minimum bid is stated to the bidder',
        (tester) async {
      await openBidScreen(tester, seeded5000);
      expect(find.text('Minimum bid: J\$5,000'), findsOneWidget);
    });

    testWidgets('UAT-05.16 a bid below the minimum is refused in the form',
        (tester) async {
      final l = seeded5000;
      await openBidScreen(tester, l);
      await type(tester, '4000');

      expect(submitButton(tester).onPressed, isNull,
          reason: 'submit is disabled below minimum');
      expect(find.text('ENTER A BID'), findsOneWidget);
      expect(
          (await tester.runAsync(() => listingRepo.getListingById(l.id)))!
              .bidCount,
          0);
    });

    testWidgets('UAT-05.17 letters in the bid box are refused', (tester) async {
      final l = seeded5000;
      await openBidScreen(tester, l);
      await type(tester, 'lots of money');

      expect(submitButton(tester).onPressed, isNull);
      expect(
          (await tester.runAsync(() => listingRepo.getListingById(l.id)))!
              .bidCount,
          0);
    });

    testWidgets('UAT-05.18 "Infinity" cannot be bid', (tester) async {
      final l = seeded5000;
      await openBidScreen(tester, l);
      await type(tester, 'Infinity');
      expect(
          (await tester.runAsync(() => listingRepo.getListingById(l.id)))!
              .bidCount,
          0);
    });

    testWidgets('UAT-05.19 a plain bid above the minimum is understood',
        (tester) async {
      final l = seeded5000;
      await openBidScreen(tester, l);
      await type(tester, '12500');
      await tester.tap(find.byWidget(submitButton(tester)));
      await settle(tester);

      expect(
          (await tester.runAsync(() => listingRepo.getListingById(l.id)))!
              .currentBid,
          12500);
    });

    testWidgets('UAT-05.20 a NEGATIVE bid is refused, never flipped positive',
        (tester) async {
      final l = seeded1000;
      await openBidScreen(tester, l);

      // The bidder types a negative amount - by fat finger, by pasting, or to
      // probe the form.
      await type(tester, '-50000');

      expect(submitButton(tester).onPressed, isNull,
          reason: 'the screen says bids are binding, so a sign the app '
              'discarded must never become one');

      final after =
          await tester.runAsync(() => listingRepo.getListingById(l.id));
      expect(after!.bidCount, 0);
      expect(after.currentBid, isNull);
    });

    testWidgets('UAT-05.21 an outsized bid is read back before it is sent',
        (tester) async {
      final l = seeded1000;
      await openBidScreen(tester, l);
      final outsized = l.startingBid * AppBidding.outsizedBidMultiple;
      await type(tester, outsized.toStringAsFixed(0));
      await tester.tap(find.byWidget(submitButton(tester)));
      await settle(tester);

      expect(find.text('Confirm this bid'), findsOneWidget,
          reason: 'a bid many times the standing price is far more often a '
              'slipped finger than an intention');

      final after =
          await tester.runAsync(() => listingRepo.getListingById(l.id));
      expect(after!.bidCount, 0, reason: 'nothing is committed until confirmed');
    });

    testWidgets('UAT-05.22 a bid beyond the house ceiling is refused',
        (tester) async {
      final l = seeded1000;
      await openBidScreen(tester, l);
      await type(tester, (AppBidding.maximumBid + 1).toStringAsFixed(0));
      await tester.tap(find.byWidget(submitButton(tester)));
      await settle(tester);

      final after =
          await tester.runAsync(() => listingRepo.getListingById(l.id));
      expect(after!.currentBid, isNull);
    });
  });
}
