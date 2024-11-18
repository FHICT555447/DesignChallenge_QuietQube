import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: FloatingActionButton(
          heroTag: 'loginButton',
          onPressed: () {},
          child: const Text('Go Back'),
        ),
      ),
    );
  }
}
