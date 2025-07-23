import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:mysql1/mysql1.dart'; // MySQL connection package
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:bcrypt/bcrypt.dart';  // Import bcrypt package
import 'package:fl_chart/fl_chart.dart'; // For charting



// Define color constants
const Color darkBlue = Color(0xFF4A628A); // Dark Blue
const Color lightBlue = Color(0xFFDFF2EB); // Lightest Blue
const Color mediumBlue = Color(0xFF7AB2D3); // Medium Blue

/// Function to connect to the MySQL database
Future<MySqlConnection> connectToDatabase() async {
  try {
    // Define connection settings using environment variables or fallback to default values
    final settings = ConnectionSettings(
      host: Platform.environment['DB_HOST'] ?? '127.0.0.1',  // Default to localhost
      port: int.parse(Platform.environment['DB_PORT'] ?? '3306'),  // Default MySQL port
      user: Platform.environment['DB_USER'] ?? 'root',  // Default user 'root'
      password: Platform.environment['DB_PASS'] ?? 'dbms123',  // Default password
      db: Platform.environment['DB_NAME'] ?? 'lifetrack',  // Default database 'lifetrack'
    );

    // Establish the database connection
    final conn = await MySqlConnection.connect(settings);
    print('Database connection successful!');
    return conn;
  } catch (e) {
    // Handle and log connection errors
    print('Error connecting to the database: $e');
    rethrow;  // Re-throw error to allow higher-level handling
  }
}
// MySQL connection function
Future<MySqlConnection> _connectToDatabase() async {
  final connection = ConnectionSettings(
    host: '127.0.0.1', // Replace with your MySQL host
    port: 3306, // MySQL default port
    user: 'root', // Replace with your MySQL username
    password: 'dbms123', // Replace with your MySQL password
    db: 'lifetrack', // Replace with your MySQL database name
  );

  final conn = await MySqlConnection.connect(connection);
  return conn;
}

// Function to fetch reminders from the database
Future<void> fetchReminders() async {
  final conn = await connectToDatabase();  // Get the connection

  try {
    var results = await conn.query('SELECT * FROM reminders');
    for (var row in results) {
      print('Reminder: ${row[0]} ${row[1]} ${row[2]}');
    }
  } catch (e) {
    print('Error fetching data: $e');
  } finally {
    await conn.close();  // Close the connection
  }
}

// Function to add a reminder to the database
Future<void> addReminder(String name, String date, String time) async {
  final conn = await connectToDatabase();  // Get the connection

  try {
    // Ensure the reminders table exists, if not, you can create it
    await conn.query('''
      CREATE TABLE IF NOT EXISTS reminders (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        date DATE NOT NULL,
        time TIME NOT NULL
      )
    ''');

    // Insert the reminder into the database
    await conn.query(
      'INSERT INTO reminders (name, date, time) VALUES (?, ?, ?)',
      [name, date, time],
    );
    print('Reminder added');
  } catch (e) {
    print('Error inserting data: $e');
  } finally {
    await conn.close();  // Close the connection
  }
}


// Function to add a user to the database
Future<void> addUser(String email, String password) async {
  final conn = await connectToDatabase();  // Get the connection

  try {
    // Insert the new user into the database
    await conn.query(
      'INSERT INTO users (email, password) VALUES (?, ?)',
      [email, password],  // Use the user input data for registration
    );
    print('User added successfully!');
  } catch (e) {
    print('Error inserting user: $e');
  } finally {
    await conn.close();  // Close the connection after operation
  }
}





void main() async {
  // Ensure Flutter bindings are initialized before async code runs
  WidgetsFlutterBinding.ensureInitialized();

  // Test MySQL connection
  try {
    final conn = await _connectToDatabase();
    print('Connected to MySQL database successfully.');

    // Example query to verify the connection
    var results = await conn.query('SELECT * FROM users');
    for (var row in results) {
      print('User ID: ${row[0]}, Name: ${row[1]}');
    }

    // Close the database connection after the query
    await conn.close();
  } catch (e) {
    print('Error connecting to the MySQL database: $e');
  }

  // Run the Flutter app
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProvider(),
      child: const MyApp(),
    ),
  );
}




class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeTrack',
      debugShowCheckedModeBanner: false, // Hides the debug banner
      theme: ThemeData(
        primaryColor: darkBlue, // Dark Blue
        scaffoldBackgroundColor: lightBlue, // Lightest Blue
        appBarTheme: AppBarTheme(
          backgroundColor: darkBlue, // Dark Blue
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true, // Center the title
          iconTheme: const IconThemeData(color: Colors.white), // Icons in AppBar
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: mediumBlue, // Medium Blue
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Button padding
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0), // Rounded button edges
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: darkBlue, fontSize: 18), // Dark Blue
          bodyMedium: TextStyle(color: darkBlue, fontSize: 16),
        ),
        fontFamily: 'Roboto', // Optional: Set a global font family
      ),
      home: const LoginPage(), // Starting point of the app
    );
  }
}







