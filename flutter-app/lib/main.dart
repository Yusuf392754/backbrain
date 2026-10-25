import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';


// ============================================================
// main
// ============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Your Stripe *publishable* key is safe to put in client code — it's
  // the secret key that must never be here. Pass this in at build time:
  //   flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_...
  Stripe.publishableKey = const String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: 'pk_test_YOUR_PUBLISHABLE_KEY',
  );

  runApp(const BackbrainApp());
}

class BackbrainApp extends StatelessWidget {
  const BackbrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => VoiceService()),
      ],
      child: MaterialApp(
        title: 'BackBrain',
        debugShowCheckedModeBanner: false,
        theme: buildBackbrainTheme(),
        home: const AppBootstrap(),
      ),
    );
  }
}

/// Decides whether to show onboarding (first launch) or go straight
/// into loading the app.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _checked = false;
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final onboarded = await StorageService().isOnboarded();
    if (mounted) {
      setState(() {
        _onboarded = onboarded;
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_onboarded) {
      return OnboardingScreen(onDone: () => setState(() => _onboarded = true));
    }
    return const AppLoader();
  }
}

/// Loads persisted state and starts the always-on voice assistant
/// before showing the main app.
class AppLoader extends StatefulWidget {
  const AppLoader({super.key});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    await appState.load();

    final voice = context.read<VoiceService>();
    voice.onCommand = (command) async {
      final answer = await appState.ask(command);
      voice.speak(answer);
    };
    await voice.startAlwaysOn();

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const RootShell();
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [HomeScreen(), TimelineScreen(), CalendarScreen(), PeopleScreen()];
    const titles = ['backbrain', "sarah's day", 'calendar', "who's who"];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tabIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: tabIndex, children: pages)),
          const VoiceStatusBar(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex,
        onTap: (i) => setState(() => tabIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'timeline'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'people'),
        ],
      ),
    );
  }
}

/// A persistent bar, visible on every screen, showing whether backbrain
/// is currently listening for "hey backbrain" — and letting the user
/// tap to pause/resume it.
class VoiceStatusBar extends StatelessWidget {
  const VoiceStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceService>();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => voice.listening ? voice.stop() : voice.startAlwaysOn(),
            child: CircleAvatar(
              backgroundColor: voice.listening ? Colors.orange : Colors.grey.shade300,
              child: Icon(
                Icons.mic,
                size: 16,
                color: voice.listening ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              voice.status,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// theme
// ============================================================

// A simple, plain theme. No custom fonts, no gradients, no
// animations — just Flutter's normal Material look with one
// accent color.

ThemeData buildBackbrainTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFFC98A3B), // warm amber accent
    scaffoldBackgroundColor: const Color(0xFFF4F6F8),
  );
}


// ============================================================
// models
// ============================================================

class InboxItem {
  final int id;
  String text;
  String meta;
  InboxItem({required this.id, required this.text, required this.meta});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'meta': meta};

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: json['id'] as int,
        text: json['text'] as String,
        meta: json['meta'] as String,
      );
}

