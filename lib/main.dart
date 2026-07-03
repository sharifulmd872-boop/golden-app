import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:animate_do/animate_do.dart';
import 'admin_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBovVJIcN2Zp_-GgE7iZZ0yILFhrslAShE",
      authDomain: "friend-room-party.firebaseapp.com",
      databaseURL: "https://friend-room-party-default-rtdb.firebaseio.com",
      projectId: "friend-room-party",
      storageBucket: "friend-room-party.firebasestorage.app",
      messagingSenderId: "750464835745",
      appId: "1:750464835745:web:992500b58e39687b6950e0",
    ),
  );
  runApp(const GoldenVoiceApp());
}

class GoldenVoiceApp extends StatelessWidget {
  const GoldenVoiceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, primaryColor: Colors.amber),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return const RoomListPage();
        return const LoginPage();
      },
    );
  }
}

// --- LOGIN PAGE ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  Future<void> _login() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _signup() async {
    try {
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': _email.text,
        'coins': 1000,
        'isAdmin': false,
        'isBanned': false,
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Golden Voice", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amber)),
            const SizedBox(height: 30),
            TextField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text("Login")),
            TextButton(onPressed: _signup, child: const Text("Sign Up")),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminLoginPage())), 
            child: const Text("Admin Portal", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }
}

// --- ROOM LIST PAGE ---
class RoomListPage extends StatelessWidget {
  const RoomListPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Voice Rooms"), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())
      ]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var room = snapshot.data!.docs[index];
              return Card(
                child: ListTile(
                  title: Text(room['name']),
                  subtitle: const Text("Join Party"),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => VoiceRoomPage(roomId: room.id))),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => FirebaseFirestore.instance.collection('rooms').add({'name': 'Golden Party ${Random().nextInt(100)}'}),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- VOICE ROOM & GAME PAGE ---
class VoiceRoomPage extends StatefulWidget {
  final String roomId;
  const VoiceRoomPage({super.key, required this.roomId});
  @override
  State<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<VoiceRoomPage> {
  late RtcEngine _engine;
  bool _isMicOn = false;
  int? _mySeat;
  
  // Game States
  int _timer = 30;
  bool _isLocked = false;
  int _selectedChip = 100;
  List<String> fruits = ["🍎", "🍓", "🍉", "🍇", "🍍", "🍌", "🍒", "🥝"];
  String _lastWin = "";
  Map<String, int> myBets = {};

  @override
  void initState() {
    super.initState();
    _initAgora();
    _initGameSync();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone].request();
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: "e4cd5ee5f6314f80adcf96e3eab2f63a"));
    await _engine.joinChannel(token: "", channelId: widget.roomId, uid: 0, options: const ChannelMediaOptions());
  }

  void _initGameSync() {
    FirebaseDatabase.instance.ref("game_status").onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          _timer = data['timer'] ?? 30;
          _isLocked = _timer <= 5;
          if (data['show_result'] == true) {
            _lastWin = data['win_fruit'];
            _showResultPopup();
          }
        });
      }
    });
  }

  void _showResultPopup() {
    showDialog(context: context, builder: (c) => ZoomIn(child: AlertDialog(
      title: const Text("Winner!"),
      content: Text(_lastWin, style: const TextStyle(fontSize: 80, textAlign: TextAlign.center)),
    )));
    Future.delayed(const Duration(seconds: 4), () => Navigator.pop(context));
  }

  void _placeBet(String fruit) async {
    if (_isLocked || myBets.length >= 6) return;
    var userDoc = FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid);
    var doc = await userDoc.get();
    if (doc['coins'] >= _selectedChip) {
      await userDoc.update({'coins': FieldValue.increment(-_selectedChip)});
      setState(() => myBets[fruit] = (myBets[fruit] ?? 0) + _selectedChip);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Room: ${widget.roomId}")),
      body: Column(
        children: [
          // 10 Mics Grid
          SizedBox(
            height: 160,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
              itemCount: 10,
              itemBuilder: (c, i) => GestureDetector(
                onTap: () => setState(() => _mySeat = i),
                child: Column(children: [
                  CircleAvatar(backgroundColor: _mySeat == i ? Colors.green : Colors.grey, child: const Icon(Icons.mic)),
                  Text("Seat ${i + 1}")
                ]),
              ),
            ),
          ),
          
          // Fruit Game Area
          Expanded(
            child: Container(
              color: Colors.black26,
              child: Column(
                children: [
                  Text("Time Remaining: $_timer", style: TextStyle(fontSize: 20, color: _isLocked ? Colors.red : Colors.green)),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                      itemCount: 8,
                      itemBuilder: (c, i) => InkWell(
                        onTap: () => _placeBet(fruits[i]),
                        child: Card(child: Center(child: Text("${fruits[i]}\n${myBets[fruits[i]] ?? 0}"))),
                      ),
                    ),
                  ),
                  // Chips
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [100, 100000, 1000000, 10000000].map((v) => 
                    ChoiceChip(label: Text(v.toString()), selected: _selectedChip == v, onSelected: (s) => setState(() => _selectedChip = v))).toList()),
                ],
              ),
            ),
          ),
          
          // Bottom Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: Icon(_isMicOn ? Icons.mic : Icons.mic_off), onPressed: () {
                setState(() => _isMicOn = !_isMicOn);
                _engine.muteLocalAudioStream(!_isMicOn);
              }),
              ElevatedButton(onPressed: () => _showGiftSheet(), child: const Text("🎁 Gifts")),
            ],
          )
        ],
      ),
    );
  }

  void _showGiftSheet() {
    showModalBottomSheet(context: context, builder: (c) => StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('gifts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (c, i) {
            var gift = snapshot.data!.docs[i];
            return InkWell(
              onTap: () async {
                var userDoc = FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid);
                await userDoc.update({'coins': FieldValue.increment(-gift['price'])});
                Navigator.pop(context);
              },
              child: Column(children: [const Icon(Icons.card_giftcard), Text(gift['name']), Text("${gift['price']} C")]),
            );
          },
        );
      },
    ));
  }
}
