import 'package:flutter/material.dart';
import 'hospital/hospital_directory_screen.dart';

/// Hospitals Screen tab presenting regional partner hospital directory and interactive OpenStreetMap.
class HospitalsScreen extends StatelessWidget {
  const HospitalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HospitalDirectoryScreen(
      showHeader: false,
    );
  }
}