class CalendarEvent {
  final int id;
  final String time;
  final String text;
  final String source; // 'backbrain' or 'you'
  CalendarEvent({
    required this.id,
    required this.time,
    required this.text,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time,
        'text': text,
        'source': source,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as int,
        time: json['time'] as String,
        text: json['text'] as String,
        source: json['source'] as String,
      );
}

class ActivityMoment {
  final String time;
  final String title;
  final String desc;
  final String tag;
  ActivityMoment({
    required this.time,
    required this.title,
    required this.desc,
    required this.tag,
  });
}

/// Someone BackBrain keeps track of — family, friends, caregivers, doctors.
class Person {
  final int id;
  String name;
  String relation;
  String note;
  Person({
    required this.id,
    required this.name,
    required this.relation,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relation': relation,
        'note': note,
      };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: json['id'] as int,
        name: json['name'] as String,
        relation: json['relation'] as String,
        note: json['note'] as String,
      );
}


// ============================================================
// utils/time_utils
// ============================================================

/// Parses common human time strings ("8:00 pm", "8pm", "14:30", "2:15 pm")
/// into a [TimeOfDay]. Returns null if it can't confidently parse — callers
/// should fall back to a sensible default rather than fail.
TimeOfDay? parseTimeString(String input) {
  final s = input.trim().toLowerCase();
  if (s.isEmpty) return null;

  final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$').firstMatch(s);
  if (match == null) return null;

  int hour = int.parse(match.group(1)!);
  final minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
  final meridiem = match.group(3);

  if (meridiem == 'pm' && hour != 12) hour += 12;
  if (meridiem == 'am' && hour == 12) hour = 0;

  if (hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}


// ============================================================
// services/storage_service
// ============================================================

/// Wraps shared_preferences so app state survives an app restart.
/// Everything here is local-device storage only — nothing is sent
/// anywhere. A real deployment with a caregiver-sharing feature would
/// need a backend instead of (or in addition to) this.
class StorageService {
  static const _kInbox = 'backbrain_inbox';
  static const _kEvents = 'backbrain_events';
  static const _kPeople = 'backbrain_people';
  static const _kOnboarded = 'backbrain_onboarded';
  static const _kCaregiverShare = 'backbrain_caregiver_share';
  static const _kNotificationsOn = 'backbrain_notifications_on';
  static const _kSubscribed = 'backbrain_subscribed';
  static const _kAskLog = 'backbrain_ask_log';
  static const _kNextInboxId = 'backbrain_next_inbox_id';
  static const _kNextEventId = 'backbrain_next_event_id';
  static const _kNextPersonId = 'backbrain_next_person_id';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<bool> isOnboarded() async => (await _prefs).getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded(bool value) async => (await _prefs).setBool(_kOnboarded, value);

  Future<bool> caregiverShareEnabled() async =>
      (await _prefs).getBool(_kCaregiverShare) ?? false;
  Future<void> setCaregiverShare(bool value) async =>
      (await _prefs).setBool(_kCaregiverShare, value);

  Future<bool> notificationsEnabled() async =>
      (await _prefs).getBool(_kNotificationsOn) ?? true;
  Future<void> setNotificationsEnabled(bool value) async =>
      (await _prefs).setBool(_kNotificationsOn, value);

  Future<bool> isSubscribed() async => (await _prefs).getBool(_kSubscribed) ?? false;
  Future<void> setSubscribed(bool value) async => (await _prefs).setBool(_kSubscribed, value);

  Future<void> saveAskLog(List<Map<String, String>> entries) async {
    final prefs = await _prefs;
    await prefs.setString(_kAskLog, jsonEncode(entries));
  }

  Future<List<Map<String, String>>> loadAskLog() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kAskLog);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((entry) {
      final map = entry as Map<String, dynamic>;
      return <String, String>{
        'q': map['q'] as String? ?? '',
        'a': map['a'] as String? ?? '',
      };
    }).where((entry) => entry['q']!.isNotEmpty && entry['a']!.isNotEmpty).toList();
  }

  Future<void> saveInbox(List<InboxItem> items, int nextId) async {
    final prefs = await _prefs;
    await prefs.setString(_kInbox, jsonEncode(items.map((e) => e.toJson()).toList()));
    await prefs.setInt(_kNextInboxId, nextId);
  }

  Future<List<InboxItem>> loadInbox() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kInbox);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => InboxItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> loadNextInboxId() async => (await _prefs).getInt(_kNextInboxId) ?? 1;

  Future<void> saveEvents(Map<DateTime, List<CalendarEvent>> events, int nextId) async {
    final prefs = await _prefs;
    final serializable = events.entries
        .map((e) => {
              'date': _dateKey(e.key),
              'events': e.value.map((ev) => ev.toJson()).toList(),
            })
        .toList();
    await prefs.setString(_kEvents, jsonEncode(serializable));
    await prefs.setInt(_kNextEventId, nextId);
  }

  Future<Map<DateTime, List<CalendarEvent>>> loadEvents() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kEvents);
    if (raw == null) return {};
    final list = jsonDecode(raw) as List;
    final Map<DateTime, List<CalendarEvent>> result = {};
    for (final entry in list) {
      final map = entry as Map<String, dynamic>;
      final date = DateTime.parse(map['date'] as String);
      final events = (map['events'] as List)
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      result[date] = events;
    }
    return result;
  }

  Future<int> loadNextEventId() async => (await _prefs).getInt(_kNextEventId) ?? 1;

  Future<void> savePeople(List<Person> people, int nextId) async {
    final prefs = await _prefs;
    await prefs.setString(_kPeople, jsonEncode(people.map((e) => e.toJson()).toList()));
    await prefs.setInt(_kNextPersonId, nextId);
  }

  Future<List<Person>> loadPeople() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kPeople);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> loadNextPersonId() async => (await _prefs).getInt(_kNextPersonId) ?? 1;

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Clears saved data (inbox/events/people) but deliberately keeps
  /// onboarding/notification/caregiver preferences intact.
  Future<void> resetAll() async {
    final prefs = await _prefs;
    await prefs.remove(_kInbox);
    await prefs.remove(_kEvents);
    await prefs.remove(_kPeople);
    await prefs.remove(_kAskLog);
    await prefs.remove(_kNextInboxId);
    await prefs.remove(_kNextEventId);
    await prefs.remove(_kNextPersonId);
  }
}


// ============================================================
// services/notification_service
// ============================================================

