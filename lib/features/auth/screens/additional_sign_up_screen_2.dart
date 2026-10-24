import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/auth/domain/models/signup_body.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/signup_appbar_widget.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/signup_fields.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Étape 3/3 : Téléchargement des documents (comme Crisyo).
class AdditionalSignUpScreen2 extends StatelessWidget {
  const AdditionalSignUpScreen2({super.key});

  String? _missing(AuthController c) {
    if (c.sdocs['license_front'] == null) return sxT('Permis de conduire — recto requis', 'Licence front required');
    if (c.sdocs['license_back'] == null) return sxT('Permis de conduire — verso requis', 'Licence back required');
    if (c.sdocs['registration'] == null) return sxT('Le certificat d\'immatriculation est requis', 'Registration certificate required');
    if (c.sc('registration_exp').text.isEmpty) return sxT('L\'expiration de l\'immatriculation est requise', 'Registration expiry required');
    if (c.sdocs['insurance'] == null) return sxT('Le certificat d\'assurance est requis', 'Insurance certificate required');
    if (c.sc('insurance_exp').text.isEmpty) return sxT('L\'expiration de l\'assurance est requise', 'Insurance expiry required');
    if (c.sdocs['taxi_training'] == null) return sxT('Le certificat de formation de taxi est requis', 'Taxi training certificate required');
    if (c.sdocs['criminal_record'] == null) return sxT('L\'antécédent judiciaire est requis', 'Criminal record check required');
    if (c.sc('criminal_exp').text.isEmpty) return sxT('L\'expiration de l\'antécédent judiciaire est requise', 'Criminal record expiry required');
    final km = int.tryParse(c.sc('v_km').text.trim()) ?? 0;
    if (km > 70000 && c.sdocs['inspection'] == null) return sxT('L\'inspection du véhicule est requise (plus de 70 000 km)', 'Vehicle inspection required (over 70,000 km)');
    if (c.sc('tps').text.trim().isEmpty) return sxT('Le n° TPS est requis', 'GST number required');
    if (c.sc('tvq').text.trim().isEmpty) return sxT('Le n° TVQ est requis', 'QST number required');
    return null;
  }

  Widget _doc(AuthController c, String label, String key, {String? expiryKey}) {
    return SxDoc(label,
      file: c.sdocs[key], onPick: () => c.pickSdoc(key), onRemove: () => c.removeSdoc(key),
      expiry: expiryKey == null ? null : SxDate(sxT('Date d\'expiration', 'Expiry date'), c.sc(expiryKey), future: true, onChanged: c.update));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GetBuilder<AuthController>(builder: (c) {
          return Column(children: [
            const SignUpAppbarWidget(title: 'signup_as_a_driver', progressText: '3_of_3', enableBackButton: true),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sxT('Téléchargement des documents', 'Upload your documents'),
                  style: textBold.copyWith(color: Theme.of(context).primaryColor, fontSize: 22)),

                _doc(c, sxT('Permis de conduire — recto', 'Driver licence — front'), 'license_front'),
                _doc(c, sxT('Permis de conduire — verso', 'Driver licence — back'), 'license_back'),
                _doc(c, sxT('Certificat d\'immatriculation', 'Registration certificate'), 'registration', expiryKey: 'registration_exp'),
                _doc(c, sxT('Certificat d\'assurance', 'Insurance certificate'), 'insurance', expiryKey: 'insurance_exp'),
                _doc(c, sxT('Certificat de formation de taxi', 'Taxi training certificate'), 'taxi_training'),
                _doc(c, sxT('Antécédent judiciaire (renouvelable chaque année)', 'Criminal record check (renewed yearly)'), 'criminal_record', expiryKey: 'criminal_exp'),
                _doc(c, sxT('Inspection du véhicule (si plus de 70 000 km)', 'Vehicle inspection (if over 70,000 km)'), 'inspection'),

                SxField(sxT('N° TPS', 'GST number'), c.sc('tps')),
                SxField(sxT('N° TVQ', 'QST number'), c.sc('tvq')),

                const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                c.isLoading
                  ? Center(child: SpinKitCircle(color: Theme.of(context).primaryColor, size: 40.0))
                  : Row(children: [
                      const Expanded(flex: 2, child: SxBackButton()),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: ButtonWidget(
                        buttonText: sxT('Soumettre', 'Submit'), radius: 50,
                        onPressed: () async {
                          final m = _missing(c);
                          if (m != null) { showCustomSnackBar(m); return; }

                          final services = <String>[];
                          if (c.isRideShare) services.add('ride_request');
                          if (c.isParcelShare) services.add('parcel');

                          String? deviceToken;
                          try {
                            deviceToken = await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 5));
                          } catch (_) { deviceToken = null; }

                          final profile = <String, String>{
                            'id_kind': c.signupIdKind,
                            'birth_date': c.sc('birth').text,
                            'city': c.sc('city').text.trim(),
                            'province': c.sc('province').text.trim(),
                            'country': c.sc('country').text.trim(),
                            'postal_code': c.sc('postal').text.trim(),
                            'license_number': c.sc('license_no').text.trim(),
                            'license_expiry': c.sc('license_exp').text,
                            'vehicle_color': c.sc('v_color').text.trim(),
                            'vehicle_year': c.sc('v_year').text.trim(),
                            'vehicle_km': c.sc('v_km').text.trim(),
                            'registration_expiry': c.sc('registration_exp').text,
                            'insurance_expiry': c.sc('insurance_exp').text,
                            'criminal_record_expiry': c.sc('criminal_exp').text,
                            'tps_number': c.sc('tps').text.trim(),
                            'tvq_number': c.sc('tvq').text.trim(),
                          };

                          final body = SignUpBody(
                            email: c.emailController.text.trim(),
                            address: c.addressController.text.trim(),
                            identityNumber: c.identityNumberController.text.trim(),
                            identificationType: c.identityType,
                            fName: c.fNameController.text.trim(),
                            lName: c.lNameController.text.trim(),
                            phone: c.countryDialCode + c.phoneController.text.trim(),
                            password: c.passwordController.text,
                            confirmPassword: c.confirmPasswordController.text,
                            deviceToken: c.getDeviceToken(),
                            services: services,
                            referralCode: c.referralCodeController.text.trim(),
                            fcmToken: deviceToken,
                            extra: {
                              'vehicle_brand_id': c.signupBrand?.id ?? '',
                              'vehicle_model_id': c.signupModel?.id ?? '',
                              'vehicle_category_id': c.signupCategory?.id ?? '',
                              'vehicle_plate': c.vehiclePlateController.text.trim(),
                              'vehicle_licence_expire_date': c.sc('registration_exp').text,
                              'vehicle_fuel_type': c.signupFuel,
                              'sex': c.signupGender,
                              'date_of_birth': c.sc('birth').text,
                              'country': c.sc('country').text.trim(),
                              'profile_extra': jsonEncode(profile),
                            },
                          );
                          c.register(c.countryDialCode, body);
                        },
                      )),
                    ]),
                const SizedBox(height: Dimensions.paddingSizeDefault),
              ]),
            )),
          ]);
        }),
      ),
    );
  }
}
