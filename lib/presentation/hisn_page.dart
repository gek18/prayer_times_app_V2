import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

class HisnPage extends StatefulWidget {
  const HisnPage({super.key});

  @override
  State<HisnPage> createState() => _HisnPageState();
}

class _HisnPageState extends State<HisnPage> {
  List<dynamic> _hisnData = [];

  Future<void> loadHisnData() async {
    final jsonString = await rootBundle.loadString(
      'assets/hisn_al_muslim.json',
    );
    setState(() {
      _hisnData = json.decode(jsonString);
    });
  }

  @override
  void initState() {
    super.initState();
    loadHisnData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'حصن المسلم 📖',
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.15,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/back.png'),
                  repeat: ImageRepeat.repeat,
                  alignment: Alignment(0.0, 0.7),
                ),
              ),
            ),
          ),
          _hisnData.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: _hisnData.length,
                  itemBuilder: (context, index) {
                    final section = _hisnData[index];
                    return Card(
                      color: const Color.fromARGB(
                        255,
                        47,
                        46,
                        46,
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: ExpansionTile(
                        collapsedIconColor: Colors.deepPurpleAccent,
                        iconColor: Colors.deepPurpleAccent,
                        title: Text(
                          section['title'],
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        children: (section['azkar'] as List).map((zekr) {
                          return ListTile(
                            title: Text(
                              zekr['text'],
                              textAlign: TextAlign.right,
                              style: GoogleFonts.tajawal(
                                fontSize: 17,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.6,
                              ),
                            ),
                            subtitle: Text(
                              "عدد التكرارات: ${zekr['repeat']}",
                              textAlign: TextAlign.right,
                              style: GoogleFonts.tajawal(
                                fontSize: 15,
                                color: Colors.deepPurpleAccent.shade100,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