/// Schedules real device notifications for reminders and calendar events.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {
      // fall back to whatever default is already set if the local
      // zone can't be resolved on this device
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    if (!_initialized) await init();

    final scheduled = tz.TZDateTime.from(dateTime, tz.local);
    // Don't schedule (or throw) for a time that's already passed —
    // this is a demo app, so just skip it quietly.
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'backbrain_reminders',
          'BackBrain reminders',
          channelDescription: 'Reminders for things BackBrain scheduled for you.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}


// ============================================================
// services/chat_service
// ============================================================

/// Sends "ask backbrain" questions to OpenAI's Chat Completions API
/// instead of hand-coded keyword matching.
///
/// SETUP NEEDED: you need your own OpenAI API key from
/// https://platform.openai.com/api-keys — this is a paid API (small
/// per-request cost, not free like the old keyword matching was).
///
/// Don't hardcode your real key here if this code is going in a public
/// GitHub repo (which CAC submissions often are) — anyone can read it
/// out of your source and rack up charges on your account. Pass it in
/// at build/run time instead:
///
///   flutter run --dart-define=OPENAI_API_KEY=sk-...
///
/// which is what the fallback below is set up for.
class ChatService {
  static const String _apiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: 'YOUR_OPENAI_API_KEY',
  );
  static const String _endpoint = 'https://api.openai.com/v1/chat/completions';

  Future<String> ask(String question, String context) async {
    if (_apiKey == 'YOUR_OPENAI_API_KEY') {
      return "backbrain needs an OpenAI API key to answer that — pass one in "
          "with --dart-define=OPENAI_API_KEY=sk-... when you run the app.";
    }

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are BackBrain, a calm, plain-spoken memory assistant '
                  'for someone who wants help remembering their day, their '
                  'schedule, and the people in their life. Answer in 1-2 '
                  'short sentences, using only the information given below. '
                  "If the answer isn't in the context, say you don't have "
                  "that information yet rather than guessing.\n\n"
                  'Context:\n$context',
            },
            {'role': 'user', 'content': question},
          ],
          'max_tokens': 150,
          'temperature': 0.4,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List;
        final message = choices.first['message'] as Map<String, dynamic>;
        return (message['content'] as String).trim();
      }

      return "backbrain couldn't reach its brain right now (error ${response.statusCode}).";
    } catch (e) {
      return "backbrain couldn't reach its brain right now — check your internet connection.";
    }
  }
}


// ============================================================
// services/payment_service
// ============================================================

/// Handles the $19/month BackBrain subscription via Stripe.
///
/// IMPORTANT: Stripe cannot be wired up from the app alone. Creating a
/// subscription requires your Stripe *secret* key, and that key must
/// never live in client code — anyone could pull it out of your app
/// and drain your Stripe account. The real flow is:
///
///   1. A backend you control (see backend/server.js in this project)
///      holds the secret key and creates a Stripe Customer + a $19/mo
///      Subscription when asked.
///   2. It returns a client secret to the app.
///   3. The app uses that client secret to show Stripe's built-in
///      payment sheet, which securely collects card details — the
///      card number never touches your backend or this app's code.
///
/// Set backendUrl (via --dart-define) to wherever you deploy
/// backend/server.js.
class PaymentService {
  static const String backendUrl = String.fromEnvironment(
    'BACKBRAIN_BACKEND_URL',
    defaultValue: 'https://YOUR_BACKEND_URL_HERE',
  );

  /// Starts the $19/month subscription checkout. Returns true if the
  /// user completed payment, false if they backed out, and throws if
  /// something actually went wrong (network, backend, Stripe error).
  Future<bool> subscribe({required String email}) async {
    if (backendUrl == 'https://YOUR_BACKEND_URL_HERE') {
      throw Exception(
        'no payments backend configured — deploy backend/server.js and pass '
        'its URL with --dart-define=BACKBRAIN_BACKEND_URL=...',
      );
    }

    final response = await http.post(
      Uri.parse('$backendUrl/create-subscription'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw Exception('backend error: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final clientSecret = data['clientSecret'] as String;

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'BackBrain',
      ),
    );

    try {
      await Stripe.instance.presentPaymentSheet();
      return true; // no exception thrown means the payment went through
    } on StripeException {
      return false; // user cancelled, or their card was declined
    }
  }
}


// ============================================================
// voice/voice_service
// ============================================================

/// Real always-on "hey backbrain" wake-word detection using Picovoice
/// Porcupine, instead of looping the device's general speech recognizer.
/// Porcupine listens locally at very low power and only wakes the rest
/// of the assistant once it actually hears the wake word. Once woken,
/// it hands off to speech_to_text to capture the question that follows.
///
/// SETUP NEEDED (can't be done from code alone):
/// 1. Sign up free at https://console.picovoice.ai
/// 2. Train a custom wake word "hey backbrain" for each platform you're
///    targeting (Android / iOS) and download the .ppn file(s) it gives you.
/// 3. Put the .ppn file at assets/hey_backbrain.ppn (already declared in
///    pubspec.yaml) — if you name it differently, update keywordPath below.
/// 4. Get your AccessKey from the same console and pass it in at run time:
///
///      flutter run --dart-define=PICOVOICE_ACCESS_KEY=your_key_here
///
///    (same reasoning as the OpenAI key — don't hardcode a real key if
///    this is going in a public repo.)
class VoiceService extends ChangeNotifier {
  static const String _accessKey = String.fromEnvironment(
    'PICOVOICE_ACCESS_KEY',
    defaultValue: 'YOUR_PICOVOICE_ACCESS_KEY',
  );
  static const String _keywordPath = 'assets/hey_backbrain.ppn';

