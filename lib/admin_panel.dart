import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  void _adminLogin() async {
    try {
      UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
      
      var adminDoc = await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).get();
      if (adminDoc['isAdmin'] == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const AdminDashboard()));
      } else {
        FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not an Admin!")));
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Access")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(controller: _email, decoration: const InputDecoration(labelText: "Admin Email")),
          TextField(controller: _pass, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _adminLogin, child: const Text("Verify Admin")),
        ]),
      ),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Panel"),
          bottom: const TabBar(tabs: [
            Tab(text: "Users"),
            Tab(text: "Gifts"),
            Tab(text: "Rooms"),
            Tab(text: "Stats"),
          ]),
        ),
        body: const TabBarView(children: [
          UserManagement(),
          GiftManagement(),
          RoomManagement(),
          StatsDashboard(),
        ]),
      ),
    );
  }
}

class UserManagement extends StatelessWidget {
  const UserManagement({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            var user = snapshot.data!.docs[i];
            return ListTile(
              title: Text(user['email']),
              subtitle: Text("Coins: ${user['coins']}"),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.add, color: Colors.green), onPressed: () => 
                  user.reference.update({'coins': FieldValue.increment(1000)})),
                IconButton(icon: const Icon(Icons.block, color: Colors.red), onPressed: () => 
                  user.reference.update({'isBanned': true})),
              ]),
            );
          },
        );
      },
    );
  }
}

class GiftManagement extends StatelessWidget {
  const GiftManagement({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () {
        FirebaseFirestore.instance.collection('gifts').add({'name': 'New Gift', 'price': 500});
      }, child: const Icon(Icons.add)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('gifts').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, i) {
              var gift = snapshot.data!.docs[i];
              return ListTile(title: Text(gift['name']), subtitle: Text("${gift['price']} Coins"),
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => gift.reference.delete()));
            },
          );
        },
      ),
    );
  }
}

class RoomManagement extends StatelessWidget {
  const RoomManagement({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('rooms').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            var room = snapshot.data!.docs[i];
            return ListTile(title: Text(room['name']), trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => room.reference.delete()));
          },
        );
      },
    );
  }
}

class StatsDashboard extends StatelessWidget {
  const StatsDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Total Users: Loading...\nTotal Coins Spend: Loading..."));
  }
}
