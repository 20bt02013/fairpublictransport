import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fairpublictransport/screens/seatAssignmentScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../function/reuse.dart';
import 'signin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _usernameTextController = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;
  String userName = '';
  String category = '';
  int ewallet = 0;
  int age = 0;
  int deductedAmount = 0;
  bool paymentMade = false;

  String? selectedCurrentItem;
  String? selectedDestinItem;
  String? path;
  int travelTime = 0;

  List<bool>? get seatSelections => null;

  Stream<QuerySnapshot> getItems() {
    return FirebaseFirestore.instance.collection('locations').snapshots();
  }

  StreamSubscription<QuerySnapshot>? destinationsSubscription;

  Stream<QuerySnapshot> getDestinItems(String? selectedCurrentItem) {
    destinationsSubscription?.cancel(); // Cancel the previous subscription

    if (selectedCurrentItem != null && selectedCurrentItem.isNotEmpty) {
      final stream = FirebaseFirestore.instance
          .collection('locations')
          .doc(selectedCurrentItem)
          .collection('destinations')
          .snapshots();

      destinationsSubscription =
          stream.listen((_) {}); // Store the new subscription
      return stream;
    } else {
      // Return an empty stream or handle the error case
      return const Stream<QuerySnapshot>.empty();
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final CollectionReference usersCollection =
        FirebaseFirestore.instance.collection('users');
    final String userId = FirebaseAuth.instance.currentUser!.uid;

    final DocumentSnapshot userSnapshot =
        await usersCollection.doc(userId).get();

    if (userSnapshot.exists) {
      final Map<String, dynamic> userData =
          userSnapshot.data() as Map<String, dynamic>;
      setState(() {
        userName = userData['name'];
        category = userData['category'];
        ewallet = userData['ewallet'];
        age = userData['age'];
      });
    }
  }

  Future<void> deductFromWallet(int price, String? newPath) async {
    final CollectionReference usersCollection =
        FirebaseFirestore.instance.collection('users');
    final String userId = FirebaseAuth.instance.currentUser!.uid;

    final DocumentSnapshot userSnapshot =
        await usersCollection.doc(userId).get();

    if (userSnapshot.exists) {
      final Map<String, dynamic> userData =
          userSnapshot.data() as Map<String, dynamic>;
      final int currentWallet = userData['ewallet'] as int;

      if (currentWallet >= price) {
        final int updatedWallet = currentWallet - price;

        await usersCollection.doc(userId).update({'ewallet': updatedWallet});

        setState(() {
          ewallet = updatedWallet;
          path = newPath;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text(
                'Successfully deducted from your wallet. Your order has been saved inside the orders menu'),
            actions: [
              TextButton(
                child: const Text('Refund'),
                onPressed: () async {
                  if (paymentMade && deductedAmount > 0) {
                    final int refundAmount = deductedAmount;
                    deductedAmount = 0; // Reset the deducted amount
                    paymentMade = false; // Set paymentMade to false
                    print('Current e-wallet balance:  $paymentMade');
                    final int updatedWallet = ewallet + refundAmount;
                    await usersCollection
                        .doc(userId)
                        .update({'ewallet': updatedWallet});

                    setState(() {
                      ewallet = updatedWallet;
                    });
                  }
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: const Text('CONFIRM'),
                onPressed: () async {
                  // Save order information to Firestore
                  final CollectionReference ordersCollection =
                      usersCollection.doc(userId).collection('orders');

                  final DateTime now = DateTime.now();

                  final Map<String, dynamic> orderData = {
                    'userName': userName,
                    'UserId': user?.uid,
                    'category': category,
                    'age': age,
                    'date': now,
                    'location': selectedCurrentItem,
                    'destination': selectedDestinItem,
                    'price paid': price,
                    'status': 'Paid', // Set initial status
                    'travel time': travelTime,
                    'path': newPath
                  };

                  await ordersCollection.add(orderData);
                  setState(() {
                    deductedAmount = 0; // Reset the deducted amount
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      }
    }
  }

  void showPreviousOrdersDialog(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    const double paddingPercentage = 0.1;
    final double paddingVertical = screenHeight * paddingPercentage;
    final double paddingHorizontal = screenWidth * paddingPercentage;

    final scrollController = ScrollController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Set to true for slow and smooth animation
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: paddingVertical,
                  horizontal: paddingHorizontal,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Previous Orders',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('orders')
                          .get(),
                      builder: (BuildContext context,
                          AsyncSnapshot<QuerySnapshot> snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        final orders = snapshot.data?.docs;

                        if (orders == null || orders.isEmpty) {
                          return const Text('No previous orders found');
                        }

                        // Sort the orders based on the 'orderDate' in descending order
                        orders.sort((a, b) {
                          final aDate =
                              (a.data() as Map<String, dynamic>)['date']
                                  ?.toDate() as DateTime;
                          final bDate =
                              (b.data() as Map<String, dynamic>)['date']
                                  ?.toDate() as DateTime;
                          return bDate.compareTo(aDate);
                        });

                        return Column(
                          children: orders.map((order) {
                            final orderData =
                                order.data() as Map<String, dynamic>;
                            final DateTime orderDate =
                                orderData['date']?.toDate() as DateTime;
                            final String location =
                                orderData['location'] as String;
                            final String category =
                                orderData['category'] as String? ??
                                    'No Category';
                            final int age = orderData['age'] as int? ?? 0;
                            final String destination =
                                orderData['destination'] as String;
                            final int price = orderData['price paid'] as int;
                            final String status = orderData['status'] as String;
                            final int travelTime =
                                orderData['travel time'] as int;
                            final orderDateUtc8 =
                                orderDate.add(const Duration(hours: 8));
                            final hour = orderDateUtc8.hour > 12
                                ? orderDateUtc8.hour - 12
                                : orderDateUtc8.hour;
                            final period =
                                orderDateUtc8.hour < 12 ? 'AM' : 'PM';

                            final String path =
                                orderData['path'] as String? ?? 'Missing';

                            final String trainDocId =
                                orderData['trainDocId'] as String? ??
                                    'No trainDocId';

                            return ListTile(
                              title: Text(
                                'Order: ${order.id}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Row(
                                crossAxisAlignment: CrossAxisAlignment
                                    .center, // Align children at the center of the height
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Date: ${orderDateUtc8.day.toString().padLeft(2, '0')}-${orderDateUtc8.month.toString().padLeft(2, '0')}-${orderDateUtc8.year.toString()} \n ${hour.toString().padLeft(2, '0')}:${orderDateUtc8.minute.toString().padLeft(2, '0')} $period',
                                        ),
                                        Text('Category: $category'),
                                        Text('Age: $age'),
                                        Text('Location: $location'),
                                        Text('Destination: $destination'),
                                        Text('Price Paid: RM $price'),
                                        Text(
                                            'Travel Time: $travelTime minutes'),
                                        const SizedBox(height: 15),
                                      ],
                                    ),
                                  ),
                                  if (status ==
                                      'Paid') // Show as clickable button only if status is 'Paid'
                                    Column(
                                      children: [
                                        GestureDetector(
                                          onTap: () async {
                                            try {
                                              //call onOpenGateButtonPressed() to send order
                                              await onOpenGateButtonPressed(
                                                  order.id,
                                                  location,
                                                  destination,
                                                  orderDate,
                                                  price,
                                                  travelTime,
                                                  category,
                                                  age,
                                                  path);
                                            } catch (e) {
                                              print(
                                                  'Error updating status: $e');
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 18),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              color: Colors
                                                  .blue, // You can change the button color here.
                                            ),
                                            child: const Text(
                                              'Open Gate',
                                              style: TextStyle(
                                                color: Colors
                                                    .white, // You can change the text color here.
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        // Add the second widget here, for example, another button or text
                                        GestureDetector(
                                          onTap: () {
                                            _showTrainSchedules(
                                                context, location, destination);
                                            print('$location $destination');
                                            // Show another showModalBottomSheet for orders that are not 'Paid'
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 18),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              color: Colors
                                                  .red, // You can change the button color here.
                                            ),
                                            child: const Text(
                                              'Schedules',
                                              style: TextStyle(
                                                color: Colors
                                                    .white, // You can change the text color here.
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else if (status ==
                                      'On Ride') // Show as clickable button only if status is 'Paid'
                                    Column(
                                      children: [
                                        GestureDetector(
                                          onTap: () async {
                                            Navigator.pop(context);
                                            // Navigate to SeatAssignmentScreen and pass the order data
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    SeatAssignmentScreen(
                                                        selectedOrderId:
                                                            order.id,
                                                        passselectedLocation:
                                                            location,
                                                        passselectedDestination:
                                                            destination,
                                                        passtrainDocId:
                                                            trainDocId,
                                                        passAge: age,
                                                        passCategory: category,
                                                        passTraveltime:
                                                            travelTime,
                                                        passPath: path),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 18),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              color: Colors
                                                  .blue, // You can change the button color here.
                                            ),
                                            child: const Text(
                                              'Seat Assign Page',
                                              style: TextStyle(
                                                color: Colors
                                                    .white, // You can change the text color here.
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Add the second widget here, for example, another button or text
                                      ],
                                    )
                                  else // If status is not 'Paid', show the status text
                                    Text(status),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => print("Modal closed"));

    // Add a listener to the scroll controller to check if the user has scrolled to the top.
    // If the user is at the top, close the bottom sheet.
    scrollController.addListener(() {
      if (scrollController.position.pixels == 0) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> onOpenGateButtonPressed(
    String orderId,
    String selectedLocation,
    String selectedDestination,
    DateTime orderDate,
    int price,
    int travelTime,
    String category,
    int age,
    String path,
  ) async {
    // Get the current time when the user clicks the "Open Gate" button
    DateTime currentTimeUtc = DateTime.now().toUtc();
    Duration durationToAdd = Duration(hours: 8);
    DateTime currentTimeUtcPlus8 = currentTimeUtc.add(durationToAdd);

    // Retrieve the train data from Firestore that matches the selected location and destination
    QuerySnapshot trainSnapshot = await FirebaseFirestore.instance
        .collection('locations')
        .doc(selectedLocation)
        .collection('destinations')
        .doc(selectedDestination)
        .collection('Trains')
        .orderBy('Depart',
            descending: false) // Order in ascending order of departures
        .get();

    // Initialize variables to track the nearest departure time and train document ID
    String nearestTrainDocId = ''; // Initialize with an empty string

    // Iterate through the train data to find the nearest departure time after the current time
    for (DocumentSnapshot trainDoc in trainSnapshot.docs) {
      Map<String, dynamic> trainData = trainDoc.data() as Map<String, dynamic>;

      String train = trainData['train'] as String;

      // Inside the for loop
      Timestamp departTimestamp = trainData['Depart'] as Timestamp;
      DateTime departDateTime =
          departTimestamp.toDate(); // Convert Timestamp to DateTime

// Adjust for UTC+8 offset
      departDateTime = DateTime(
        departDateTime.year,
        departDateTime.month,
        departDateTime.day,
        departDateTime.hour + 8, // Add 8 hours for UTC+8
        departDateTime.minute,
        departDateTime.second,
      );

// Compare departDateTime with currentTimeUtcPlus8
      if (departDateTime.isBefore(currentTimeUtcPlus8)) {
        // Update the date part to today's date
        print('Before: $departDateTime');
        departDateTime = DateTime(
          currentTimeUtcPlus8.year,
          currentTimeUtcPlus8.month,
          currentTimeUtcPlus8.day,
          departDateTime.hour,
          departDateTime.minute,
          departDateTime.second,
        );
        print('After:$departDateTime');
      }

// Compare departDateTime with currentTimeUtcPlus8 again after updating the date
      if (departDateTime.isAfter(currentTimeUtcPlus8)) {
        nearestTrainDocId = train;
        break; // Exit the loop after finding the nearest departure
      }
    }

    if (nearestTrainDocId.isNotEmpty) {
      // Rest of your code to create order data and update Firestore
      // Create the user's order data
      Map<String, dynamic> orderData = {
        'userName': userName, // Replace with the user's name
        'userId': user?.uid,
        'date': orderDate,
        'category': category,
        'age': age,
        'location': selectedLocation,
        'destination': selectedDestination,
        'price paid': price,
        'status': 'On Ride', // Set initial status
        'travel time': travelTime,
        'path': path,
        'trainDocId': nearestTrainDocId
        // Add other relevant order information here
      };

      // Save the user's order in the "passengers" collection under the specific train document
      await FirebaseFirestore.instance
          .collection('paths')
          .doc(path)
          .collection('Trains')
          .doc(nearestTrainDocId) // Use nearestTrainDocId here
          .collection('passengers')
          .doc(orderId) // Use the order ID as the document ID
          .set(orderData); // Use 'set' instead of 'add'

      // Update the status in Firestore to 'On Ride'
      final orderRef = FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('orders')
          .doc(orderId); // Replace 'order.id' with the actual order document ID

      await orderRef
          .update({'status': 'On Ride', 'trainDocId': nearestTrainDocId});

      print('currentTimeUtcPlus8: $currentTimeUtcPlus8');
      print('nearestTrainDocId: $nearestTrainDocId');

      // ignore: use_build_context_synchronously
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SeatAssignmentScreen(
              selectedOrderId: orderId,
              passselectedLocation: selectedLocation,
              passselectedDestination: selectedDestination,
              passtrainDocId: nearestTrainDocId,
              passAge: age,
              passCategory: category,
              passTraveltime: travelTime,
              passPath: path),
        ),
      );
    } else {
      // Show a message to the user that no suitable train was found
      print("No suitable train found");
      showTrainDepartedBottomSheet(context);
    }
  }

  void showTrainDepartedBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Train has already departed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              // You can add additional content or buttons if needed
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close the bottom sheet
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTrainSchedules(BuildContext context, String selectedLocation,
      String selectedDestination) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
      ),
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchTrainSchedules(selectedLocation,
              selectedDestination), // Call the function to retrieve train data
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              final trainSchedules = snapshot.data;
              if (trainSchedules == null || trainSchedules.isEmpty) {
                return const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons
                          .train, // Replace 'Icons.train' with the desired icon
                      color: Colors
                          .grey, // Replace 'Colors.grey' with the desired icon color
                    ),
                    SizedBox(
                        width:
                            8), // Add some spacing between the icon and the text
                    Text(
                      '\nNo train schedules found\n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                );
              }

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20, // Replace with your desired vertical padding
                    horizontal:
                        16, // Replace with your desired horizontal padding
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add content for the bottom sheet here
                      const Text(
                        'Train Schedules',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var schedule in trainSchedules)
                        ListTile(
                          title: Text('Arrive: ${schedule['Arrive']}'),
                          subtitle: Text('Depart: ${schedule['Depart']}'),
                        ),
                    ],
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchTrainSchedules(
      String selectedLocation, String selectedDestination) async {
    QuerySnapshot trainSnapshot = await FirebaseFirestore.instance
        .collection('locations')
        .doc(selectedLocation)
        .collection('destinations')
        .doc(selectedDestination)
        .collection('Trains')
        .get();

    if (trainSnapshot.docs.isNotEmpty) {
      List<Map<String, dynamic>> trainSchedules = [];
      for (var doc in trainSnapshot.docs) {
        Map<String, dynamic> trainData = doc.data() as Map<String, dynamic>;
        trainSchedules.add(trainData);
      }
      return trainSchedules;
    } else {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Disable resizing when the keyboard pops up
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/home.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 4),
              child: Container(
                color: Colors.black.withOpacity(0),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.09,
            left: MediaQuery.of(context).size.width * 0.09,
            child: IconButton(
              icon: const Icon(Icons.nfc),
              onPressed: () {
                // Do something when the icon is pressed
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.1,
            right: MediaQuery.of(context).size.width * 0.09,
            child: Text(
              '     UIS FYP \n 20BT02013',
              style: GoogleFonts.blinker(
                textStyle: const TextStyle(
                  color: Color(0xff343341),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .5,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: GestureDetector(
                onTap: () {
                  FirebaseAuth.instance.signOut().then((value) {
                    showDialog(
                      context: context,
                      builder: (context) => WillPopScope(
                        onWillPop: () async {
                          // Handle the sign-out process here
                          Navigator.pop(context); // Pop the dialog route
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignInScreen(),
                            ),
                          );
                          return true;
                        },
                        child: AlertDialog(
                          title: const Text('Success'),
                          content: const Text('Log out successfully.'),
                          actions: [
                            TextButton(
                              child: const Text('OK'),
                              onPressed: () {
                                // Handle the sign-out process here
                                Navigator.pop(context); // Pop the dialog route
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignInScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      10, // Replace with the border radius you desire
                    ),
                    color: Colors.grey.withOpacity(
                        0.9), // Replace with the background color you desire
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                    ), // Adjust horizontal padding as needed
                    child: IntrinsicWidth(
                      // Wrap the Row with an IntrinsicWidth widget
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.login_outlined),
                            onPressed: null,
                          ),
                          Text(
                            'LOG OUT',
                            style: TextStyle(
                              color: Color(0xff343341),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: .5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Fair Public\nTransport (MY)',
                      style: GoogleFonts.blinker(
                        textStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 35,
                          fontWeight: FontWeight.bold,
                          letterSpacing: .5,
                          shadows: [
                            Shadow(
                              blurRadius: 4.0,
                              color: Colors.white60,
                              offset: Offset(2.0, 2.0),
                            ),
                            Shadow(
                              blurRadius: 4.0,
                              color: Colors.white10,
                              offset: Offset(-2.0, -2.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: MediaQuery.of(context).size.height * 0.9 * 0.65,
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 10.0, top: 10.0),
                              child: Text(
                                'Ride Safely,   Ride Comfortably, \nEnjoy the journey... ', //ttime:$travelTime path:$path destination:$selectedDestinItem
                                style: GoogleFonts.blinker(
                                  textStyle: const TextStyle(
                                    fontSize: 20,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: .5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            reuseTextField(
                                '$userName: $category\n\n${user?.uid}',
                                Icons.person,
                                false,
                                _usernameTextController),
                            const SizedBox(height: 20),

                            StreamBuilder<QuerySnapshot>(
                              stream: getItems(),
                              builder: (BuildContext context,
                                  AsyncSnapshot<QuerySnapshot> snapshot) {
                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                }

                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }

                                final items = snapshot.data?.docs
                                        .map<String>(
                                            (doc) => doc['name'] as String)
                                        .toList() ??
                                    [];

                                return Container(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Current Location: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      DropdownButton<String>(
                                        value: selectedCurrentItem,
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            selectedCurrentItem = newValue;
                                            selectedDestinItem =
                                                null; // Reset the destination value when the current location changes
                                          });
                                        },
                                        items: [
                                          const DropdownMenuItem<String>(
                                            value: null,
                                            child:
                                                Text('Select current location'),
                                          ),
                                          ...items
                                              .map<DropdownMenuItem<String>>(
                                            (String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(value),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),

                            StreamBuilder<QuerySnapshot>(
                              stream: getDestinItems(selectedCurrentItem),
                              builder: (BuildContext context,
                                  AsyncSnapshot<QuerySnapshot> snapshot) {
                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                }

                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }

                                final items = snapshot.data?.docs
                                        .map<String>(
                                            (doc) => doc['name'] as String)
                                        .toList() ??
                                    [];

                                return Container(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Destination: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      DropdownButton<String>(
                                        value: selectedDestinItem,
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            selectedDestinItem = newValue;
                                          });
                                        },
                                        items: [
                                          if (selectedCurrentItem == null)
                                            const DropdownMenuItem<String>(
                                              value: null,
                                              child: Text(
                                                  'Select current location first'),
                                            )
                                          else
                                            ...items
                                                .map<DropdownMenuItem<String>>(
                                              (String value) {
                                                return DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Text(value),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      if (selectedDestinItem != null)
                                        StreamBuilder<DocumentSnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('locations')
                                              .doc(selectedCurrentItem)
                                              .collection('destinations')
                                              .doc(selectedDestinItem)
                                              .snapshots(),
                                          builder: (BuildContext context,
                                              AsyncSnapshot<DocumentSnapshot>
                                                  snapshot) {
                                            if (snapshot.hasError) {
                                              return Text(
                                                  'Error: ${snapshot.error}');
                                            }

                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const CircularProgressIndicator();
                                            }

                                            final data = snapshot.data?.data()
                                                as Map<String, dynamic>?;

                                            if (data == null) {
                                              return const Text(
                                                  'Destination data not found');
                                            }

                                            final travelTimeInMinutes =
                                                data['Travel Time'] as int?;
                                            travelTime = travelTimeInMinutes ??
                                                0; // Use the null-aware operator

                                            final travelTimeHours =
                                                travelTime ~/ 60;
                                            final travelTimeMinutes =
                                                travelTime % 60;

                                            String formattedTravelTime = '';

                                            if (travelTimeHours > 0) {
                                              formattedTravelTime +=
                                                  '${travelTimeHours}h ';
                                            }

                                            formattedTravelTime +=
                                                '${travelTimeMinutes}min';

                                            final price = data['Price'] as int?;

                                            final path =
                                                data['path'] as String?;

                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Text(
                                                          'Travel Time:',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          formattedTravelTime,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(
                                                      width: 30,
                                                    ), // Add spacing between columns
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Text(
                                                          'Price:',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          'RM ${price ?? 'N/A'}',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Text(
                                                          'Path:',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${path}',
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 20),
                                                Center(
                                                  child: Container(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.4,
                                                    height: 45,
                                                    margin: const EdgeInsets
                                                        .fromLTRB(0, 10, 0, 20),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              30),
                                                      border: Border.all(
                                                        color: Colors.white70,
                                                        width: 2,
                                                        style:
                                                            BorderStyle.solid,
                                                      ),
                                                    ),
                                                    child: ElevatedButton(
                                                      onPressed: () async {
                                                        int currentBalance =
                                                            ewallet;

                                                        if (price != null &&
                                                            currentBalance >=
                                                                price) {
                                                          await deductFromWallet(
                                                              price, path);
                                                          deductedAmount =
                                                              price; // Store the deducted amount
                                                          paymentMade =
                                                              true; // Set paymentMade to true

                                                          // print(
                                                          //     'Current e-wallet balance: $currentBalance');
                                                        } else {
                                                          showDialog(
                                                            context: context,
                                                            builder:
                                                                (context) =>
                                                                    AlertDialog(
                                                              title: const Text(
                                                                  'Insufficient Balance'),
                                                              content: Text(
                                                                  'You do not have enough balance in your e-wallet. Current e-wallet balance: $currentBalance. The price is $price'),
                                                              actions: [
                                                                TextButton(
                                                                  child:
                                                                      const Text(
                                                                          'OK'),
                                                                  onPressed:
                                                                      () {
                                                                    Navigator.pop(
                                                                        context);
                                                                  },
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }
                                                      },
                                                      style: ButtonStyle(
                                                        backgroundColor:
                                                            MaterialStateProperty
                                                                .resolveWith(
                                                          (states) {
                                                            if (states.contains(
                                                                MaterialState
                                                                    .pressed)) {
                                                              return Colors.blue
                                                                  .shade200;
                                                            }
                                                            return Colors
                                                                .blueGrey;
                                                          },
                                                        ),
                                                        shape: MaterialStateProperty
                                                            .all<
                                                                OutlinedBorder>(
                                                          const StadiumBorder(),
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        'Pay Now',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Rest of your code
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: IconButton(
              icon: const Icon(Icons.tram_outlined),
              onPressed: () {
                // Do something when the icon is pressed
              },
            ),
          ),
          Positioned(
            bottom: 30,
            left: 30,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.account_balance_wallet),
                  onPressed: () {
                    // Do something when the icon is pressed
                  },
                ),
                Text(
                  'RM $ewallet', // Add the ewallet value after 'RM'
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.reorder_outlined),
                      onPressed: () {
                        // Do something when the icon is pressed
                        showPreviousOrdersDialog(context);
                      },
                    ),
                    const Text(
                      'ORDERS', // Add the ewallet value after 'RM'
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
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