  PorcupineManager? _porcupine;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool listening = false;
  String status = 'tap the mic to start listening for "hey backbrain."';

  /// called with the question heard after the wake word
  void Function(String command)? onCommand;

  Future<void> startAlwaysOn() async {
    if (_accessKey == 'YOUR_PICOVOICE_ACCESS_KEY') {
      status = 'backbrain needs a Picovoice access key — see voice_service.dart.';
      notifyListeners();
      return;
    }

    try {
      _porcupine ??= await PorcupineManager.fromKeywordPaths(
        _accessKey,
        [_keywordPath],
        _onWakeWordDetected,
        errorCallback: _onPorcupineError,
      );
      await _porcupine!.start();
      listening = true;
      status = 'listening — say "hey backbrain" any time.';
      notifyListeners();
    } on PorcupineException catch (e) {
      status = 'wake word engine error: ${e.message}';
      notifyListeners();
    }
  }

  void _onPorcupineError(PorcupineException error) {
    status = 'wake word engine error: ${error.message}';
    notifyListeners();
  }

  void _onWakeWordDetected(int keywordIndex) {
    status = 'heard "hey backbrain" — listening for your question…';
    notifyListeners();
    _captureQuestion();
  }

  Future<void> _captureQuestion() async {
    final available = await _speech.initialize();
    if (!available) {
      status = "speech recognition isn't available on this device.";
      notifyListeners();
      return;
    }

    _speech.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          onCommand?.call(result.recognizedWords.trim());
          status = 'listening — say "hey backbrain" any time.';
          notifyListeners();
        }
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> stop() async {
    await _porcupine?.stop();
    listening = false;
    status = 'mic off. tap to start listening again.';
    notifyListeners();
  }

  Future<void> speak(String text) async {
    await _tts.setSpeechRate(0.48);
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _porcupine?.delete();
    super.dispose();
  }
}


// ============================================================
// app_state
// ============================================================

class AppState extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final NotificationService _notifications = NotificationService();
  final ChatService _chat = ChatService();

  bool loaded = false;
  bool isThinking = false;
  bool notificationsEnabled = true;
  bool caregiverShareEnabled = false;
  bool isSubscribed = false;

  int _nextInboxId = 1;
  int _nextEventId = 1;
  int _nextPersonId = 1;

  List<InboxItem> inbox = [];
  Map<DateTime, List<CalendarEvent>> events = {};
  List<Person> people = [];

  DateTime selectedDay = _dateOnly(DateTime.now());
  DateTime weekStart = _startOfWeek(DateTime.now());

  /// Sample captured moments — stands in for what a real capture
  /// pipeline would produce. Not persisted; it's demo data.
  final List<ActivityMoment> moments = [
    ActivityMoment(time: '7:30 am', title: 'woke up', desc: 'morning medication taken on schedule.', tag: 'health'),
    ActivityMoment(time: '9:00 am', title: 'coffee with pat', desc: 'neighbor stopped by, talked about the garden.', tag: 'social'),
    ActivityMoment(time: '11:00 am', title: 'call with michael', desc: "son called to confirm saturday's visit.", tag: 'family'),
    ActivityMoment(time: '1:00 pm', title: 'lunch', desc: 'soup and a sandwich, watched the news after.', tag: 'routine'),
    ActivityMoment(time: '2:15 pm', title: 'dr. patel visit', desc: 'evening medication dose adjusted, bloodwork in 3 weeks.', tag: 'health'),
    ActivityMoment(time: '4:00 pm', title: 'walk in the garden', desc: 'short walk, watered the tomatoes.', tag: 'routine'),
    ActivityMoment(time: '6:30 pm', title: 'family dinner', desc: 'michael and the kids came by with takeout.', tag: 'family'),
    ActivityMoment(time: '8:00 pm', title: 'evening reminder', desc: 'new medication dose, confirmed taken.', tag: 'health'),
  ];

    /// each entry: {'q': question, 'a': answer} — newest first.
  /// The latest entries are persisted locally so the user can return to
  /// recent answers after restarting the app.
  final List<Map<String, String>> askLog = [];

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _startOfWeek(DateTime d) {
    final date = _dateOnly(d);
    return date.subtract(Duration(days: date.weekday % 7)); // sunday-start week
  }