class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkForSavedLogin(); // Check if there's a saved email on app start
  }

  // Check for saved email and auto-login
  Future<void> _checkForSavedLogin() async {
    final savedEmail = await getUserEmail(); // Get the email from SharedPreferences
    if (savedEmail != null) {
      emailController.text = savedEmail;
      _validateAndLogin(); // Automatically attempt to login if email is saved
    }
  }

  void navigateToHealthInputPage() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.updateProfile(email: emailController.text);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HealthTestInputPage()),
    );
  }

  Future<void> _validateAndLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    // Basic email validation
    if (!emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    // Password length validation
    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    // Check if the credentials exist in the MySQL database
    final conn = await connectToDatabase(); // Ensure you have a connectToDatabase() method
    var result = await conn.query(
      'SELECT * FROM users WHERE email = ? AND password = ?',
      [emailController.text, passwordController.text],
    );

    if (result.isNotEmpty) {
      // Save user email in SharedPreferences
      await saveUserLoginData(emailController.text);

      navigateToHealthInputPage();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid email or password')),
      );
    }

    conn.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                hintText: 'Email',
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Password',
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _validateAndLogin,
              child: const Text('Login'),
            ),
            const SizedBox(height: 16.0),
            TextButton(
              onPressed: navigateToSignupPage,
              child: const Text('Sign up'),
            ),
          ],
        ),
      ),
    );
  }

  void navigateToSignupPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignupPage()),
    );
  }

  // Get the user email from SharedPreferences
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_email'); // Retrieve email if saved
  }

  // Save the user email in SharedPreferences
  Future<void> saveUserLoginData(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email); // Save email to SharedPreferences
  }
}






