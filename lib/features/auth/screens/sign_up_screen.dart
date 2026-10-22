import 'package:flutter/material.dart';
import 'package:ride_sharing_user_app/features/auth/screens/additional_sign_up_screen_1.dart';

/// Point d'entrée de l'inscription chauffeur.
/// Le choix des services (Passager / Colis) se fait maintenant à l'étape « Véhicule ».
class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdditionalSignUpScreen1();
  }
}