  Future<void> load() async {
    await _notifications.init();

    inbox = await _storage.loadInbox();
    _nextInboxId = await _storage.loadNextInboxId();
    events = await _storage.loadEvents();
    _nextEventId = await _storage.loadNextEventId();
    people = await _storage.loadPeople();
    _nextPersonId = await _storage.loadNextPersonId();
    askLog
      ..clear()
      ..addAll(await _storage.loadAskLog());
    notificationsEnabled = await _storage.notificationsEnabled();
    caregiverShareEnabled = await _storage.caregiverShareEnabled();
    isSubscribed = await _storage.isSubscribed();

    if (inbox.isEmpty && events.isEmpty && people.isEmpty) {
      _seedDemoData();
    }

    loaded = true;
    notifyListeners();
  }

  void _seedDemoData() {
    inbox = [
      InboxItem(
        id: _nextInboxId++,
        text: 'follow-up bloodwork',
        meta: 'detected from dr. patel visit · suggested: 3 weeks from today',
      ),
    ];

    final today = _dateOnly(DateTime.now());
    events = {
      today: [
        CalendarEvent(
          id: _nextEventId++,
          time: '8:00 pm',
          text: 'new medication dose begins',
          source: 'backbrain',
        ),
      ],
      today.add(const Duration(days: 4)): [
        CalendarEvent(
          id: _nextEventId++,
          time: 'afternoon',
          text: 'sarah visiting',
          source: 'backbrain',
        ),
      ],
    };

    people = [
      Person(id: _nextPersonId++, name: 'sarah', relation: 'daughter', note: 'visits most weekends, usually calls first.'),
      Person(id: _nextPersonId++, name: 'michael', relation: 'son', note: 'calls to check in, brings the kids over for dinner.'),
      Person(id: _nextPersonId++, name: 'dr. patel', relation: 'physician', note: 'manages medication — last visit adjusted the evening dose.'),
      Person(id: _nextPersonId++, name: 'pat', relation: 'neighbor', note: 'stops by for coffee, tends the garden together.'),
    ];

    _persistAll();
  }

  void _persistAll() {
    _storage.saveInbox(inbox, _nextInboxId);
    _storage.saveEvents(events, _nextEventId);
    _storage.savePeople(people, _nextPersonId);
  }

  // ---------------- scheduling inbox ----------------

  void editInboxItem(int id, String newText) {
    final item = inbox.firstWhere((i) => i.id == id);
    item.text = newText;
    _storage.saveInbox(inbox, _nextInboxId);
    notifyListeners();
  }

  Future<void> confirmInboxItem(int id, DateTime day, {String time = ''}) async {
    final item = inbox.firstWhere((i) => i.id == id);
    final date = _dateOnly(day);
    final eventId = _nextEventId++;
    final event = CalendarEvent(
      id: eventId,
      time: time.trim().isEmpty ? 'time tbd' : time.trim(),
      text: item.text,
      source: 'you',
    );
    events.putIfAbsent(date, () => []).add(event);
    inbox.removeWhere((i) => i.id == id);

    _storage.saveInbox(inbox, _nextInboxId);
    _storage.saveEvents(events, _nextEventId);
    notifyListeners();

    await _maybeScheduleNotification(eventId, event, date);
  }

  void addReminder(String text) {
    inbox.add(InboxItem(id: _nextInboxId++, text: text, meta: 'added manually'));
    _storage.saveInbox(inbox, _nextInboxId);
    notifyListeners();
  }

  // ---------------- calendar ----------------

  Future<void> addEvent(DateTime day, String text, String time) async {
    final date = _dateOnly(day);
    final eventId = _nextEventId++;
    final event = CalendarEvent(
      id: eventId,
      time: time.trim().isEmpty ? 'time tbd' : time.trim(),
      text: text,
      source: 'you',
    );
    events.putIfAbsent(date, () => []).add(event);

    _storage.saveEvents(events, _nextEventId);
    notifyListeners();

    await _maybeScheduleNotification(eventId, event, date);
  }

  Future<void> removeEvent(DateTime day, int eventId) async {
    final date = _dateOnly(day);
    final dayEvents = events[date];
    if (dayEvents == null) return;

    final existed = dayEvents.any((event) => event.id == eventId);
    if (!existed) return;
    dayEvents.removeWhere((event) => event.id == eventId);
    if (dayEvents.isEmpty) events.remove(date);

    await _notifications.cancel(eventId);
    await _storage.saveEvents(events, _nextEventId);
    notifyListeners();
  }

  Future<void> _maybeScheduleNotification(int id, CalendarEvent event, DateTime date) async {
    if (!notificationsEnabled) return;
    final parsedTime = parseTimeString(event.time);
    final scheduledFor = DateTime(
      date.year,
      date.month,
      date.day,
      parsedTime?.hour ?? 9,
      parsedTime?.minute ?? 0,
    );
    await _notifications.scheduleReminder(
      id: id,
      title: 'backbrain reminder',
      body: event.text,
      dateTime: scheduledFor,
    );
  }