class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _userEmail;  // Store the user's email

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Two tabs: Daily & General
    _loadUserEmail(); // Load saved user email
  }

  // Load saved email from SharedPreferences
  Future<void> _loadUserEmail() async {
    final savedEmail = await getUserEmail();
    setState(() {
      _userEmail = savedEmail; // Update the email in the state
    });
  }

  // Get the user email from SharedPreferences
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('Email'); // Retrieve email if saved
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text('LifeTrack'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFB9E5E8), // Light Blue
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'General'),
          ],
        ),
      ),
      drawer: AppDrawer(
        userEmail: _userEmail, // Pass the user email to the drawer
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DailyPage(),
          GeneralPage(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}





class DailyPage extends StatefulWidget {
  const DailyPage({super.key});

  @override
  _DailyPageState createState() => _DailyPageState();
}

class _DailyPageState extends State<DailyPage> {
  final List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = false;  // Loading indicator state

  // Connect to MySQL and fetch reminders
  Future<void> _fetchReminders() async {
    setState(() {
      _isLoading = true;  // Show loading indicator
    });

    try {
      final conn = await connectToDatabase(); // Use the existing method
      var results = await conn.query('SELECT * FROM reminders');
      setState(() {
        _reminders.clear();  // Clear any existing data
        for (var row in results) {
          _reminders.add({
            'name': row['name'],
            'date': row['date'],
            'time': row['time'],
          });
        }
      });
    } catch (e) {
      // Handle database connection or query error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching reminders: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;  // Hide loading indicator
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchReminders();  // Fetch reminders when the page loads
  }

  @override
  Widget build(BuildContext context) {
    DateTime today = DateTime.now();

    return Column(
      children: [
        // Fetch reminders button
        ElevatedButton(
          onPressed: _fetchReminders,
          child: const Text('Fetch Reminders'),
        ),
        // Loading indicator
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
        // Displaying reminders if available
        if (_reminders.isEmpty && !_isLoading)
          const Center(child: Text('No reminders available.')),
        // Display reminders
        ..._reminders.map((reminder) {
          final date = DateTime.parse(reminder['date']);
          final time = TimeOfDay.fromDateTime(DateTime.parse(reminder['time']));
          return ListTile(
            title: Text(reminder['name']),
            subtitle: Text('${DateFormat.yMMMd().format(date)} at ${time.format(context)}'),
          );
        }).toList(),
      ],
    );
  }
}



class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  _JournalPageState createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final Map<DateTime, String> _entries = {};
  bool _isLoading = false;  // Loading state

  // Fetch journal entries from MySQL database
  Future<void> _fetchJournalEntries() async {
    setState(() {
      _isLoading = true;  // Show loading spinner
    });

    try {
      final conn = await connectToDatabase();  // Use existing connection function
      var results = await conn.query('SELECT * FROM journal_entries');

      setState(() {
        _entries.clear();  // Clear previous entries
        for (var row in results) {
          DateTime date = DateTime.parse(row['date']);
          _entries[date] = row['entry'];  // Store entries by date
        }
      });
    } catch (e) {
      // Error handling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching journal entries: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;  // Hide loading spinner
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchJournalEntries();  // Fetch journal entries when the page loads
  }

  @override
  Widget build(BuildContext context) {
    DateTime today = DateTime.now();
    String todayEntry = _entries[today] ?? '';  // Get today's entry, if any

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: Column(
        children: [
          // Button to manually fetch journal entries
          ElevatedButton(
            onPressed: _fetchJournalEntries,
            child: const Text('Fetch Journal Entries'),
          ),

          // Loading indicator
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),

          // Display today's journal entry or a message if empty
          todayEntry.isNotEmpty
              ? Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Today\'s Journal Entry: $todayEntry'),
          )
              : const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No journal entry for today.'),
          ),

          // Optionally display other journal entries
          if (_entries.isNotEmpty && !todayEntry.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: _entries.entries
                    .where((entry) => entry.key != today)
                    .map((entry) {
                  return ListTile(
                    title: Text(DateFormat.yMMMd().format(entry.key)),
                    subtitle: Text(entry.value),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class GeneralPage extends StatefulWidget {
  const GeneralPage({super.key});

  @override
  _GeneralPageState createState() => _GeneralPageState();
}

class _GeneralPageState extends State<GeneralPage> {
  final List<Map<String, dynamic>> _generalData = [];
  bool _isLoading = false;  // Loading state

  // Fetch general data (e.g., reminders, entries) from the database
  Future<void> _fetchGeneralData() async {
    setState(() {
      _isLoading = true;  // Show loading spinner
    });

    try {
      final conn = await connectToDatabase();  // Use existing connection function
      var results = await conn.query('SELECT * FROM general_entries');  // Adjust table name accordingly

      setState(() {
        _generalData.clear();
        for (var row in results) {
          _generalData.add({
            'name': row['name'],  // Example field
            'description': row['description'],  // Example field
          });
        }
      });
    } catch (e) {
      // Error handling
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;  // Hide loading spinner
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchGeneralData();  // Fetch data when the page loads
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('General Page')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Loading indicator
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),

          // Display fetched general data
          if (_generalData.isNotEmpty)
            ..._generalData.map((data) {
              return ListTile(
                title: Text(data['name']),
                subtitle: Text(data['description']),
              );
            }).toList(),

          // Display a message if no data is available
          if (_generalData.isEmpty && !_isLoading)
            const Center(child: Text('No general data available.')),
        ],
      ),
    );
  }
}



class HealthTestGraph extends StatelessWidget {
  final Map<String, double> healthTestData;

  HealthTestGraph({required this.healthTestData});

  @override
  Widget build(BuildContext context) {
    // Convert the health test data into a list of FlSpot (points for the graph)
    final spots = healthTestData.entries.map((entry) {
      return FlSpot(
        double.parse(entry.key), // Assuming the key is time or index
        entry.value, // Value of the health test result
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: healthTestData.length.toDouble(),
          minY: 0,
          maxY: healthTestData.values.reduce((a, b) => a > b ? a : b), // Max value for Y axis
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue, // Corrected parameter to `color`
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}



class ReminderPage extends StatefulWidget {
  final Function(String, DateTime, TimeOfDay, String) onAddReminder;

  const ReminderPage({super.key, required this.onAddReminder});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final TextEditingController _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _recurrence = "None";

  Future<MySqlConnection> _connectToDatabase() async {
    final connection = ConnectionSettings(
      host: '127.0.0.1', // Replace with actual host
      port: 3306,
      user: 'root', // Replace with actual username
      password: 'dbms123', // Replace with actual password
      db: 'lifetrack', // Replace with actual database name
    );

    final conn = await MySqlConnection.connect(connection);
    return conn;
  }

  // Method to add reminder to MySQL
  Future<void> _addReminderToDatabase(String name, DateTime date, TimeOfDay time, String recurrence) async {
    try {
      final conn = await _connectToDatabase();
      await conn.query(
        'INSERT INTO reminders (name, date, time, recurrence) VALUES (?, ?, ?, ?)',
        [name, DateFormat('yyyy-MM-dd').format(date), time.format(context), recurrence],
      );
      conn.close();
    } catch (e) {
      print('Error adding reminder: $e');
    }
  }

  // Method to add reminder locally
  void _addReminder(String name, DateTime date, TimeOfDay time, String recurrence) {
    setState(() {
      widget.onAddReminder(name, date, time, recurrence); // This adds it to the local reminder list
    });

    // Add to MySQL database
    _addReminderToDatabase(name, date, time, recurrence);
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Reminder"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Reminder Name"),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: _selectDate,
                  child: const Text('Select Date'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Time: ${_selectedTime.format(context)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: _selectTime,
                  child: const Text('Select Time'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Recurrence Dropdown
            DropdownButton<String>(
              value: _recurrence,
              onChanged: (String? newValue) {
                setState(() {
                  _recurrence = newValue!;
                });
              },
              items: <String>['None', 'Daily', 'Weekly', 'Monthly']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name for the reminder.')),
                  );
                  return;
                }
                _addReminder(
                  _nameController.text,
                  _selectedDate,
                  _selectedTime,
                  _recurrence,
                );
                Navigator.pop(context);
              },
              child: const Text('Add Reminder'),
            ),
          ],
        ),
      ),
    );
  }
}



class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? _selectedGender;  // Gender is optional
  bool _passwordVisible = false;

  Future<MySqlConnection> _connectToDatabase() async {
    final settings = ConnectionSettings(
      host: '127.0.0.1',
      port: 3306,
      user: 'root',
      password: 'dbms123',
      db: 'lifetrack',
    );
    return await MySqlConnection.connect(settings);
  }

  Future<void> _signup() async {
    // Validation for required fields
    if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all the fields')),
      );
      return;
    }

    // Email validation
    if (!emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    // Password validation
    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    try {
      final conn = await _connectToDatabase();
      String hashedPassword = BCrypt.hashpw(passwordController.text, BCrypt.gensalt());

      // Insert data into the database (gender can be null now)
      await conn.query(
        'INSERT INTO users (name, email, gender, password) VALUES (?, ?, ?, ?)',
        [
          nameController.text,
          emailController.text,
          _selectedGender ?? 'Not Specified',  // Default to 'Not Specified' if gender is not selected
          hashedPassword
        ],
      );
      conn.close();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup successful!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during signup: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign up')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(hintText: 'Name'),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: emailController,
              decoration: InputDecoration(hintText: 'Email'),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: passwordController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                hintText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 16.0),
            // Gender dropdown (optional)
            DropdownButton<String>(
              value: _selectedGender,
              hint: Text('Select Gender (Optional)'),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
              items: ['Male', 'Female', 'Other'].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _signup,
              child: Text('Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}

class HealthTestInputPage extends StatefulWidget {
  const HealthTestInputPage({super.key});

  @override
  _HealthTestInputPageState createState() => _HealthTestInputPageState();
}

class _HealthTestInputPageState extends State<HealthTestInputPage> {
  final Map<String, TextEditingController> controllers = {
    'Hemoglobin': TextEditingController(),
    'RBC': TextEditingController(),
    'WBC': TextEditingController(),
    'Platelets': TextEditingController(),
    // other controllers...
  };

  // Simulate saving data to a database
  Future<void> _saveDataToDatabase() async {
    final conn = await _connectToDatabase();

    try {
      var result = await conn.query(
        'INSERT INTO health_test_data (Hemoglobin, RBC, WBC, Platelets) VALUES (?, ?, ?, ?)',
        [
          controllers['Hemoglobin']!.text,
          controllers['RBC']!.text,
          controllers['WBC']!.text,
          controllers['Platelets']!.text,
          // other values...
        ],
      );

      if (result.affectedRows != null && result.affectedRows! > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data saved successfully!')),
        );
        _clearFields(); // Clear the fields after saving data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save data!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      conn.close();
    }
  }

  void _clearFields() {
    controllers.forEach((key, controller) {
      controller.clear();
    });
  }

  void _validateAndSave() {
    // Check if all required fields are valid
    for (var key in controllers.keys) {
      String? fieldValue = controllers[key]?.text;
      if (fieldValue == null || fieldValue.isEmpty || double.tryParse(fieldValue) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid value for $key')),
        );
        return;
      }
    }

    _saveDataToDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Test Input'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          buildSectionTitle('Complete Blood Count'),
          ...controllers.keys.map((label) => buildInputField(label)).toList(),
          const SizedBox(height: 20.0),
          Center(
            child: ElevatedButton(
              onPressed: _validateAndSave,
              child: const Text('Save Data'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildInputField(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controllers[label],
        decoration: InputDecoration(
          labelText: '$label (g/dL)', // Adding units as example
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  // Database connection method
  Future<MySqlConnection> _connectToDatabase() async {
    final settings = ConnectionSettings(
      host: 'your-database-host',
      port: 3306,
      user: 'your-database-username',
      db: 'your-database-name',
      password: 'your-database-password',
    );
    return await MySqlConnection.connect(settings);
  }
}


class SavedDataPage extends StatefulWidget {
  final Map<String, String> data;

  const SavedDataPage({super.key, required this.data});

  @override
  _SavedDataPageState createState() => _SavedDataPageState();
}

class _SavedDataPageState extends State<SavedDataPage> {
  late Map<String, TextEditingController> controllers;

  final Map<String, List<String>> categories = {
    'Complete Blood Count': ['Hemoglobin', 'RBC', 'WBC', 'Platelets'],
    'Blood Sugar': ['Fasting Glucose', 'HbA1c', 'Postprandial Glucose'],
    'Lipid Profile': ['Total Cholesterol', 'LDL Cholesterol', 'HDL Cholesterol', 'Triglycerides'],
    'Kidney Function': ['BUN', 'Creatinine', 'eGFR'],
    'Electrolytes': ['Sodium', 'Potassium', 'Calcium'],
    'Thyroid Function': ['TSH', 'Free T3', 'Free T4'],
  };

  @override
  void initState() {
    super.initState();
    controllers = widget.data.map((key, value) =>
        MapEntry(key, TextEditingController(text: value)));
  }

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Fetch the data from MySQL (for initial population or re-fetching)
  Future<void> _fetchDataFromDatabase() async {
    final conn = await _connectToDatabase();
    var results = await conn.query('SELECT * FROM health_test_data WHERE id = 1');
    if (results.isNotEmpty) {
      var row = results.first;
      setState(() {
        // You can adjust this to match your database fields
        controllers['Hemoglobin']!.text = row['Hemoglobin'];
        controllers['RBC']!.text = row['RBC'];
        controllers['WBC']!.text = row['WBC'];
        controllers['Platelets']!.text = row['Platelets'];
        // Add other fields here...
      });
    }
    conn.close();
  }

  // Updated validation before saving
  Future<void> _validateAndUpdateData() async {
    if (controllers['Hemoglobin']!.text.isEmpty ||
        double.tryParse(controllers['Hemoglobin']!.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Hemoglobin value')),
      );
      return;
    }
    // Add other validations as necessary
    _updateDataToDatabase();
  }

  Future<void> _updateDataToDatabase() async {
    final conn = await _connectToDatabase();

    var result = await conn.query(
      'UPDATE health_test_data SET Hemoglobin = ?, RBC = ?, WBC = ?, Platelets = ?, Fasting_Glucose = ?, HbA1c = ?, Postprandial_Glucose = ?, Total_Cholesterol = ?, LDL_Cholesterol = ?, HDL_Cholesterol = ?, Triglycerides = ?, BUN = ?, Creatinine = ?, eGFR = ?, Sodium = ?, Potassium = ?, Calcium = ?, TSH = ?, Free_T3 = ?, Free_T4 = ? WHERE id = 1',
      [
        controllers['Hemoglobin']!.text,
        controllers['RBC']!.text,
        controllers['WBC']!.text,
        controllers['Platelets']!.text,
        controllers['Fasting Glucose']!.text,
        controllers['HbA1c']!.text,
        controllers['Postprandial Glucose']!.text,
        controllers['Total Cholesterol']!.text,
        controllers['LDL Cholesterol']!.text,
        controllers['HDL Cholesterol']!.text,
        controllers['Triglycerides']!.text,
        controllers['BUN']!.text,
        controllers['Creatinine']!.text,
        controllers['eGFR']!.text,
        controllers['Sodium']!.text,
        controllers['Potassium']!.text,
        controllers['Calcium']!.text,
        controllers['TSH']!.text,
        controllers['Free T3']!.text,
        controllers['Free T4']!.text,
      ],
    );

    if (result.affectedRows != null && result.affectedRows! > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data updated successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update data!')),
      );
    }

    conn.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Data'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Health Test Results',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              ...categories.entries.map((category) => _buildCategorySection(
                context,
                category.key,
                category.value,
              )),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _validateAndUpdateData, // Validate and then update
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, String title, List<String> fields) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: fields.map((field) => _buildEditableRow(field)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow(String field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controllers[field],
        decoration: InputDecoration(
          labelText: field,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }
}


class SummaryPage extends StatelessWidget {
  final Map<String, String> data;

  const SummaryPage({super.key, required this.data});

  Future<MySqlConnection> _connectToDatabase() async {
    try {
      final connection = ConnectionSettings(
        host: '127.0.0.1',
        port: 3306,
        user: 'root',
        password: 'dbms123',
        db: 'lifetrack',
      );
      final conn = await MySqlConnection.connect(connection);
      return conn;
    } catch (e) {
      throw Exception('Failed to connect to the database: $e');
    }
  }

  Future<void> _saveSummaryToDatabase(BuildContext context, Map<String, String> data) async {
    try {
      final conn = await _connectToDatabase();

      // Prepare the insert query
      var query = 'INSERT INTO summary_table (field_name, field_value) VALUES ';
      var values = <String>[];
      data.forEach((key, value) {
        query += '(?, ?),';
        values.add(key);
        values.add(value);
      });

      // Remove the trailing comma
      query = query.substring(0, query.length - 1);

      var result = await conn.query(query, values);

      if (result.insertId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Summary saved to the database!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save summary data!')),
        );
      }

      await conn.close();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _confirmAndSave(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text('Are you sure you want to save the data and go to the home screen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _saveSummaryToDatabase(context, data);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Summary of Health Data:',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            ...data.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _confirmAndSave(context),
              child: const Text('Go to Home and Save Data'),
            ),
          ],
        ),
      ),
    );
  }
}



class UserProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (userProvider.loading) {
          return Center(child: CircularProgressIndicator());
        }

        // Error or empty profile message
        if (userProvider.name.isEmpty || userProvider.email.isEmpty) {
          return Center(child: Text('Failed to load user profile.'));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('User Profile'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${userProvider.name}', style: TextStyle(fontSize: 18)),
                Text('Email: ${userProvider.email}', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 20),
                if (userProvider.profileImage != null)
                  Image.file(userProvider.profileImage!)
                else
                  Icon(Icons.account_circle, size: 100), // Placeholder icon if no image
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => userProvider.fetchUserProfile(),
                  child: const Text('Fetch Profile'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // You can navigate to a page where the user can edit their profile
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                    );
                  },
                  child: const Text('Edit Profile'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class UserProvider extends ChangeNotifier {
  String _name = '';
  String _email = '';
  File? _profileImage;
  bool _loading = false; // Loading state

  String get name => _name;
  String get email => _email;
  File? get profileImage => _profileImage;
  bool get loading => _loading;

  // Update profile data
  void updateProfile({
    String? name,
    String? email,
    File? profileImage,
  }) {
    if (name != null) _name = name;
    if (email != null) _email = email;
    if (profileImage != null) _profileImage = profileImage;
    notifyListeners();
  }

  // Fetch user profile from MySQL
  Future<void> fetchUserProfile() async {
    _loading = true;
    notifyListeners(); // Notify listeners to show loading indicator
    try {
      final conn = await _connectToDatabase();
      final results = await conn.query(
          'SELECT name, email, profile_image FROM users WHERE id = ?', [1] // Replace with dynamic user ID
      );

      if (results.isNotEmpty) {
        final row = results.first;
        _name = row['name'] ?? 'User';
        _email = row['email'] ?? 'Not provided';
        _profileImage = row['profile_image'] != null && await File(row['profile_image']).exists()
            ? File(row['profile_image'])
            : null;
      } else {
        _name = 'No name available';
        _email = 'No email available';
      }

      conn.close();
    } catch (e) {
      print('Error fetching user profile: $e');
      _name = 'Error loading data';
      _email = 'Error loading data';
    } finally {
      _loading = false; // Set loading to false after the operation
      notifyListeners(); // Notify listeners to update UI
    }
  }

  // MySQL connection settings
  Future<MySqlConnection> _connectToDatabase() async {
    final connection = ConnectionSettings(
      host: '127.0.0.1',
      port: 3306,
      user: 'root',
      password: 'dbms123',
      db: 'lifetrack',
    );

    final conn = await MySqlConnection.connect(connection);
    return conn;
  }
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Add logic to save updated profile data
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}


class AppDrawer extends StatelessWidget {
  final String? userEmail; // Declare userEmail

  // Constructor with userEmail parameter
  const AppDrawer({super.key, this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer<UserProvider>( // Using Consumer to access user data
        builder: (context, userProvider, child) {
          return FutureBuilder<void>(
            future: userProvider.fetchUserProfile(), // Fetch user profile from MySQL
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  UserAccountsDrawerHeader(
                    accountName: Text(
                        userProvider.name.isNotEmpty
                            ? "Hi, ${userProvider.name}"
                            : "Hi, User",
                        style: const TextStyle(fontSize: 18)
                    ),
                    accountEmail: Text(userEmail ?? "Set up your profile"), // Use userEmail here
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: userProvider.profileImage != null
                          ? FileImage(userProvider.profileImage!)
                          : null,
                      child: userProvider.profileImage == null
                          ? const Icon(Icons.person, size: 40, color: Color(0xFFD3C1C3))
                          : null,
                    ),
                    decoration: const BoxDecoration(color: Color(0xFFD3C1C3)),
                  ),
                  _createDrawerItem(
                    context,
                    icon: Icons.person,
                    text: 'Profile',
                    page: ProfilePage(), // Use the imported ProfilePage
                  ),
                  _createDrawerItem(
                    context,
                    icon: Icons.list_alt,
                    text: 'Test Results',
                    page: TestResultsPage(),
                  ),
                  _createDrawerItem(
                    context,
                    icon: Icons.settings,
                    text: 'Settings',
                    page: SettingsPage(), // Use the imported SettingsPage
                  ),
                  _createDrawerItem(
                    context,
                    icon: Icons.contact_phone,
                    text: 'Contact Us',
                    page: ContactUsPage(),
                  ),
                  _createDrawerItem(
                    context,
                    icon: Icons.info,
                    text: 'About Us',
                    page: AboutUsPage(),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Sign Out'),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      // Add sign-out logic here
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  ListTile _createDrawerItem(BuildContext context, {
    required IconData icon,
    required String text,
    required Widget page
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFD3C1C3)),
      title: Text(text),
      onTap: () {
        Navigator.pop(context); // Close the drawer
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
    );
  }
}




class TestResultsPage extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    "Hemoglobin": TextEditingController(),
    "RBC": TextEditingController(),
    "Fasting Glucose": TextEditingController(),
    "Postprandial Glucose": TextEditingController(),
    "Total Cholesterol": TextEditingController(),
    "LDL": TextEditingController(),
    "HDL": TextEditingController(),
    "BUN": TextEditingController(),
    "Creatinine": TextEditingController(),
    "Sodium": TextEditingController(),
    "Potassium": TextEditingController(),
    "Calcium": TextEditingController(),
    "TSH": TextEditingController(),
    "Free T3": TextEditingController(),
    "Free T4": TextEditingController(),
  };

  TestResultsPage({super.key});

  // MySQL connection function
  Future<MySqlConnection> _connectToDatabase() async {
    final settings = ConnectionSettings(
      host: '127.0.0.1',
      port: 3306,
      user: 'root',
      password: 'dbms123',
      db: 'lifetrack',
    );
    return await MySqlConnection.connect(settings);
  }

  // Function to save results to MySQL database
  Future<void> _saveTestResults(BuildContext context) async {
    final conn = await _connectToDatabase();
    try {
      final results = _controllers.map(
            (key, controller) => MapEntry(key, controller.text),
      );

      // Create a batch insert query
      var query = 'INSERT INTO test_results (test_name, result_value) VALUES ';
      var values = <String>[];

      results.forEach((key, value) {
        query += '(?, ?),';
        values.add(key);
        values.add(value);
      });

      // Remove last comma from the query
      query = query.substring(0, query.length - 1);

      await conn.query(query, values);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test Results Saved")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving results: $e")),
      );
    } finally {
      await conn.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enter Test Results"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._controllers.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextFormField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: entry.key,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter ${entry.key}";
                        }
                        if (double.tryParse(value) == null) {
                          return "${entry.key} must be a valid number";
                        }
                        return null;
                      },
                    ),
                  );
                }),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _saveTestResults(context);  // Save to MySQL
                    }
                  },
                  child: const Text("Save Results"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedGender;
  final List<String> _genders = ["Male", "Female", "Other"];
  File? _profileImage;

  Map<String, double> healthTestData = {}; // For storing health test data

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _nameController.text = userProvider.name;
    _emailController.text = userProvider.email;
    _profileImage = userProvider.profileImage;
    _fetchHealthTestData();  // Fetch health test data on init
  }

  // Function to save profile to MySQL
  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        (_selectedGender == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all fields")),
      );
      return;
    }

    final conn = await _connectToDatabase();
    try {
      String password = _passwordController.text;
      String age = _ageController.text;

      var queryParams = [
        _nameController.text,
        _emailController.text,
        _selectedGender ?? 'Not Specified',  // If gender is not selected, default to 'Not Specified'
        _profileImage?.path,
        1 // Assuming 1 is the logged-in user's ID
      ];

      if (password.isNotEmpty) {
        queryParams.insert(3, password);
        await conn.query(
            'UPDATE users SET name = ?, email = ?, password = ?, gender = ?, profile_image = ? WHERE id = ?',
            queryParams);
      } else {
        await conn.query(
            'UPDATE users SET name = ?, email = ?, gender = ?, profile_image = ? WHERE id = ?',
            queryParams);
      }

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.updateProfile(
        name: _nameController.text,
        email: _emailController.text,
        profileImage: _profileImage,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Profile Updated: ${_nameController.text}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving profile: $e")),
      );
    }
  }

  // Image picker function
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  // Fetch health test data from MySQL
  Future<void> _fetchHealthTestData() async {
    final conn = await _connectToDatabase();
    try {
      var results = await conn.query('SELECT test_name, result_value FROM test_results WHERE user_id = ?', [1]);
      setState(() {
        healthTestData = {
          for (var row in results)
            row['test_name']: double.parse(row['result_value']),
        };
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching test data: $e")),
      );
    } finally {
      conn.close();
    }
  }

  // MySQL database connection
  Future<MySqlConnection> _connectToDatabase() async {
    final connection = ConnectionSettings(
      host: '127.0.0.1',
      port: 3306,
      user: 'root',
      password: 'dbms123',
      db: 'lifetrack',
    );
    final conn = await MySqlConnection.connect(connection);
    return conn;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Health Test Graph - Will only show if we have data
              healthTestData.isNotEmpty
                  ? Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(show: true),
                    borderData: FlBorderData(show: true),
                    minX: 0,
                    maxX: healthTestData.length.toDouble(),
                    minY: 0,
                    maxY: healthTestData.values.reduce((a, b) => a > b ? a : b),
                    lineBarsData: [
                      LineChartBarData(
                        spots: healthTestData.entries.map((entry) {
                          return FlSpot(
                            double.parse(entry.key), // Assuming the key is time or index
                            entry.value,
                          );
                        }).toList(),
                        isCurved: true,
                        color: Colors.blue,  // Replaced `colors` with `color`
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              )
                  : const Center(child: CircularProgressIndicator()),

              // Profile details form
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFD3C1C3),
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : null,
                    child: _profileImage == null
                        ? const Icon(Icons.person, size: 60, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: "Age",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Change Password",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: "Gender",
                  border: OutlineInputBorder(),
                ),
                items: _genders.map((gender) {
                  return DropdownMenuItem<String>(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text("Save Changes"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _selectedLanguage;
  final List<String> _languages = [
    "English",
    "Hindi",
    "Korean",
    "French",
    "Spanish"
  ];
  bool _isLoading = false;  // Loading indicator flag

  // Function to connect to MySQL database
  Future<MySqlConnection> _connectToDatabase() async {
    final connection = ConnectionSettings(
      host: '127.0.0.1', // Replace with actual MySQL host
      port: 3306,
      user: 'root', // MySQL username
      password: 'dbms123', // MySQL password
      db: 'lifetrack', // MySQL database name
    );
    final conn = await MySqlConnection.connect(connection);
    return conn;
  }

  // Save the selected language to MySQL
  Future<void> _saveLanguageSetting(String language) async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    final conn = await _connectToDatabase();

    try {
      await conn.query(
          'UPDATE settings SET language = ? WHERE user_id = ?',
          [language, 1]  // Assuming '1' is the logged-in user's ID
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Language set to: $language")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving language setting: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
      conn.close();
    }
  }

  // Load the language setting from MySQL
  Future<void> _loadLanguageSetting() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    final conn = await _connectToDatabase();

    try {
      var results = await conn.query(
          'SELECT language FROM settings WHERE user_id = ?',
          [1]  // Assuming '1' is the logged-in user's ID
      );

      if (results.isNotEmpty) {
        setState(() {
          _selectedLanguage = results.first['language'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading language setting: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
      conn.close();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLanguageSetting(); // Load the saved language setting when the page loads
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ListTile(
              title: const Text("Notification Settings"),
              leading: const Icon(Icons.notifications),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Notification Settings")),
                );
              },
            ),
            ListTile(
              title: const Text("Language Settings"),
              leading: const Icon(Icons.language),
              trailing: _isLoading
                  ? const CircularProgressIndicator() // Show loading spinner when saving or loading
                  : DropdownButton<String>(
                value: _selectedLanguage,
                hint: const Text("Select Language"),
                items: _languages.map((lang) {
                  return DropdownMenuItem(
                    value: lang,
                    child: Text(lang),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value;
                    _saveLanguageSetting(value!); // Save to MySQL
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  Future<void> _launchEmail(BuildContext context, String email, String subject, String body) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=$subject&body=$body',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        // After sending email, save the inquiry to MySQL (optional)
        _saveContactInquiry(context, email, subject, body);
      } else {
        throw 'Could not launch email client';
      }
    } catch (e) {
      print('Error launching email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening email client: $e')),
      );
    }
  }

  Future<void> _saveContactInquiry(BuildContext context, String email, String subject, String body) async {
    if (email.isEmpty || subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide all details for the inquiry.')),
      );
      return;
    }

    final conn = await _connectToDatabase();

    try {
      await conn.query(
          'INSERT INTO contact_us (email, subject, body) VALUES (?, ?, ?)',
          [email, subject, body]
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inquiry sent and saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving inquiry: $e')),
      );
    } finally {
      conn.close();
    }
  }

  Future<MySqlConnection> _connectToDatabase() async {
    final connection = ConnectionSettings(
      host: '127.0.0.1', // MySQL host
      port: 3306,        // MySQL port
      user: 'root',      // MySQL username
      password: 'dbms123', // MySQL password
      db: 'lifetrack',    // MySQL database name
    );
    final conn = await MySqlConnection.connect(connection);
    return conn;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Contact Us"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Contact us through the options below.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text("Email Us"),
              onTap: () {
                _launchEmail(context, 'support@example.com', 'Subject: Inquiry', 'Body: Your message here');
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text("Chat with Us"),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Starting a chat...")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  Future<String> _fetchAppDetails() async {
    final conn = await _connectToDatabase();
    try {
      var results = await conn.query('SELECT description FROM app_info WHERE id = 1');
      return results.isNotEmpty ? results.first['description'] : 'No details available';
    } catch (e) {
      return 'Error fetching app details: $e';
    } finally {
      conn.close();
    }
  }

  Future<MySqlConnection> _connectToDatabase() async {
    final connection = ConnectionSettings(
      host: '127.0.0.1', // MySQL host
      port: 3306,        // MySQL port
      user: 'root',      // MySQL username
      password: 'dbms123', // MySQL password
      db: 'lifetrack',    // MySQL database name
    );
    final conn = await MySqlConnection.connect(connection);
    return conn;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About LifeTrack"),
      ),
      body: FutureBuilder<String>(
        future: _fetchAppDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome to LifeTrack - your comprehensive health and wellness companion!",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    // Displaying the fetched app description
                    Text(
                      snapshot.data ?? 'No information available',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    // Optional: Add an app logo or image for branding
                    Center(
                      child: Image.asset(
                        'assets/images/lifetrack_logo.png', // Example image path
                        height: 150,
                        width: 150,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}