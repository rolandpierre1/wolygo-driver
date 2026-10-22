import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/auth/screens/additional_sign_up_screen_2.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/signup_appbar_widget.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/text_field_title_widget.dart';
import 'package:ride_sharing_user_app/features/profile/domain/models/categoty_model.dart';
import 'package:ride_sharing_user_app/features/profile/domain/models/vehicle_brand_model.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Étape 2/3 de l'inscription chauffeur : Véhicule.
class VehicleSignUpScreen extends StatefulWidget {
  const VehicleSignUpScreen({super.key});

  @override
  State<VehicleSignUpScreen> createState() => _VehicleSignUpScreenState();
}

class _VehicleSignUpScreenState extends State<VehicleSignUpScreen> {
  bool get _fr => (Get.locale?.languageCode ?? 'fr') == 'fr';
  String _t(String fr, String en) => _fr ? fr : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AuthController>().loadSignupVehicleOptions();
    });
  }

  BoxDecoration _box(BuildContext context) => BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(50),
    border: Border.all(width: .5, color: Theme.of(context).hintColor.withOpacity(.7)),
  );

  Widget _dropdown<T>(BuildContext context, {required String hint, required T? value, required List<T> items,
    required String Function(T) label, required void Function(T?) onChanged}) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      decoration: _box(context),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint, style: textRegular.copyWith(color: Theme.of(context).hintColor)),
        isExpanded: true,
        underline: const SizedBox(),
        items: items.map((e) => DropdownMenuItem<T>(
          value: e,
          child: Text(label(e), style: textRegular.copyWith(color: Theme.of(context).textTheme.bodyMedium!.color)),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GetBuilder<AuthController>(builder: (c) {
          return Column(children: [
            const SignUpAppbarWidget(title: 'signup_as_a_driver', progressText: '2_of_3', enableBackButton: true),
            Expanded(child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Text(_t('Véhicule', 'Vehicle'),
                    style: textBold.copyWith(color: Theme.of(context).primaryColor, fontSize: 22))),
                  Center(child: Text(_t('Informations sur votre véhicule', 'Your vehicle information'),
                    style: textRegular.copyWith(color: Theme.of(context).primaryColor.withOpacity(0.5),
                      fontSize: Dimensions.fontSizeSmall))),
                  const SizedBox(height: Dimensions.paddingSizeLarge),

                  if (c.signupOptionsLoading) const Center(child: Padding(
                    padding: EdgeInsets.all(20), child: CircularProgressIndicator())),

                  TextFieldTitleWidget(title: '${'vehicle_brand'.tr}*'),
                  _dropdown<Brand>(context,
                    hint: 'select_brand_model'.tr, value: c.signupBrand, items: c.signupBrands,
                    label: (b) => b.name ?? '', onChanged: c.setSignupBrand),

                  TextFieldTitleWidget(title: '${'vehicle_model'.tr}*'),
                  _dropdown<VehicleModels>(context,
                    hint: 'select_vehicle_model'.tr, value: c.signupModel, items: c.signupModels,
                    label: (m) => m.name ?? '', onChanged: c.setSignupModel),

                  TextFieldTitleWidget(title: '${_t('Type de véhicule', 'Vehicle type')}*'),
                  _dropdown<Category>(context,
                    hint: 'select_vehicle_category'.tr, value: c.signupCategory, items: c.signupCategories,
                    label: (x) => x.name ?? '', onChanged: c.setSignupCategory),

                  TextFieldTitleWidget(title: '${'licence_plate_number'.tr}*'),
                  Container(
                    decoration: _box(context),
                    padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                    child: TextField(
                      controller: c.vehiclePlateController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(border: InputBorder.none, hintText: 'ABC 123'),
                    ),
                  ),

                  TextFieldTitleWidget(title: '${_t('Expiration de l\'immatriculation', 'Registration expiry')}*'),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 180)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (d != null) {
                        c.vehicleExpireController.text =
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        c.update();
                      }
                    },
                    child: Container(
                      height: 50, width: double.infinity, alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                      decoration: _box(context),
                      child: Text(
                        c.vehicleExpireController.text.isEmpty ? 'aaaa-mm-jj' : c.vehicleExpireController.text,
                        style: textRegular.copyWith(color: c.vehicleExpireController.text.isEmpty
                          ? Theme.of(context).hintColor : Theme.of(context).textTheme.bodyMedium!.color)),
                    ),
                  ),

                  TextFieldTitleWidget(title: '${'fuel_type'.tr}*'),
                  _dropdown<String>(context,
                    hint: 'fuel_type'.tr, value: c.signupFuel, items: const ['petrol', 'diesel', 'cng', 'lpg'],
                    label: (f) => f.tr, onChanged: (v) { if (v != null) c.setSignupFuel(v); }),

                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  TextFieldTitleWidget(title: '${_t('Types de services proposés', 'Services offered')}*'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                    title: Text(_t('Passager', 'Passenger')),
                    value: c.isRideShare,
                    onChanged: (_) => c.updateServiceType(true),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                    title: Text(_t('Livraison de Colis', 'Parcel delivery')),
                    value: c.isParcelShare,
                    onChanged: (_) => c.updateServiceType(false),
                  ),

                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  ButtonWidget(
                    buttonText: 'next'.tr, radius: 50,
                    onPressed: () {
                      if (c.signupBrand == null) {
                        showCustomSnackBar('vehicle_brand_is_required'.tr);
                      } else if (c.signupModel == null) {
                        showCustomSnackBar('vehicle_model_is_required'.tr);
                      } else if (c.signupCategory == null) {
                        showCustomSnackBar(_t('Le type de véhicule est requis', 'Vehicle type is required'));
                      } else if (!c.isRideShare && !c.isParcelShare) {
                        showCustomSnackBar(_t('Choisissez au moins un type de service', 'Select at least one service'));
                      } else if (c.vehiclePlateController.text.trim().isEmpty) {
                        showCustomSnackBar('licence_plate_number_is_required'.tr);
                      } else if (c.vehicleExpireController.text.isEmpty) {
                        showCustomSnackBar(_t('La date d\'expiration est requise', 'Expiry date is required'));
                      } else {
                        Get.to(() => const AdditionalSignUpScreen2());
                      }
                    },
                  ),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                ]),
              ),
            )),
          ]);
        }),
      ),
    );
  }
}