  List<CalendarEvent> eventsOn(DateTime day) => events[_dateOnly(day)] ?? [];

  void selectDay(DateTime day) {
    selectedDay = _dateOnly(day);
    notifyListeners();
  }

  void goToNextWeek() {
    weekStart = weekStart.add(const Duration(days: 7));
    selectedDay = weekStart;
    notifyListeners();
  }

  void goToPreviousWeek() {
    weekStart = weekStart.subtract(const Duration(days: 7));
    selectedDay = weekStart;
    notifyListeners();
  }

  // ---------------- people ----------------

  void addPerson(String name, String relation, String note) {
    people.add(Person(id: _nextPersonId++, name: name, relation: relation, note: note));
    _storage.savePeople(people, _nextPersonId);
    notifyListeners();
  }

  void editPerson(int id, String name, String relation, String note) {
    final person = people.firstWhere((p) => p.id == id);
    person.name = name;
    person.relation = relation;
    person.note = note;
    _storage.savePeople(people, _nextPersonId);
    notifyListeners();
  }

  void removePerson(int id) {
    people.removeWhere((p) => p.id == id);
    _storage.savePeople(people, _nextPersonId);
    notifyListeners();
  }

  // ---------------- settings ----------------

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    await _storage.setNotificationsEnabled(value);
    if (!value) await _notifications.cancelAll();
    notifyListeners();
  }

  Future<void> setCaregiverShareEnabled(bool value) async {
    caregiverShareEnabled = value;
    await _storage.setCaregiverShare(value);
    notifyListeners();
  }

  Future<void> setSubscribed(bool value) async {
    isSubscribed = value;
    await _storage.setSubscribed(value);
    notifyListeners();
  }

  Future<void> resetDemoData() async {
    await _storage.resetAll();
    await _notifications.cancelAll();
    inbox = [];
    events = {};
    people = [];
    askLog.clear();
    _nextInboxId = 1;
    _nextEventId = 1;
    _nextPersonId = 1;
    _seedDemoData();
    notifyListeners();
  }

  // ---------------- ask backbrain (via ChatGPT) ----------------

  /// Builds a plain-text summary of everything backbrain currently
  /// knows, to send as context alongside the question.
  String _buildContext() {
    final buffer = StringBuffer();

    buffer.writeln('People:');
    if (people.isEmpty) buffer.writeln('- (none added yet)');
    for (final p in people) {
      buffer.writeln('- ${p.name} (${p.relation}): ${p.note}');
    }

    buffer.writeln('\nScheduling inbox (not yet on the calendar):');
    if (inbox.isEmpty) buffer.writeln('- (empty)');
    for (final item in inbox) {
      buffer.writeln('- ${item.text} (${item.meta})');
    }

    buffer.writeln("\nToday's calendar events:");
    final todayEvents = eventsOn(DateTime.now());
    if (todayEvents.isEmpty) buffer.writeln('- (nothing scheduled today)');
    for (final e in todayEvents) {
      buffer.writeln('- ${e.text} at ${e.time}');
    }

    buffer.writeln('\nMoments captured today:');
    for (final m in moments) {
      buffer.writeln('- ${m.time}: ${m.title} — ${m.desc}');
    }

    return buffer.toString();
  }

  /// asks ChatGPT the question, logs the exchange, and returns the answer
  Future<String> ask(String question) async {
    isThinking = true;
    notifyListeners();

    final answer = await _chat.ask(question, _buildContext());

    askLog.insert(0, {'q': question, 'a': answer});
    if (askLog.length > 20) askLog.removeLast();
    await _storage.saveAskLog(askLog);
    isThinking = false;
    notifyListeners();
    return answer;
  }
}


// ============================================================
// widgets/activity_card
// ============================================================

class ActivityCard extends StatelessWidget {
  final String time;
  final String title;
  final String desc;
  final String tag;

  const ActivityCard({
    super.key,
    required this.time,
    required this.title,
    required this.desc,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time, style: const TextStyle(color: Colors.orange, fontSize: 12)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 12))),
          Text(tag, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}


// ============================================================
// widgets/inbox_row
// ============================================================

class InboxRow extends StatelessWidget {
  final String text;
  final String meta;
  final VoidCallback onEdit;
  final VoidCallback onConfirm;

