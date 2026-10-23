import 'dart:io';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:ride_sharing_user_app/common_widgets/button_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/image_widget.dart';
import 'package:ride_sharing_user_app/common_widgets/text_field_widget.dart';
import 'package:ride_sharing_user_app/features/auth/controllers/auth_controller.dart';
import 'package:ride_sharing_user_app/features/auth/screens/vehicle_sign_up_screen.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/signup_appbar_widget.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/signup_fields.dart';
import 'package:ride_sharing_user_app/features/auth/widgets/text_field_title_widget.dart';
import 'package:ride_sharing_user_app/features/splash/controllers/splash_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/email_checker.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// Étape 1/3 : Informations personnelles (comme Crisyo).
class AdditionalSignUpScreen1 extends StatelessWidget {
  const AdditionalSignUpScreen1({super.key});

  String? _missing(AuthController c) {
    if (c.pickedProfileFile == null) return sxT('La photo de profil est requise', 'Profile photo is required');
    if (c.fNameController.text.trim().isEmpty) return 'first_name_is_required'.tr;
    if (c.lNameController.text.trim().isEmpty) return 'last_name_is_required'.tr;
    if (c.identityNumberController.text.trim().isEmpty) return sxT('Le n° du document est requis', 'Document number is required');
    if (c.signupGender.isEmpty) return sxT('Le sexe est requis', 'Gender is required');
    if (c.sc('birth').text.isEmpty) return sxT('La date de naissance est requise', 'Birth date is required');
    final phone = c.phoneController.text.trim();
    if (phone.isEmpty) return 'phone_is_required'.tr;
    if (!PhoneNumber.parse(c.countryDialCode + phone).isValid(type: PhoneNumberType.mobile)) return 'phone_number_is_not_valid'.tr;
    final email = c.emailController.text.trim();
    if (email.isEmpty) return 'email_is_required'.tr;
    if (EmailChecker.isNotValid(email)) return 'enter_valid_email_address'.tr;
    final pw = c.passwordController.text;
    if (pw.isEmpty) return 'password_is_required'.tr;
    if (pw.length < 8) return 'minimum_password_length_is_8'.tr;
    if (c.confirmPasswordController.text.isEmpty) return 'confirm_password_is_required'.tr;
    if (pw != c.confirmPasswordController.text) return 'password_is_mismatch'.tr;
    if (c.addressController.text.trim().isEmpty) return 'address_is_required'.tr;
    if (c.sc('city').text.trim().isEmpty) return sxT('La ville est requise', 'City is required');
    if (c.sc('province').text.trim().isEmpty) return sxT('La province est requise', 'Province is required');
    if (c.sc('country').text.trim().isEmpty) return sxT('Le pays est requis', 'Country is required');
    if (c.sc('postal').text.trim().isEmpty) return sxT('Le code postal est requis', 'Postal code is required');
    if (c.sc('license_no').text.trim().isEmpty) return sxT('Le n° de permis est requis', 'Licence number is required');
    if (c.sc('license_exp').text.isEmpty) return sxT('L\'expiration du permis est requise', 'Licence expiry is required');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GetBuilder<AuthController>(builder: (c) {
          if (c.sc('country').text.isEmpty) { c.sc('country').text = 'Canada'; }
          return Column(children: [
            const SignUpAppbarWidget(title: 'signup_as_a_driver', progressText: '1_of_3', enableBackButton: true),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sxT('Informations personnelles', 'Personal information'),
                  style: textBold.copyWith(color: Theme.of(context).primaryColor, fontSize: 22)),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                Row(children: [
                  Container(height: 80, width: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).primaryColor, width: 1)),
                    child: c.pickedProfileFile == null
                      ? ClipRRect(borderRadius: BorderRadius.circular(50),
                          child: const ImageWidget(image: '', height: 76, width: 76, placeholder: Images.personPlaceholder))
                      : CircleAvatar(radius: 38, backgroundImage: FileImage(File(c.pickedProfileFile!.path))),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(onPressed: () => c.pickImage(false, true),
                    child: Text(sxT('Photo de profil', 'Profile photo'))),
                ]),

                SxField(sxT('Prénom', 'First name'), c.fNameController, caps: TextCapitalization.words),
                SxField(sxT('Nom', 'Last name'), c.lNameController, caps: TextCapitalization.words),

                SxDrop<String>(sxT('Type de pièce d\'identité', 'ID type'),
                  hint: '', value: c.signupIdKind, items: const ['carte_identite', 'passeport'],
                  text: (k) => k == 'passeport' ? sxT('Passeport', 'Passport') : sxT('Carte d\'identité', 'ID card'),
                  onChanged: (v) { if (v != null) c.setSignupIdKind(v); }),
                SxField(sxT('N° du document', 'Document number'), c.identityNumberController),

                SxDrop<String>(sxT('Sexe', 'Gender'), hint: '—', value: c.signupGender.isEmpty ? null : c.signupGender,
                  items: const ['male', 'female', 'other'],
                  text: (g) => g == 'male' ? sxT('Homme', 'Male') : g == 'female' ? sxT('Femme', 'Female') : sxT('Autre', 'Other'),
                  onChanged: (v) { if (v != null) c.setSignupGender(v); }),
                SxDate(sxT('Date de naissance (aaaa-mm-jj)', 'Birth date'), c.sc('birth'), onChanged: c.update),

                TextFieldTitleWidget(title: sxT('Téléphone', 'Phone')),
                TextFieldWidget(
                  hintText: 'phone'.tr, inputType: TextInputType.number,
                  countryDialCode: c.countryDialCode, controller: c.phoneController,
                  focusNode: c.phoneNode, nextFocus: c.emailNode, inputAction: TextInputAction.next,
                  onCountryChanged: (CountryCode cc) {
                    c.countryDialCode = cc.dialCode!;
                    c.setCountryCode(cc.dialCode!);
                  },
                ),

                SxField('Email', c.emailController, type: TextInputType.emailAddress),

                TextFieldTitleWidget(title: sxT('Mot de passe', 'Password')),
                TextFieldWidget(hintText: 'password_hint'.tr, inputType: TextInputType.text, prefixIcon: Images.password,
                  isPassword: true, controller: c.passwordController, focusNode: c.passwordNode,
                  nextFocus: c.confirmPasswordNode, inputAction: TextInputAction.next),
                TextFieldTitleWidget(title: '${'confirm_password'.tr}'),
                TextFieldWidget(hintText: 'enter_confirm_password'.tr, inputType: TextInputType.text, prefixIcon: Images.password,
                  isPassword: true, controller: c.confirmPasswordController, focusNode: c.confirmPasswordNode,
                  nextFocus: c.referralNode, inputAction: TextInputAction.next),

                SxField(sxT('Adresse', 'Address'), c.addressController, caps: TextCapitalization.words),
                SxField(sxT('Ville', 'City'), c.sc('city'), caps: TextCapitalization.words),
                SxField('Province', c.sc('province'), caps: TextCapitalization.words),
                SxField(sxT('Pays', 'Country'), c.sc('country'), caps: TextCapitalization.words),
                SxField(sxT('Code postal', 'Postal code'), c.sc('postal'), caps: TextCapitalization.characters),

                SxField(sxT('N° de permis de conduire', 'Driver licence number'), c.sc('license_no')),
                SxDate(sxT('Expiration du permis', 'Licence expiry'), c.sc('license_exp'), future: true, onChanged: c.update),

                if (Get.find<SplashController>().config?.referralEarningStatus ?? false) ...[
                  TextFieldTitleWidget(title: 'referral_code'.tr),
                  TextFieldWidget(hintText: 'referral_code'.tr, capitalization: TextCapitalization.words,
                    inputType: TextInputType.text, prefixIcon: Images.referralIcon1,
                    controller: c.referralCodeController, focusNode: c.referralNode, inputAction: TextInputAction.done),
                ],

                const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                ButtonWidget(
                  buttonText: 'next'.tr, radius: 50,
                  onPressed: () {
                    final m = _missing(c);
                    if (m != null) { showCustomSnackBar(m); return; }
                    c.setIdentityType(c.signupIdKind == 'passeport' ? 'passport' : 'nid');
                    Get.to(() => const VehicleSignUpScreen());
                  },
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
              ]),
            )),
          ]);
        }),
      ),
    );
  }
}
