import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/auth/screens/additional_sign_up_screen_2.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/signup_appbar_widget.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/signup_fields.dart';
import 'package:ride_sharing_user_app/features/profile/domain/models/categoty_model.dart';
import 'package:ride_sharing_user_app/features/profile/domain/models/vehicle_brand_model.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Étape 2/3 : Informations du véhicule (comme Crisyo).
class VehicleSignUpScreen extends StatefulWidget {
  const VehicleSignUpScreen({super.key});

  @override
  State<VehicleSignUpScreen> createState() => _VehicleSignUpScreenState();
}

class _VehicleSignUpScreenState extends State<VehicleSignUpScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AuthController>().loadSignupVehicleOptions();
    });
  }

  String? _missing(AuthController c) {
    if (c.sdocs['vehicle_photo'] == null) return sxT('La photo du véhicule est requise', 'Vehicle photo is required');
    if (c.signupBrand == null) return sxT('La marque est requise', 'Brand is required');
    if (c.signupModel == null) return sxT('Le modèle est requis', 'Model is required');
    if (c.sc('v_color').text.trim().isEmpty) return sxT('La couleur est requise', 'Colour is required');
    if (c.sc('v_year').text.trim().isEmpty) return sxT('L\'année est requise', 'Year is required');
    if (c.sc('v_km').text.trim().isEmpty) return sxT('Le kilométrage est requis', 'Mileage is required');
    if (c.vehiclePlateController.text.trim().isEmpty) return sxT('Le n° de plaque est requis', 'Plate number is required');
    if (c.signupCategory == null) return sxT('Le type de véhicule est requis', 'Vehicle type is required');
    if (!c.isRideShare && !c.isParcelShare) return sxT('Choisissez au moins un type de service', 'Select at least one service');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GetBuilder<AuthController>(builder: (c) {
          final photo = c.sdocs['vehicle_photo'];
          return Column(children: [
            const SignUpAppbarWidget(title: 'signup_as_a_driver', progressText: '2_of_3', enableBackButton: true),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sxT('Informations du véhicule', 'Vehicle information'),
                  style: textBold.copyWith(color: Theme.of(context).primaryColor, fontSize: 22)),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                Row(children: [
                  Container(width: 96, height: 80,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).hintColor.withOpacity(.12)),
                    child: photo == null
                      ? Icon(Icons.photo_camera_outlined, color: Theme.of(context).hintColor)
                      : ClipRRect(borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(photo.path), fit: BoxFit.cover))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    OutlinedButton(onPressed: () => c.pickSdoc('vehicle_photo'),
                      child: Text(sxT('Photo du véhicule', 'Vehicle photo'))),
                    Text(sxT('Pour vérifier la couleur et l\'état du véhicule', 'To check colour and condition'),
                      style: textRegular.copyWith(color: Theme.of(context).hintColor, fontSize: Dimensions.fontSizeSmall)),
                  ])),
                ]),

                if (c.signupOptionsLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),

                SxDrop<Brand>(sxT('Marque', 'Brand'), hint: '', value: c.signupBrand, items: c.signupBrands,
                  text: (b) => b.name ?? '', onChanged: c.setSignupBrand),
                SxDrop<VehicleModels>(sxT('Modèle', 'Model'), hint: '', value: c.signupModel, items: c.signupModels,
                  text: (m) => m.name ?? '', onChanged: c.setSignupModel),
                SxField(sxT('Couleur', 'Colour'), c.sc('v_color'), caps: TextCapitalization.words),
                SxField(sxT('Année', 'Year'), c.sc('v_year'), type: TextInputType.number),
                SxField(sxT('Kilométrage', 'Mileage'), c.sc('v_km'), type: TextInputType.number),
                SxField(sxT('N° de plaque du véhicule', 'Plate number'), c.vehiclePlateController, caps: TextCapitalization.characters),
                SxDrop<Category>(sxT('Type de véhicule', 'Vehicle type'), hint: sxT('Choisir une catégorie', 'Choose a category'),
                  value: c.signupCategory, items: c.signupCategories, text: (x) => x.name ?? '', onChanged: c.setSignupCategory),

                sxLabel(sxT('Types de services proposés', 'Services offered')),
                _service(context, sxT('Passager', 'Passenger'), c.isRideShare, () => c.updateServiceType(true)),
                _service(context, sxT('Livraison de Colis', 'Parcel delivery'), c.isParcelShare, () => c.updateServiceType(false)),

                const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Get.back(), child: Text(sxT('Précédent', 'Previous')))),
                  const SizedBox(width: 12),
                  Expanded(child: ButtonWidget(
                    buttonText: 'next'.tr, radius: 50,
                    onPressed: () {
                      final m = _missing(c);
                      if (m != null) { showCustomSnackBar(m); return; }
                      Get.to(() => const AdditionalSignUpScreen2());
                    },
                  )),
                ]),
                const SizedBox(height: Dimensions.paddingSizeLarge),
              ]),
            )),
          ]);
        }),
      ),
    );
  }

  Widget _service(BuildContext context, String label, bool value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? Theme.of(context).primaryColor : Theme.of(context).hintColor.withOpacity(.5))),
        child: Row(children: [
          Icon(value ? Icons.check_circle : Icons.radio_button_unchecked,
            color: value ? Theme.of(context).primaryColor : Theme.of(context).hintColor),
          const SizedBox(width: 12),
          Text(label, style: textRegular),
        ]),
      ),
    );
  }
}