  const InboxRow({
    super.key,
    required this.text,
    required this.meta,
    required this.onEdit,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            const SizedBox(height: 2),
            Text(meta, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(onPressed: onEdit, child: const Text('edit')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: onConfirm, child: const Text('confirm')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// screens/home_screen
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _askController = TextEditingController();

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final voice = context.watch<VoiceService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'the memory that never lets go.',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'backbrain listens, remembers, and recalls.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // ask bar
        Row(
          children: [
            GestureDetector(
              onTap: () => voice.listening ? voice.stop() : voice.startAlwaysOn(),
              child: CircleAvatar(
                backgroundColor: voice.listening ? Colors.orange : Colors.grey.shade300,
                child: Icon(Icons.mic, color: voice.listening ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _askController,
                decoration: const InputDecoration(
                  hintText: 'ask backbrain something...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _ask(appState),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () => _ask(appState), child: const Text('ask')),
          ],
        ),
        const SizedBox(height: 8),
        if (appState.isThinking)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('backbrain is thinking…', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ),
        for (var entry in appState.askLog.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Q: ${entry['q']}\nA: ${entry['a']}',
              style: const TextStyle(fontSize: 13),
            ),
          ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'captured today', value: '14')),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: 'needs scheduling', value: '${appState.inbox.length}')),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: 'people mentioned', value: '${appState.people.length}')),
          ],
        ),

        const SizedBox(height: 16),
        Card(
          color: const Color(0xFF1B2430),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "today's recap: sarah is visiting saturday, dr. patel adjusted "
              "your medication, and bloodwork still needs scheduling.",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),

        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('scheduling inbox', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => _addReminder(context, appState),
              child: const Text('+ add reminder'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (appState.inbox.isEmpty)
          const Text('nothing waiting.', style: TextStyle(color: Colors.grey))
        else
          for (var item in appState.inbox)
            InboxRow(
              text: item.text,
              meta: item.meta,
              onEdit: () => _editReminder(context, appState, item.id, item.text),
              onConfirm: () => _confirmReminder(context, appState, item.id),
            ),

        const SizedBox(height: 20),
        const Text('moments backbrain caught today', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var m in appState.moments)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ActivityCard(time: m.time, title: m.title, desc: m.desc, tag: m.tag),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _ask(AppState appState) {
    final text = _askController.text.trim();
    if (text.isEmpty) return;
    _askController.clear();
    appState.ask(text);
  }

  void _addReminder(BuildContext context, AppState appState) async {
    final result = await _promptText(context, 'add reminder', 'what needs to be remembered?');
    if (result != null && result.trim().isNotEmpty) {
      appState.addReminder(result.trim());
    }
  }

  void _editReminder(BuildContext context, AppState appState, int id, String current) async {
    final result = await _promptText(context, 'edit reminder', 'reminder text', initial: current);
    if (result != null && result.trim().isNotEmpty) {
      appState.editInboxItem(id, result.trim());
    }
  }

  void _confirmReminder(BuildContext context, AppState appState, int id) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final timeStr = await _promptText(context, 'what time?', 'e.g. 3:00 pm (optional)');
    await appState.confirmInboxItem(id, picked, time: timeStr ?? '');
  }

  Future<String?> _promptText(
    BuildContext context,
    String title,
    String hint, {
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: InputDecoration(hintText: hint), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('save')),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// screens/timeline_screen
// ============================================================

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("sarah's day", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('a sample recall of a full day.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var m in appState.moments)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ActivityCard(time: m.time, title: m.title, desc: m.desc, tag: m.tag),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var m in appState.moments)
          ListTile(
            leading: Text(m.time, style: const TextStyle(fontSize: 12)),
            title: Text(m.title),
            subtitle: Text(m.desc),
          ),
      ],
    );
  }
}


// ============================================================
// screens/calendar_screen
// ============================================================

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final days = List.generate(7, (i) => appState.weekStart.add(Duration(days: i)));
    final today = DateTime.now();

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(onPressed: appState.goToPreviousWeek, icon: const Icon(Icons.chevron_left)),
                IconButton(onPressed: appState.goToNextWeek, icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ],
        ),
        Text(
          '${DateFormat('MMM d').format(days.first)} - ${DateFormat('MMM d').format(days.last)}',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var day in days)
              Expanded(
                child: GestureDetector(
                  onTap: () => appState.selectDay(day),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSameDay(day, appState.selectedDay)
                          ? Colors.orange.shade100
                          : (isSameDay(day, today) ? Colors.orange.shade50 : Colors.white),
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(DateFormat('EEE').format(day), style: const TextStyle(fontSize: 10)),
                        Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (appState.eventsOn(day).isNotEmpty)
                          const Icon(Icons.circle, size: 5, color: Colors.green),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM d, EEEE').format(appState.selectedDay),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _addEvent(context, appState),
              child: const Text('+ add event'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (appState.eventsOn(appState.selectedDay).isEmpty)
          const Text('nothing scheduled.', style: TextStyle(color: Colors.grey))
        else
          for (var ev in appState.eventsOn(appState.selectedDay))
            Card(
              child: ListTile(
                title: Text(ev.text),
                subtitle: Text('${ev.time} · ${ev.source == 'backbrain' ? 'detected by backbrain' : 'added by you'}'),
                trailing: IconButton(
                  tooltip: 'delete event',
                  icon: const Icon(Icons.delete_outline, size: 19),
                  onPressed: () => _removeEvent(context, appState, ev),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _removeEvent(BuildContext context, AppState appState, CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('remove event?'),
        content: Text('remove “${event.text}” from the calendar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('remove')),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.removeEvent(appState.selectedDay, event.id);
    }
  }

  void _addEvent(BuildContext context, AppState appState) async {
    final textController = TextEditingController();
    final timeController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('add event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: textController, decoration: const InputDecoration(hintText: "what's the event?"), autofocus: true),
            const SizedBox(height: 8),
            TextField(controller: timeController, decoration: const InputDecoration(hintText: 'time, e.g. 3:00 pm (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('add')),
        ],
      ),
    );
    if (result == true && textController.text.trim().isNotEmpty) {
      await appState.addEvent(appState.selectedDay, textController.text.trim(), timeController.text);
    }
  }
}


// ============================================================
// screens/people_screen
// ============================================================

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("who's who", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => _editPerson(context, appState, null),
              child: const Text('+ add person'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('family, friends, and caregivers.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        if (appState.people.isEmpty)
          const Text('no one added yet.', style: TextStyle(color: Colors.grey))
        else
          for (var p in appState.people)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?')),
                title: Text(p.name),
                subtitle: Text('${p.relation} — ${p.note}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _editPerson(context, appState, p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => appState.removePerson(p.id),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  void _editPerson(BuildContext context, AppState appState, Person? existing) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final relationController = TextEditingController(text: existing?.relation ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'add person' : 'edit person'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(hintText: 'name'), autofocus: true),
            const SizedBox(height: 8),
            TextField(controller: relationController, decoration: const InputDecoration(hintText: 'relation, e.g. daughter')),
            const SizedBox(height: 8),
            TextField(controller: noteController, decoration: const InputDecoration(hintText: 'note'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('save')),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      if (existing == null) {
        appState.addPerson(nameController.text.trim(), relationController.text.trim(), noteController.text.trim());
      } else {
        appState.editPerson(existing.id, nameController.text.trim(), relationController.text.trim(), noteController.text.trim());
      }
    }
  }
}


// ============================================================
// screens/settings_screen
// ============================================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('subscription'),
            subtitle: Text(appState.isSubscribed ? 'active — \$19/month' : 'not subscribed'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
          const Divider(height: 32),
          SwitchListTile(
            value: appState.notificationsEnabled,
            onChanged: (v) => appState.setNotificationsEnabled(v),
            title: const Text('reminder notifications'),
            subtitle: const Text('get notified when something scheduled is coming up.'),
          ),
          SwitchListTile(
            value: appState.caregiverShareEnabled,
            onChanged: (v) => appState.setCaregiverShareEnabled(v),
            title: const Text('share with a caregiver'),
            subtitle: const Text('let a family member view your recap, schedule, and inbox.'),
          ),
          const Divider(height: 32),
          ListTile(
            title: const Text('reset demo data'),
            subtitle: const Text('clears everything and reloads the sample day.'),
            trailing: const Icon(Icons.refresh),
            onTap: () => _confirmReset(context, appState),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('reset demo data?'),
        content: const Text("this clears your inbox, calendar, and people. can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('reset')),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.resetDemoData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('demo data reset.')));
      }
    }
  }
}


// ============================================================
// screens/onboarding_screen
// ============================================================

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('backbrain', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'backbrain listens, remembers, and recalls — so a conversation, '
                'a promise, or a name is never gone for good.',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              const Text('• always tells you when it\'s listening — nothing recorded in secret.'),
              const SizedBox(height: 8),
              const Text('• every recap, reminder, and event can be edited by hand.'),
              const SizedBox(height: 8),
              const Text('• sharing with a caregiver is off unless you turn it on in settings.'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await StorageService().setOnboarded(true);
                    onDone();
                  },
                  child: const Text('get started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================
// screens/subscription_screen
// ============================================================

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final PaymentService _payments = PaymentService();
  final TextEditingController _emailController = TextEditingController();
  bool _loading = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('backbrain subscription')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (appState.isSubscribed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("you're subscribed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('$19/month — thanks for supporting backbrain.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => appState.setSubscribed(false),
                      child: const Text('cancel subscription (demo)'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const Text('backbrain plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('$19 / month', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('everything in the app, for one person. cancel anytime.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'email for billing',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : () => _subscribe(appState),
                child: Text(_loading ? 'opening payment sheet…' : 'subscribe — \$19/month'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _subscribe(AppState appState) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'enter a valid email first.');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final success = await _payments.subscribe(email: email);
      if (success) {
        await appState.setSubscribed(true);
      }
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
